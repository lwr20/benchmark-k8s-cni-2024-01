kubectl exec -it cni-benchmark-a2 --  statexec -f stm-server.prom -d 10 -l id=calico-bpf-vxlan-9k-wg -l run=3 -i stm -mst 1704067200000 -s --  iperf3 -s
