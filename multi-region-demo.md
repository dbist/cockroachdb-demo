# Demo Multi Region
---

## Spin up a demo environment

```bash
cockroach demo --global --insecure --nodes 9
```

## Show cluster regions

```sql
SHOW REGIONS FROM CLUSTER;
```

## Set primary database region

```sql
ALTER DATABASE movr SET PRIMARY REGION "us-east1";
```

## Show zone survivability which is default

```sql
SHOW DATABASES;
```

## Show an internal type for regions "crdb_internal_region"

```sql
SHOW ENUMS FROM movr.public;
```

## Show table localities

```sql
SHOW TABLES;
```

## Lease preference and constraints set automatically

```sql
SHOW ZONE CONFIGURATION FOR DATABASE movr;
```

## Add secondary region

```sql
ALTER DATABASE movr ADD REGION "us-west1";
```

## Fix this, need to show which replicas belong to which table. For now go to Advanced Debug/Data Distribution

```sql
select voting_replicas, non_voting_replicas FROM crdb_internal.ranges;
```

## Read from a Follower Read

```sql
SELECT * FROM promo_codes AS OF SYSTEM TIME follower_read_timestamp() LIMIT 5;
```

## Add a third region, will add survivability

```sql
ALTER DATABASE movr ADD REGION "europe-west1";
```

## It now displays survivability

```sql
SHOW DATABASES;
```

## do more here, will show a hidden column by which the table is partioned

```sql
SHOW CREATE TABLE rides;
```

## Add region survivability

```sql
ALTER DATABASE movr SURVIVE REGION FAILURE;
```

## Display survivability

```sql
SHOW DATABASES;
```

```sql
\demo shutdown 1