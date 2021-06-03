# CockroachDB Magic Demo

---

## Configure minikube

```bash
kubectl config set-context minikube
minikube config set memory 16384
minikube config set cpus 8
```

### Follow the standard CockroachDB tutorial to start CockroachDB using Kubernetes

[Tutorial](https://www.cockroachlabs.com/docs/v20.2/orchestrate-a-local-cluster-with-kubernetes)

```bash
minikube start --driver=hyperkit
```

### You should see

```bash
 Creating virtualbox VM (CPUs=8, Memory=16384MB, Disk=20000MB) ...
 ```

### Apply the Operator CRD

```bash
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/config/crd/bases/crdb.cockroachlabs.com_crdbclusters.yaml
```

### Install the operator manifest

```bash
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/manifests/operator.yaml
```

### Check the Operator is up

```bash
kubectl get pods --watch
```

### Download the CockroachDB config if not available, otherwise edit the existing

```bash
curl -O https://raw.githubusercontent.com/cockroachdb/cockroach-operator/
master/examples/example.yaml
```

### Working config as of 04/26/21

```yaml
apiVersion: crdb.cockroachlabs.com/v1alpha1
kind: CrdbCluster
metadata:
  name: cockroachdb
spec:
  dataStore:
    pvc:
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: "4Gi"
        volumeMode: Filesystem
  resources:
    requests:
      cpu: "1"
      memory: "2Gi"
    limits:
      cpu: "1"
      memory: "2Gi"
  tlsEnabled: true
  image:
    name: cockroachdb/cockroach:v20.2.9
  nodes: 3
  ```

### Start the CockroachDB cluster using the config

```bash
kubectl apply -f example.yaml
```

### Watch the stdout to make sure cluster is up

```bash
kubectl get pods --watch
```

### Create a SQL client

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
    image: cockroachdb/cockroach:v20.2.9
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

```bash
kubectl apply -f client.yaml
kubectl get pods --watch
```

### List the public service

```bash
kubectl get services
```

### Create a SQL user

###### Doesn't work, need RAM maybe?
```bash
kubectl  exec -it crdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs/ --host=cockroachdb-public
```


### Create a SQL user

```bash
kubectl exec -it cockroachdb-2 -- ./cockroach sql --certs-dir cockroach-certs
```

```sql
CREATE USER roach WITH PASSWORD 'roach';
GRANT admin TO roach;
```

### Access the DB Console

```bash
kubectl port-forward service/cockroachdb-public 8080
```

## Demo Time

### Simulate node failure

```bash
kubectl delete pod cockroachdb-2
kubectl get pod cockroachdb-2
```

### Add a node

```bash
sed -i.saved 's/nodes: 3/nodes: 4/' example.yaml
```

```bash
kubectl apply -f example.yaml
kubectl get pods
```

### Remove a node

[Instructions](https://www.cockroachlabs.com/docs/v20.2/orchestrate-a-local-cluster-with-kubernetes#step-7-remove-nodes)

#### Get node IDs

```bash
kubectl exec -it cockroachdb-2 -- ./cockroach node status --certs-dir cockroach-certs
```

#### Decommission node

```bash
kubectl exec -it cockroachdb-3 -- ./cockroach node decommission --self --certs-dir cockroach-certs --host=cockroachdb-3.cockroachdb.default:26258
```

#### Once decommissiong is done, apply cluster config without that node

```bash
sed -i.saved 's/nodes: 4/nodes: 3/' example.yaml
```

```bash
kubectl apply -f example.yaml
```

#### Optional, decrease node heartbeat

```bash
kubectl exec -it cockroachdb-2 -- ./cockroach sql --certs-dir cockroach-certs --execute="SET CLUSTER SETTING server.time_until_store_dead = '1m15s';"
```

### Upgrade the cluster

Change the cockroachdDB version in the example.yaml

```bash
sed -i.saved 's/cockroach:v20.2.8/cockroach:v20.2.9/' example.yaml
```

```bash
kubectl apply -f example.yaml
kubectl get pods --watch
```

### Upgrade the Operator

```bash
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/manifests/operator.yaml
```

### This will likely affect the port-forwarding, restart the port forwarding

```bash
kubectl port-forward service/cockroachdb-public 8080
```

### Run a workload

```bash
kubectl exec -it cockroachdb-2 -- ./cockroach workload \
 fixtures import tpcc \
 'postgresql://root@cockroachdb-0.cockroachdb.default:26257?sslcert=%2Fcockroach%2Fcockroach-certs%2Fclient.root.crt&sslkey=%2Fcockroach%2Fcockroach-certs%2Fclient.root.key&sslmode=verify-full&sslrootcert=%2Fcockroach%2Fcockroach-certs%2Fca.crt'
```

```bash
kubectl exec -it cockroachdb-2 -- ./cockroach workload \
 run tpcc \
 --duration=20m \
 --conns 10 \
 --ramp=3m \
 --workers=10 \
 --tolerate-errors \
 'postgresql://root@cockroachdb-0.cockroachdb.default:26257?sslcert=%2Fcockroach%2Fcockroach-certs%2Fclient.root.crt&sslkey=%2Fcockroach%2Fcockroach-certs%2Fclient.root.key&sslmode=verify-full&sslrootcert=%2Fcockroach%2Fcockroach-certs%2Fca.crt'
 ```

### Online Schema Change

```bash
kubectl exec -it cockroachdb-2 -- ./cockroach sql --certs-dir cockroach-certs 
```

```sql
CREATE TABLE t1 (id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
val int);

SHOW CREATE TABLE t1;

INSERT INTO t1 (val) SELECT generate_series(1, 10000);

SELECT * FROM t1 LIMIT 10;
```

####
#### ADD SCHEMA CHANGE EXAMPLE
####

### Backup a database

```sql
BACKUP DATABASE defaultdb TO 'userfile://defaultdb.public.userfiles_root/database-defaultdb-weekly' AS OF SYSTEM TIME '-10s';
```

### Restore a table from backup

```sql
CREATE DATABASE newdb;

RESTORE defaultdb.users FROM 'userfile://defaultdb.public.userfiles_root/database-defaultdb-weekly' WITH into_db = 'newdb';

SELECT * FROM newdb.users;
```

### Stop the CockroachDB cluster

#### Delete the StatefulSet

```bash
kubectl delete -f example.yaml
```

#### Delete the persistent volumes and persistent volume claims

```bash
kubectl delete pv,pvc --all
```

#### Remove the Operator

```bash
kubectl delete -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/manifests/operator.yaml
```

### Stop the minikube

```bash
minikube stop
minikube delete
```

```bash
sed -i.saved 's/cockroach:v20.2.8/cockroach:v20.2.7/' example.yaml
```