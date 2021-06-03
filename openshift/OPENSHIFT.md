# CockroachDB Magic Demo

---

## Configure CRC

```bash
crc start
pbcopy < pull-secret.txt
```

```bash
Started the OpenShift cluster.

The server is accessible via web console at:
  https://console-openshift-console.apps-crc.testing

Log in as administrator:
  Username: kubeadmin
  Password: w2muB-X4xLC-3D7Mz-8DBTe

Log in as user:
  Username: developer
  Password: developer

Use the 'oc' command line interface:
  $ eval $(crc oc-env)
  $ oc login -u developer https://api.crc.testing:6443
  $ oc login -u kubeadmin https://api.crc.testing:6443
```

Connect to the [OpenShift Console](https://oauth-openshift.apps-crc.testing/)

```bash
oc create namespace cockroachdb
oc config view --minify | grep namespace:
oc config set-context --current --namespace=cockroachdb
```

### Follow the OpenShift tutorial for CockroachDB

[Tutorial](https://www.cockroachlabs.com/docs/v21.1/deploy-cockroachdb-with-kubernetes-openshift.html)

### Check the Operator is up

```bash
oc get pods --watch
```

### Create a SQL user

```bash
oc exec -it crdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs/ --host=crdb-tls-example-public
```

```sql
CREATE USER roach WITH PASSWORD 'roach';
GRANT ADMIN TO roach;
```

### Access the DB Console

```bash
oc port-forward service/crdb-tls-example-public 8080
```

## Demo Time

### Simulate node failure

```bash
oc delete pod crdb-tls-example-2
oc get pod crdb-tls-example-2
```

### Add a node

Go to crdb-tls-examples and click Number of nodes, enter 4 and press enter

### Remove a node

#### Get node IDs

```bash
oc exec -it crdb-tls-example-1 -- ./cockroach node status --certs-dir cockroach-certs
```

#### Decommission node

```bash
oc exec -it crdb-tls-example-1 -- ./cockroach node decommission --self --certs-dir cockroach-certs --host=crdb-tls-example-3.crdb-tls-example.cockroachdb:26258
```

#### When node is decommissioned

Follow the same steps as adding a node and replace 4 nodes with 3

#### Optional, decrease node heartbeat

```bash
oc exec -it crdb-tls-example-1 -- ./cockroach sql --certs-dir cockroach-certs --execute="SET CLUSTER SETTING server.time_until_store_dead = '1m15s';"
```

### Upgrade the cluster

TODO

### Upgrade the Operator

TODO

### Run a workload

```bash
oc exec -it crdb-client-secure -- ./cockroach workload \
 fixtures import tpcc \
 'postgresql://root@crdb-tls-example-0.crdb-tls-example.cockroachdb:26257?sslcert=%2Fcockroach%2Fcockroach-certs%2Fclient.root.crt&sslkey=%2Fcockroach%2Fcockroach-certs%2Fclient.root.key&sslmode=verify-full&sslrootcert=%2Fcockroach%2Fcockroach-certs%2Fca.crt'
```

```bash
oc exec -it crdb-client-secure -- ./cockroach workload \
 run tpcc \
 --duration=20m \
 --conns 10 \
 --ramp=3m \
 --workers=10 \
 --tolerate-errors \
 'postgresql://root@crdb-tls-example-0.crdb-tls-example.cockroachdb:26257?sslcert=%2Fcockroach%2Fcockroach-certs%2Fclient.root.crt&sslkey=%2Fcockroach%2Fcockroach-certs%2Fclient.root.key&sslmode=verify-full&sslrootcert=%2Fcockroach%2Fcockroach-certs%2Fca.crt'
 ```

### Online Schema Change

```bash
oc exec -it crdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs/ --host=crdb-tls-example-public
```

```sql
CREATE TABLE t1 (id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
val int);

SHOW CREATE TABLE t1;

INSERT INTO t1 (val) SELECT generate_series(1, 10000);

SELECT COUNT(*) FROM t1;
SELECT * FROM t1 LIMIT 10;

-- SCHEMA CHANGE
ALTER TABLE t1 ADD COLUMN val2 STRING;

```

### Drop the table

```sql
DROP TABLE t1;
```

### Backup a database

```sql
BACKUP DATABASE defaultdb TO 'userfile://defaultdb.public.userfiles_root/database-defaultdb' AS OF SYSTEM TIME '-1m';
```

### Restore a table from backup

```sql
RESTORE defaultdb.t1 FROM 'userfile://defaultdb.public.userfiles_root/database-defaultdb';

SELECT * FROM newdb.t1 LIMIT 100;
```

### Stop the CockroachDB cluster

#### Delete the cluster

Go to CrdbClusters/crdb-tls-example/actions/delete

#### Delete the persistent volumes and persistent volume claims

```bash
oc delete pv,pvc --all
```

#### Remove the Operator

Go to installed operators/uninstall

#### Delete the client pod

Go to pods/crdb-client-secure/delete pod

#### Delete CRC

```bash
crc delete
```