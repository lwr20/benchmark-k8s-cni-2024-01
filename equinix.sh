#!/bin/bash

set -x

CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

export KUBECONFIG=$CURDIR/setup/59-kubeconfig.yaml
export SERVER_MTU=1500
export SSHUSER=root
export RESULTPREFIX="eq-metal"
export PROJECT="730997aa-dfc5-429f-a05d-0effa65253c5"
export TYPE="m3.small.x86"

function init {
    echo "Setup instances on Equinix Metal"
    SERVEROPTS="-p $PROJECT -m da -O ubuntu_22_04 -P $TYPE"

    metal device create -H a1 $SERVEROPTS
    metal device create -H a2 $SERVEROPTS
    metal device create -H a3 $SERVEROPTS

    echo "Waiting for all servers to be deployed"
    until metal device get --filter hostname=a1 --output json | jq -r .[].state | grep active; do echo "Trying again"; sleep 1; done
    until metal device get --filter hostname=a2 --output json | jq -r .[].state | grep active; do echo "Trying again"; sleep 1; done
    until metal device get --filter hostname=a3 --output json | jq -r .[].state | grep active; do echo "Trying again"; sleep 1; done

    metal device list -o json | jq -r .[].state

    sleep 10

    A1IP=$(getip a1)
    A2IP=$(getip a2)
    A3IP=$(getip a3)

    WAITPID=""
    $CURDIR/setup/20-os-prepare.sh ${SSHUSER}@$A1IP &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/20-os-prepare.sh ${SSHUSER}@$A2IP &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/20-os-prepare.sh ${SSHUSER}@$A3IP &
    WAITPID="$WAITPID $!"

    echo "Waiting for all servers to be prepared"
    wait $WAITPID

}
function rke2-up {
    A1IP=$(getip a1)
    A2IP=$(getip a2)
    A3IP=$(getip a3)

    echo "Setup RKE2 controlplane on a1 ($A1IP)"
    $CURDIR/setup/50-setup-rke2.sh cp ${SSHUSER}@$A1IP

    echo "Setup RKE2 worker on a2 ($A2IP) and a3 ($A3IP)"
    $CURDIR/setup/50-setup-rke2.sh worker ${SSHUSER}@$A2IP $A1IP
    $CURDIR/setup/50-setup-rke2.sh worker ${SSHUSER}@$A3IP $A1IP

    echo "RKE2 ready"
}

function setup-cni {

    A1IP=$(getip a1)
    A2IP=$(getip a2)
    A3IP=$(getip a3)

    echo "Setup CNI $1"
    $CURDIR/setup/60-setup-cni.sh $1

    echo "Waiting for all pods to be running or completed"
    while [ "$(kubectl get pods -A --no-headers | grep -v Running | grep -v Completed)" != "" ]; do
        echo -n "."
        sleep 2
    done
    echo ""
}

function rke2-down {
    A1IP=$(getip a1)
    A2IP=$(getip a2)
    A3IP=$(getip a3)

    echo "Tear down RKE2"
    WAITPID=""
    $CURDIR/setup/80-teardown-rke2.sh ${SSHUSER}@$A1IP &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/80-teardown-rke2.sh ${SSHUSER}@$A2IP &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/80-teardown-rke2.sh ${SSHUSER}@$A3IP &
    WAITPID="$WAITPID $!"

    echo "Waiting for all servers to be cleaned up"
    wait $WAITPID

    echo "RKE2 down"
}

function clean {
    yes | metal device delete -i "$(metal device get --filter hostname=a1 --output json | jq -r .[].id)"
    yes | metal device delete -i "$(metal device get --filter hostname=a2 --output json | jq -r .[].id)"
    yes | metal device delete -i "$(metal device get --filter hostname=a3 --output json | jq -r .[].id)"

    echo "Waiting for all servers to be deleted"
    until metal device get --filter hostname=a1 --output json | grep "null"; do echo "Trying again"; sleep 1; done
    until metal device get --filter hostname=a2 --output json | grep "null"; do echo "Trying again"; sleep 1; done
    until metal device get --filter hostname=a3 --output json | grep "null"; do echo "Trying again"; sleep 1; done
}


function debugpods {
cat <<-EOF | kubectl apply -f - >/dev/null|| { echo "Cannot create server pod"; return 1;  }
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: debug-server
  name: debug-server
spec:
  containers:
  - name: iperf
    image: infrabuilder/bench-iperf3
    args:
    - iperf3
    - -s
  nodeName: a2
EOF
cat <<-EOF | kubectl apply -f - >/dev/null|| { echo "Cannot create client pod"; return 1;  }
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: debug-client
  name: debug-client
spec:
  containers:
  - name: iperf
    image: infrabuilder/bench-iperf3
    args:
    - sh
    tty: true
  nodeName: a3
EOF

    echo -n "Waiting for server pod to be running "
    while [ "$(kubectl get pod debug-server -o jsonpath='{.status.phase}')" != "Running" ]; do
        echo -n "."
        sleep 2
    done
    echo ""

    # Print server pod IP
    echo "Server IP: $(kubectl get pod debug-server -o jsonpath='{.status.podIP}')"
    echo "Run client with : kubectl exec -it debug-client -- sh"
}

function connect-ssh {
    SSHIP=$(getip "$1")
    shift
    exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSHUSER}@$SSHIP "$@"
}

function getip {
    case $1 in
        a1)
            metal device get --filter hostname=a1 --output json | jq -r .[].ip_addresses[0].address
            ;;
        a2)
            metal device get --filter hostname=a2 --output json | jq -r .[].ip_addresses[0].address
            ;;
        a3)
            metal device get --filter hostname=a3 --output json | jq -r .[].ip_addresses[0].address
            ;;
        *)
            echo "Unknown server $1"
            exit 1
            ;;
    esac
}

[ "$1" = "" ] && echo "Usage: $0 (init|rke2-up|rke2-down|cni <cni>|cleanup)" && exit 1

while [ "$1" != "" ]; do
    case $1 in
        init|i)
            init
            ;;
        rke2-up|up|u)
            rke2-up
            ;;
        rke2-down|down|d)
            rke2-down
            ;;
        setup-cni|cni)
            setup-cni $2
            shift
            ;;
        cleanup|clean|c)
            clean
            ;;
        debugpods|debug|d)
            debugpods
            ;;
        ssh|s)
            connect-ssh $2 "${@:3}"
            shift
            ;;
        getip|ip)
            getip $2
            shift
            ;;
        *)
            echo "Unknown command '$1'"
            exit 1
            ;;
    esac
    shift
done
