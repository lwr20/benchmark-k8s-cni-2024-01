kubectl exec -it cni-benchmark-a3 --  statexec -f idle-client.prom -d 10 -l id=cilium -l run=1 -i idle -mst 1704067200000 -dbc 11  -c 10.0.1.194 --  sleep 60
