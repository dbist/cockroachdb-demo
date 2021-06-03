# multi-region demo

# cockroach demo tpcc --with-load
cockroach demo --global --insecure --nodes 9

create database movr; use movr;

create table promo_codes (
code string primary key,
description string
);


SHOW REGIONS FROM CLUSTER;


ALTER DATABASE movr SET PRIMARY REGION "us-east1";

SHOW DATABASES; -- will show zone survivability which is default

SHOW ENUMS FROM movr.public;
crdb_internal_region

SHOW TABLES; -- regional by table in primary region

SHOW ZONE CONFIGURATION FOR DATABASE movr; -- lease preference and constraints set automatically

## add second region
ALTER DATABASE movr ADD REGION "us-west1";

select voting_replicas, non_voting_replicas FROM crdb_internal.ranges WHERE table =

SELECT * FROM promo_codes AS OF SYSTEM TIME follower_read_timestamp();

## add third region, will add survivability

ALTER DATABASE movr ADD REGION "europe-west1"

SHOW DATABASES; -- now displays survivability

SHOW CREATE TABLE rides; -- will show a hidden column by which the table is partioned
