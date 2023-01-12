# Roachprod

## based on https://www.cockroachlabs.com/docs/stable/demo-fault-tolerance-and-recovery.html

export cluster="${USER}-tpcc"
export nodes=13
export zones="eastus2"
export ssd=2
export version="v22.1.13"
export lb=${nodes}
export app1=$(($nodes - 1))
export app2=$(($nodes - 2))
export app3=$(($nodes - 3))

## Create cluster
echo "Creating cluster"
roachprod create ${cluster} -n $nodes -c azure \
    --azure-locations $zones

## Stage and start cluster
echo "Staging and starting cluster"
roachprod stage ${cluster} release $version
roachprod start ${cluster}:1-$(($nodes - 4))

roachprod adminurl ${cluster}:1

## HA Proxy
echo "Install HAProxy"
roachprod install ${cluster}:${lb} haproxy
roachprod run ${cluster}:${lb} "./cockroach gen haproxy --insecure --host `roachprod ip $cluster:1 --external`"
roachprod run ${cluster}:${lb} -- "sed -i 's/roundrobin/leastconn/' haproxy.cfg"
roachprod run ${cluster}:${lb} -- "sed -i 's/4096/20000/' haproxy.cfg"
roachprod run ${cluster}:${lb} -- "sed -i 's/^    bind :26257/    bind :26000/' haproxy.cfg"

roachprod run ${cluster}:${lb} 'haproxy -f haproxy.cfg -D'

# Configure the cluster
echo "Configure store dead time"
roachprod sql ${cluster}:1 -- -e "SET CLUSTER SETTING server.time_until_store_dead = '1m15s';"

# Configure rebalance rates
echo "Configure rebalance rates"
roachprod sql ${cluster}:1 -- -e "SET CLUSTER SETTING kv.snapshot_rebalance.max_rate = '512MB';"
roachprod sql ${cluster}:1 -- -e "SET CLUSTER SETTING kv.snapshot_recovery.max_rate = '512MB';"

# Create tpcc database
echo "Create tpcc database"
roachprod sql ${cluster}:1 -- -e "CREATE DATABASE IF NOT EXISTS tpcc;"

# Change the number of replicas
# echo "Change the number of replicas"
# roachprod sql ${cluster}:1 -- -e "ALTER DATABASE tpcc CONFIGURE ZONE USING num_replicas = 5;"

# Capture the Load Balancer IP
PGHOST=$(roachprod ip ${cluster}:${lb})

# Initialize the tpcc workload
echo "Initialize the tpcc workload"
roachprod run ${cluster}:${app1} "./cockroach workload init tpcc --warehouses 100 \
 \"postgresql://root@${PGHOST}:26000/tpcc?sslmode=disable\""

# Run the tpcc workload
echo "Run the tpcc workload"
declare -a app_nodes=(${app1} ${app2} ${app3})
for i in "${app_nodes[@]}"; do
    roachprod run ${cluster}:$i "./cockroach workload run tpcc \"postgresql://root@${PGHOST}:26000/tpcc?sslmode=disable\" \
      --active-warehouses 10 \
      --warehouses 10 \
      --duration 120m \
      --idle-conns 100 \
      --tolerate-errors \
      --workers 100 2>&1 > tpcc.log | tee -a /dev/null" &
done

# Decommission a node
# echo "Decommission a node"
# roachprod run ${cluster}:1 -- "./cockroach node decommission 3 --insecure"

# Drain a node
# echo "Drain a node"
# roachprod run ${cluster}:1 -- "./cockroach node drain 2 --insecure"
