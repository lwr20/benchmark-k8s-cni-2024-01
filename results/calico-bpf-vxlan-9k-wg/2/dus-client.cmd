kubectl exec -it cni-benchmark-a3 --  statexec -f dus-client.prom -d 10 -l id=calico-bpf-vxlan-9k-wg -l run=2 -i dus -mst 1704067200000 -dbc 11  -c 10.42.164.110 --  iperf3 -c 10.42.164.110 -O 1 -u -b 0 -Z -t 60 --json
