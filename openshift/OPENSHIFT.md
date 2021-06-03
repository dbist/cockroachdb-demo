# CockroachDB OpenShift Demo

---

## Requirements

1. CockroachDB Operator
2. OpenShift and/or [Red Hat CodeReady Containers](https://developers.redhat.com/products/codeready-containers/overview)

## Configure CRC

```bash
crc start
pbcopy < ~/Downloads/pull-secret.txt
```

```bash
...
Started the OpenShift cluster.

The server is accessible via web console at:
  https://console-openshift-console.apps-crc.testing

Log in as administrator:
  Username: kubeadmin
  Password: CjssU-6uVIg-6PhbI-mBxIB

Log in as user:
  Username: developer
  Password: developer

Use the 'oc' command line interface:
  $ eval $(crc oc-env)
  $ oc login -u developer https://api.crc.testing:6443
  $ oc login -u kubeadmin https://api.crc.testing:6443
```

### Save the password for kubeadmin

Connect to the [OpenShift Console](https://oauth-openshift.apps-crc.testing/)

```bash
oc create namespace cockroachdb
oc config view --minify | grep namespace:
oc config set-context --current --namespace=cockroachdb
oc config view --minify | grep namespace:
```

### Follow the OpenShift [Tutorial](https://www.cockroachlabs.com/docs/v21.1/deploy-cockroachdb-with-kubernetes-openshift.html) for CockroachDB

### Install the Operator through the Operator Hub

### Check whether the operator is up

```bash
oc get pods --watch
```

### Install an instance of CockroachDB

### Create a secure [client pod](https://www.cockroachlabs.com/docs/v21.1/deploy-cockroachdb-with-kubernetes-openshift.html#step-4-create-a-secure-client-pod)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: crdb-client-secure
  labels:
    app.kubernetes.io/component: database
    app.kubernetes.io/instance: crdb-tls-example
    app.kubernetes.io/name: cockroachdb
spec:
  serviceAccountName: cockroach-operator-sa
  containers:
  - name: crdb-client-secure
    image: registry.connect.redhat.com/cockroachdb/cockroach:v20.2.8
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: client-certs
      mountPath: /cockroach/cockroach-certs/
    command:
    - sleep
    - "2147483648" # 2^31
  terminationGracePeriodSeconds: 0
  volumes:
  - name: client-certs
    projected:
        sources:
          - secret:
              name: crdb-tls-example-node
              items:
                - key: ca.crt
                  path: ca.crt
          - secret:
              name: crdb-tls-example-root
              items:
                - key: tls.crt
                  path: client.root.crt
                - key: tls.key
                  path: client.root.key
        defaultMode: 256
```

Or deploy manually

```bash
oc apply -f client.yaml
```

### Create a SQL user

```bash
oc exec -it crdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs/ --host=crdb-tls-example-public
```

```sql
CREATE USER roach WITH PASSWORD 'roach';
GRANT ADMIN TO roach;
-- decrease node heartbeat
SET CLUSTER SETTING server.time_until_store_dead = '1m15s';
```

### Access the DB Console

```bash
oc port-forward service/crdb-tls-example-public 8080
```

Open the [DB Console](http://localhost:8080)

### Simulate a node failure

```bash
oc delete pod crdb-tls-example-2
oc get pods --watch
```

### Add a node

Go to StatefulSets/crdb-tls-example and click Number of nodes, enter 4 and press enter

### Remove a node

#### Get node IDs

```bash
oc exec -it crdb-tls-example-1 -- ./cockroach node status --certs-dir cockroach-certs
```

#### Decommission a node

```bash
oc exec -it crdb-tls-example-1 -- ./cockroach node decommission --self --certs-dir cockroach-certs --host=crdb-tls-example-3.crdb-tls-example.cockroachdb:26258
```

#### When node is decommissioned

Follow the same steps as adding a node and replace 4 nodes with 3

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
-- Add a column to a table while workload is running
ALTER TABLE tpcc.stock ADD COLUMN val STRING;

-- Show the table description after change
SHOW CREATE TABLE tpcc.stock;

-- Create an index on the table
CREATE INDEX ON tpcc.stock (val);

-- Drop the column while the workload is still running
SET sql_safe_updates = false;
ALTER TABLE tpcc.stock DROP COLUMN val;

-- Validate the column is gone
SHOW CREATE TABLE tpcc.stock;
```

### Drop a table

```sql
SELECT COUNT(*) FROM tpcc.order_line;
DROP TABLE tpcc.order_line;
```

### Backup a database

```sql
BACKUP DATABASE tpcc TO 'userfile://tpcc.public.userfiles_root/database-tpcc' AS OF SYSTEM TIME '-1m';
```

### Restore a table from backup

```sql
RESTORE tpcc.order_line FROM 'userfile://tpcc.public.userfiles_root/database-tpcc' WITH skip_missing_foreign_keys;

SELECT COUNT(*) FROM tpcc.order_line;
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
