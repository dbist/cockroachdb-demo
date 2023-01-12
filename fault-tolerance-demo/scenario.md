Fault Tolerance & Recovery

Step 1. Initialize the workload (on a single client)

docker run --rm -it -m 15g  --cpus=4 \
 postgres pgbench \
    --initialize \
    --host=${PGHOST} \
    --username=${PGUSER} \
    --port=${PGPORT} \
    --no-vacuum \
    --scale=${SCALE} \
    --foreign-keys \
    ${PGDATABASE}

Step 2. Run the workload (on each client)

docker run --rm -it -m 15g --cpus=4 \
    --volume="$(pwd)"/tpcb-cockroach.sql:/home/ubuntu/tpcb-cockroach.sql \
    postgres pgbench \
    --host=${PGHOST} \
    --username=${PGUSER} \
    --port=${PGPORT} \
    --no-vacuum \
    --file=/home/ubuntu/tpcb-cockroach.sql@1 \
    --client=10 \
    --jobs=10 \
    --scale=${SCALE} \
    --time=6000 \
    --failures-detailed \
    --max-tries=10 \
    --protocol=prepared \
    -P 5 \
    ${PGDATABASE}

docker run --rm -it -m 15g --cpus=4 \
    postgres pgbench \
        --host=${PGHOST} \
        --username=${PGUSER} \
        --port=${PGPORT} \
        --no-vacuum \
        --builtin=tpcb-like@1 \
        --client=10 \
        --jobs=10 \
        --scale=${SCALE} \
        --time=6000 \
        --failures-detailed \
        --max-tries=10 \
        --protocol=prepared \
        -P 5 \
        --connect \
        ${PGDATABASE}

Step 4. Check the workload

Step 5. Simulate a single node failure

DOWNED=$((1 + $RANDOM % 6))
roachprod stop ${cluster}:$DOWNED

Step 6. Check load continuity and cluster health

Step 7. Watch the cluster repair itself

roachprod start ${cluster}:$DOWNED

Step 8. Prepare for two simultaneous node failures

roachprod sql ${cluster}:1 -- -e "ALTER DATABASE tpcc CONFIGURE ZONE USING num_replicas = 5;"

Step 9. Simulate two simultaneous node failures

DOWNED1=$((1 + $RANDOM % 6))
roachprod stop ${cluster}:$DOWNED1

DOWNED2=$((1 + $RANDOM % 6))
roachprod stop ${cluster}:$DOWNED2

Step 10. Check cluster status and service continuity

Step 11. Simulate hardware deprovisioning

roachprod start ${cluster}:$DOWNED1
roachprod start ${cluster}:$DOWNED2

Step 12. Retire a node

roachprod run ${cluster}:1 -- "./cockroach node drain $DOWNED1 --insecure"
roachprod run ${cluster}:1 -- "./cockroach node decommission $DOWNED1 --insecure"
roachprod wipe ${cluster}:$DOWNED1

Step 13. Upgrade a node

roachprod stage ${cluster}:$DOWNED1 release v22.2.2
roachprod start ${cluster}:$DOWNED1

Step 14. Online Schema Changes (on a random client)

docker run --rm \
    flyway/flyway \
    -url=jdbc:postgresql://${PGHOST}:26000/defaultdb \
    -user=root \
    -password= \
    -connectRetries=3 \
    info

docker run \
    --rm \
    -v $PWD/flyway/sql:/flyway/sql \
    flyway/flyway \
    -url=jdbc:postgresql://${PGHOST}:26000/defaultdb \
    -user=root \
    -password= \
    -connectRetries=3 \
    -baselineOnMigrate="true" \
    migrate
