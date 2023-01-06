
cockroach demo --nodes 9 --with-load

ALTER DATABASE movr CONFIGURE ZONE USING num_replicas = 5, gc.ttlseconds = 100000;

SHOW ZONE CONFIGURATION FROM DATABASE movr;

SET CLUSTER SETTING server.time_until_store_dead = '1m';

\demo add region=us-central1,az=a
\demo add region=us-central1,az=b
\demo add region=us-central1,az=c

\demo shutdown 7
\demo shutdown 8
\demo shutdown 9

after time_until_store_dead threshold, you can decommission to get rid off the nodes

\demo decommission 7
\demo decommission 8
\demo decommission 9



