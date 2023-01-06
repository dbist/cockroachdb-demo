Fault Tolerance & Recovery

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
roachprod start ${cluster}:$DOWNED1
