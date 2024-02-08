kubectl exec -it cni-benchmark-a2 --  statexec -f sum-server.prom -d 10 -l id=calico-bpf-vxlan-9k -l run=3 -i sum -mst 1704067200000 -s --  iperf3 -s
