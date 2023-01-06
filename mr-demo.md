select distinct order_line.ol_o_id, "order".o_id from "order" inner join order_line on "order".o_id = order_line.ol_o_id limit 10;


select customer.c_d_id, count("order".o_d_id) as total from "order" inner join customer on "order".o_d_id = customer.c_d_id group by customer.c_d_id order by customer.c_d_id; 

  c_d_id |   total
---------+-------------
       1 | 1009650000
       2 | 1012410000
       3 | 1013010000
       4 | 1010070000
       5 | 1010430000
       6 | 1013550000
       7 | 1010910000
       8 | 1011540000
       9 | 1008750000
      10 | 1014090000
(10 rows)


Time: 244.627s total (execution 244.551s / network 0.076s)




REGION=east-1
USER=artem
DATABASE=tpcc
PASSWORD=changeme12345
HOST=artem-mr-6j2
CLOUD=aws

cockroach sql --url "postgresql://${USER}:${PASSWORD}@${HOST}.${CLOUD}-us-${REGION}.cockroachlabs.cloud:26257/${DATABASE}?sslmode=verify-full&sslrootcert=%2FUsers%2Fartem%2FLibrary%2FCockroachCloud%2Fcerts%2Fartem-mr-ca.crt"

REGION=east-2
USER=artem
DATABASE=tpcc
PASSWORD=changeme12345
HOST=artem-mr-6j2
CLOUD=aws

cockroach sql --url "postgresql://${USER}:${PASSWORD}@${HOST}.${CLOUD}-us-${REGION}.cockroachlabs.cloud:26257/${DATABASE}?sslmode=verify-full&sslrootcert=%2FUsers%2Fartem%2FLibrary%2FCockroachCloud%2Fcerts%2Fartem-mr-ca.crt"

REGION=west-2
USER=artem
DATABASE=tpcc
PASSWORD=changeme12345
HOST=artem-mr-6j2
CLOUD=aws

cockroach sql --url "postgresql://${USER}:${PASSWORD}@${HOST}.${CLOUD}-us-${REGION}.cockroachlabs.cloud:26257/${DATABASE}?sslmode=verify-full&sslrootcert=%2FUsers%2Fartem%2FLibrary%2FCockroachCloud%2Fcerts%2Fartem-mr-ca.crt"


## WORKLOAD

#### Configure schema changes for MR

ALTER DATABASE system CONFIGURE ZONE USING constraints = '{"+region=aws-us-east-1": 1}', lease_preferences = '[[+region=aws-us-east-1]]';

REGION=east-1
USER=artem
DATABASE=tpcc
PASSWORD=changeme12345
HOST=artem-mr-6j2
CLOUD=aws

cockroach \
 workload \
 fixtures \
 import \
 tpcc \
 --warehouses=10 \
 "postgresql://${USER}:${PASSWORD}@${HOST}.${CLOUD}-us-${REGION}.cockroachlabs.cloud:26257/${DATABASE}?sslmode=verify-full&sslrootcert=%2FUsers%2Fartem%2FLibrary%2FCockroachCloud%2Fcerts%2Fartem-mr-ca.crt"

REGION=east-1
USER=artem
DATABASE=tpcc
PASSWORD=changeme12345
HOST=artem-mr-6j2
CLOUD=aws

cockroach workload \
 run tpcc \
 --duration=120m \
 --warehouses=10 \
 --conns 20 \
 --ramp=3m \
 --workers=100 \
 --tolerate-errors \
  "postgresql://${USER}:${PASSWORD}@${HOST}.${CLOUD}-us-${REGION}.cockroachlabs.cloud:26257/${DATABASE}?sslmode=verify-full&sslrootcert=%2FUsers%2Fartem%2FLibrary%2FCockroachCloud%2Fcerts%2Fartem-mr-ca.crt"


REGION=east-2
USER=artem
DATABASE=tpcc
PASSWORD=changeme12345
HOST=artem-mr-6j2
CLOUD=aws

cockroach workload \
 run tpcc \
 --duration=120m \
 --warehouses=10 \
 --conns 20 \
 --ramp=3m \
 --workers=100 \
 --tolerate-errors \
  "postgresql://${USER}:${PASSWORD}@${HOST}.${CLOUD}-us-${REGION}.cockroachlabs.cloud:26257/${DATABASE}?sslmode=verify-full&sslrootcert=%2FUsers%2Fartem%2FLibrary%2FCockroachCloud%2Fcerts%2Fartem-mr-ca.crt"

