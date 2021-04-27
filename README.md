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
kubectl get pods
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
  # cockroachDBVersion: v20.2.7
  image:
    name: cockroachdb/cockroach:v20.2.7
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
sed 's/nodes: 3/nodes: 4/' example.yaml
```

```bash
kubectl apply -f example.yaml
kubectl get pods
```

### Remove a node

https://www.cockroachlabs.com/docs/v20.2/orchestrate-a-local-cluster-with-kubernetes#step-7-remove-nodes 

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
sed 's/nodes: 4/nodes: 3/' example.yaml
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
sed 's/cockroach:v20.2.7/cockroach:v20.2.8/' example.yaml
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
kubectl exec -it cockroachdb-2 -- ./cockroach workload init ycsb --splits=50 'postgresql://root@cockroachdb-0.cockroachdb.default:26257?sslcert=%2Fcockroach%2Fcockroach-certs%2Fclient.root.crt&sslkey=%2Fcockroach%2Fcockroach-certs%2Fclient.root.key&sslmode=verify-full&sslrootcert=%2Fcockroach%2Fcockroach-certs%2Fca.crt'
```

```bash
kubectl exec -it cockroachdb-2 -- ./cockroach workload run ycsb \
 --duration=20m \
 --concurrency=3 \
 --max-rate=1000 \
 --tolerate-errors \
 'postgresql://root@cockroachdb-0.cockroachdb.default:26257?sslcert=%2Fcockroach%2Fcockroach-certs%2Fclient.root.crt&sslkey=%2Fcockroach%2Fcockroach-certs%2Fclient.root.key&sslmode=verify-full&sslrootcert=%2Fcockroach%2Fcockroach-certs%2Fca.crt'
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
sed 's/cockroach:v20.2.8/cockroach:v20.2.7/' example.yaml
```