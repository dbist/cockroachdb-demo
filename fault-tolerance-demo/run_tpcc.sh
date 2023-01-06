# Roachprod run tpcc scenario

export cluster="${USER}-poc"
export nodes=16
export zones="eastus2"
export ssd=2
export version="v22.2.2"
export lb=${nodes}
export app1=$(($nodes - 1))
export app2=$(($nodes - 2))
export app3=$(($nodes - 3))

declare -a app_nodes=(${app1} ${app2} ${app3})
PGHOST=$(roachprod ip ${cluster}:${lb})

for i in "${app_nodes[@]}"; do 
    roachprod run ${cluster}:$i "./cockroach workload run tpcc \"postgresql://root@${PGHOST}:26000/tpcc?sslmode=disable\" \
      --active-warehouses 100 \
      --warehouses 100 \
      --duration 60m \
      --idle-conns 100 \
      --tolerate-errors \
      --workers 1000 2>&1 > tpcc.log | tee -a /dev/null" &
done

