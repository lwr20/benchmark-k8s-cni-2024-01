kubectl exec -it cni-benchmark-a2 --  statexec -f sts-server.prom -d 10 -l id=antrea-ipsec -l run=3 -i sts -mst 1704067200000 -s --  iperf3 -s