REGION=west-2
USER=artem
DATABASE=tpcc
PASSWORD=changeme12345
HOST=artem-mr-6j2
CLOUD=aws

cockroach workload \
 run tpcc \
 --duration=120m \
 --warehouses=10 \
 --conns 20 \
 --ramp=3m \
 --workers=100 \
 --tolerate-errors \
  "postgresql://${USER}:${PASSWORD}@${HOST}.${CLOUD}-us-${REGION}.cockroachlabs.cloud:26257/${DATABASE}?sslmode=verify-full&sslrootcert=%2FUsers%2Fartem%2FLibrary%2FCockroachCloud%2Fcerts%2Fartem-mr-ca.crt"


select gateway_region();

## without AOST warehouse table execution, not network

select max(w_id) from warehouse;

us-east1 Time: 21ms total (execution 2ms / network 19ms)
us-east2 Time: 42ms total (execution 13ms / network 29ms)
us-west2 Time: 151ms total (execution 72ms / network 79ms)

## with AOST warehouse table execution, not network (fetch stale reach from the nearest replica)

select max(w_id) from warehouse AS OF SYSTEM TIME follower_read_timestamp();

us-east1 Time: 22ms total (execution 2ms / network 20ms)
us-east2 Time: 30ms total (execution 1ms / network 29ms)
us-west2 Time: 81ms total (execution 3ms / network 79ms)

ALTER DATABASE tpcc SET PRIMARY REGION "aws-us-east-1";
ALTER DATABASE tpcc ADD REGION "aws-us-east-2";
ALTER DATABASE tpcc ADD REGION "aws-us-west-2";
ALTER TABLE warehouse SET LOCALITY GLOBAL;

## SELECT FROM a global table (strong read from a global table)

select max(w_id) from warehouse;

us-east1 Time: 22ms total (execution 3ms / network 19ms)
us-east2 Time: 30ms total (execution 1ms / network 30ms)
us-west2 Time: 81ms total (execution 2ms / network 78ms)

warehouse table is a good candidate for GLOBAL because district table has a foreign key relationship to warehouse on w_id. Now FK lookups on district will have local latencies via warehouse.w_id FK. https://www.cockroachlabs.com/docs/v22.1/demo-low-latency-multi-region-deployment#configure-global-tables 


## Reset the table to default

ALTER TABLE warehouse SET LOCALITY REGIONAL BY TABLE;




## Show regions

```sql
SHOW REGIONS FROM CLUSTER;
```

```sql
      region      |                          zones
------------------+----------------------------------------------------------
  gcp-us-central1 | {gcp-us-central1-b,gcp-us-central1-c,gcp-us-central1-f}
  gcp-us-east4    | {gcp-us-east4-a,gcp-us-east4-b,gcp-us-east4-c}
  gcp-us-west2    | {gcp-us-west2-a,gcp-us-west2-b,gcp-us-west2-c}
```

## Set primary database region

```sql
ALTER DATABASE tpcc SET PRIMARY REGION "gcp-us-east4";
```

## Show zone survivability which is default

```sql
SHOW DATABASES;
```

## Show an internal type for regions "crdb_internal_region"

```sql
SHOW ENUMS FROM tpcc.public;
```

## Show table localities

```sql
SHOW TABLES;
```

## Lease preference and constraints set automatically

```sql
SHOW ZONE CONFIGURATION FOR DATABASE tpcc;
```

## Add secondary region

```sql
ALTER DATABASE tpcc ADD REGION "gcp-us-west2";
```

## Fix this, need to show which replicas belong to which table. For now go to Advanced Debug/Data Distribution

```sql
select voting_replicas, non_voting_replicas FROM crdb_internal.ranges;
```

## Read from a Follower Read

```sql
SELECT * FROM stock AS OF SYSTEM TIME follower_read_timestamp() LIMIT 5;
```

## Add a third region, will add survivability

```sql
ALTER DATABASE tpcc ADD REGION "gcp-us-central1";
```

## It now displays survivability

```sql
SHOW DATABASES;
```

## do more here, it should show a hidden column by which the table is partioned

```sql
SHOW CREATE TABLE stock;
```

## Add region survivability

```sql
ALTER DATABASE tpcc SURVIVE REGION FAILURE;
```

## Display survivability

```sql
SHOW DATABASES;
```



