kubectl exec -it cni-benchmark-a3 --  statexec -f dus-client.prom -d 10 -l id=cilium -l run=3 -i dus -mst 1704067200000 -dbc 11  -c 10.0.1.154 --  iperf3 -c 10.0.1.154 -O 1 -u -b 0 -Z -t 60 --json
