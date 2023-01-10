# Roachprod

## based on https://www.postgresql.org/docs/current/pgbench.html

export cluster="${USER}-pgbench"
export nodes=10
export zones="eastus2"
export ssd=2
export version="v22.1.13"
export lb=${nodes}
export app=$(($nodes - 1))

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

# Change the number of replicas
echo "Change the number of replicas"
roachprod sql ${cluster}:1 -- -e "ALTER DATABASE defaultdb CONFIGURE ZONE USING num_replicas = 5;"

# Capture the Load Balancer IP
PGHOST=$(roachprod ip ${cluster}:${lb})

# Install Docker
echo "Installing Docker"
for i in {0..2}; do
    roachprod run ${cluster}:$(($app - $i)) -- "sudo apt-get update && sudo apt-get install ca-certificates curl gnupg lsb-release -y"
    roachprod run ${cluster}:$(($app - $i)) -- "sudo mkdir -p /etc/apt/keyrings"
    roachprod run ${cluster}:$(($app - $i)) -- "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
    roachprod run ${cluster}:$(($app - $i)) -- "echo deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
    roachprod run ${cluster}:$(($app - $i)) -- "sudo apt-get update && sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y"
    roachprod run ${cluster}:$(($app - $i)) -- "sudo usermod -aG docker ubuntu"
    roachprod run ${cluster}:$(($app - $i)) -- "newgrp docker"
    roachprod run ${cluster}:$(($app - $i)) -- "docker pull postgres"
    roachprod put ${cluster}:$(($app - $i)) tpcb-cockroach.sql .
    roachprod run ${cluster}:$(($app - $i)) -- "echo export PGHOST=${PGHOST} >> ~/.bashrc"
    roachprod run ${cluster}:$(($app - $i)) -- "echo export PGUSER=root >> ~/.bashrc"
    roachprod run ${cluster}:$(($app - $i)) -- "echo export PGPORT=26000  >> ~/.bashrc"
    roachprod run ${cluster}:$(($app - $i)) -- "echo export PGDATABASE=defaultdb  >> ~/.bashrc"
    roachprod run ${cluster}:$(($app - $i)) -- "echo export SCALE=100  >> ~/.bashrc"
    roachprod run ${cluster}:$(($app - $i)) -- "source ~/.bashrc"
done

# Initialize the pgbench workload
#echo "Initializing pgbench workload"

#roachprod run ${cluster}:$(($app - 0)) -- "docker run --rm -it -m #15g --cpus=4 postgres pgbench \
# --initialize \
# --host=${PGHOST} \
# --username=${PGUSER} \
# --port=${PGPORT} \
# --no-vacuum \
# --scale=${SCALE} \
# --foreign-keys \
#${PGDATABASE} bash -s"

# Run the pgbench workload
#echo "Running pgbench workload"

#roachprod run ${cluster}:$(($app - 0)) --
#    "docker run --rm -it -m 15g --cpus=4 \
#        postgres pgbench \
#            --host=${PGHOST} \
#            --username=${PGUSER} \
#            --port=${PGPORT} \
#            --no-vacuum \
#            --builtin=tpcb-like@1 \
#            --client=30 \
#            --jobs=30 \
#            --scale=${SCALE} \
#            --time=1800 \
#            --failures-detailed \
#            --max-tries=10 \
#            --protocol=prepared \
#            -P 5 \
#            --connect \
#            ${PGDATABASE}"

# Run the pgbench workload using CockroachDB
#echo "Running pgbench workload using CockroachDB"

#roachprod run ${cluster}:$(($app - 0)) --
#    "docker run --rm -it -m 15g --cpus=4 \
#        --volume="$(pwd)"/tpcb-cockroach.sql:/home/ubuntu/#tpcb-cockroach.sql \
#        postgres pgbench \
#            --host=${PGHOST} \
#            --username=${PGUSER} \
#            --port=${PGPORT} \
#            --no-vacuum \
#            --file=/home/ubuntu/tpcb-cockroach.sql@1 \
#            --client=30 \
#            --jobs=30 \
#            --scale=${SCALE} \
#            --time=1800 \
#            --failures-detailed \
#            --max-tries=10 \
#            --protocol=prepared \
#            -P 5 \
#            --connect \
#            ${PGDATABASE}"
