kubectl exec -it cni-benchmark-a2 --  statexec -f dum-server.prom -d 10 -l id=calico-bpf-vxlan-9k -l run=1 -i dum -mst 1704067200000 -s --  iperf3 -s
