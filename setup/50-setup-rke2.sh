#!/bin/bash

set -x

[ "$2" = "" ] && echo "Usage: $0 (cp|wk) user@host" && exit 1

CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

QSSH="ssh -A -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
CONTROLPLANE_IP=$3
IP=$4
EXT_IP=$5

case $1 in
    "cp")
        cat $CURDIR/51-setup-rke2-controlplane.sh | sed 's/{{CONTROLPLANE_IP}}/'${CONTROLPLANE_IP}'/' | \
		sed 's/{{NODE_IP}}/'${IP}'/' | sed 's/{{NODE_IP_EXT}}/'${EXT_IP}'/' | \
		$QSSH $2 sudo bash
        CONTROLPLANE_URL=$( sed 's/.*@//' <<< ${CONTROLPLANE_IP} )
        $QSSH $2 sudo cat /etc/rancher/rke2/rke2.yaml| sed 's/127.0.0.1:6443/'${EXT_IP}':6443/' > $CURDIR/59-kubeconfig.yaml
        ;;
    "worker")
        [ "$3" = "" ] && echo "Usage: $0 worker user@host controlplane-ip" && exit 1
        cat $CURDIR/52-setup-rke2-worker.sh | sed 's/{{CONTROLPLANE_IP}}/'${CONTROLPLANE_IP}'/' | \
		sed 's/{{NODE_IP}}/'${IP}'/' | sed 's/{{NODE_IP_EXT}}/'${EXT_IP}'/' | \
		$QSSH $2 sudo bash
        ;;
    *)
        echo "Unknown node type"
        exit 1
        ;;
esac
