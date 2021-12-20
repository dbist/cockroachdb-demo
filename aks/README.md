# Using CRDB K8S operator with Azure Kubernetes Service

---

*Today, we have Kubernetes Operator pattern documented for OpenShift, Google Kubernetes Engine and Elastic Kubernetes Service on AWS. We don't have documentation for launching CockroachDB on AKS, this tutorial fills that void.*

---

## Previous articles on the topic of K8S and CockroachDB

[CockroachDB with OpenShift](https://blog.ervits.com/2020/09/introducing-cockroachdb-kubernetes.html)

---

## Motivation

We have customers asking for deploying CockroachDB on Azure Kubernetes Service. We do not officially publish documentation on how to do that. This is an attempt to do just that.

There are certain differences in operating kubernetes on Azure, for more information, please refer to their [docs](We only need a few https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough
)

## Prerequisites

We need Azure cli to execute a few commands, make sure you install `azure-cli` on your host. After that, run `az version` to confirm the version compatible with the current documentation.

### High Level Steps

- Create an AKS cluster
- Install CockroachDB Operator
- Deploy CockroachDB
- Verify
- Clean up

#### Step by step instructions

The gist of the tutorial will follow our general Kubernetes [documentation](https://www.cockroachlabs.com/docs/v21.1/deploy-cockroachdb-with-kubernetes), I will highlight the differences on Azure.

## Login to Azure cli

We need to authenticate with Azure and you may do so using CLI below:

```bash
az login --scope https://management.core.windows.net//.default
```

## Create a resource group

```bash
az group create --name artem-rg --location eastus
```

## Create an AKS cluster

```bash
az aks create --resource-group artem-rg --name artem-aks-crdb --node-count 1 --generate-ssh-keys --node-vm-size Standard_D3_v2
```

We need a minimum additional capacity to run CockroachDB and I've had good experience with 4 CPU and 16GB nodes. Notice in the command above I changed `--node-vm-size Standard_D3_v2` which fits my requirements.

Refer to Microsoft Azure CLI [docs](https://docs.microsoft.com/en-US/cli/azure/aks?view=azure-cli-latest#az_aks_create) for more information.

## Get credentials

```bash
az aks get-credentials --resource-group artem-rg --name artem-aks-crdb
```

## Deploy the Operator

This is where you can refer to our docs for launching CockroachDB

Apply the CRD for the operator

```bash
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/config/crd/bases/crdb.cockroachlabs.com_crdbclusters.yaml
```

```bash
customresourcedefinition.apiextensions.k8s.io/crdbclusters.crdb.cockroachlabs.com created
```

apply the Operator manifest

```bash
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/manifests/operator.yaml
```

```bash
Warning: resource namespaces/default is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
namespace/default configured
clusterrole.rbac.authorization.k8s.io/cockroach-database-role created
serviceaccount/cockroach-database-sa created
clusterrolebinding.rbac.authorization.k8s.io/cockroach-database-rolebinding created
role.rbac.authorization.k8s.io/cockroach-operator-role created
clusterrolebinding.rbac.authorization.k8s.io/cockroach-operator-rolebinding created
clusterrole.rbac.authorization.k8s.io/cockroach-operator-role created
serviceaccount/cockroach-operator-sa created
rolebinding.rbac.authorization.k8s.io/cockroach-operator-default created
deployment.apps/cockroach-operator created
```

Validate the operator is running


```bash
kubectl get pods
```

```bash
NAME                                  READY   STATUS    RESTARTS   AGE
cockroach-operator-78ccd58cf7-bwh7d   1/1     Running   0          61s
```

## Download the example.yaml config

```bash
curl -O https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/examples/example.yaml
```

## Apply the example.yaml config

```bash
kubectl apply -f example.yaml
```

```bash
crdbcluster.crdb.cockroachlabs.com/cockroachdb created
```

## Check the pods are created

```bash
kubectl get pods
```

```bash
cockroach-operator-78ccd58cf7-bwh7d   1/1     Running   0          7m45s
cockroachdb-0                         1/1     Running   0          92s
cockroachdb-1                         1/1     Running   0          92s
cockroachdb-2                         0/1     Running   0          92s
```

## Use the built-in SQL client

```bash
kubectl create -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/examples/client-secure-operator.yaml
```

## Get the shell into the pod

```bash
kubectl exec -it cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public
```

```bash
# Welcome to the CockroachDB SQL shell.
# All statements must be terminated by a semicolon.
# To exit, type: \q.
#
# Client version: CockroachDB CCL v21.1.7 (x86_64-unknown-linux-gnu, built 2021/08/09 17:55:28, go1.15.14)
# Server version: CockroachDB CCL v21.1.9 (x86_64-unknown-linux-gnu, built 2021/09/20 21:47:27, go1.15.14)
# Cluster ID: cb48c366-28e7-43f0-a356-f21706f18e8f
#
# Enter \? for a brief introduction.
#
root@cockroachdb-public:26257/defaultdb>
```

## Create user with password

```sql
CREATE USER roach WITH PASSWORD 'Q7gc8rEdS';
GRANT admin TO roach;
```

## Exit the shell

```sql
> \q
```

## Access the DB Console

```bash
kubectl port-forward service/cockroachdb-public 8080
```

IMAGE_CLUSTER
IMAGE_AKS_CONSOLE
IMAGE_NODE_MAP

## Stop the cluster

```bash
kubectl delete -f example.yaml
```

```bash
crdbcluster.crdb.cockroachlabs.com "cockroachdb" deleted
```

## Remove the operator

```bash
kubectl delete -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/manifests/operator.yaml
```

```bash
clusterrole.rbac.authorization.k8s.io "cockroach-database-role" deleted
serviceaccount "cockroach-database-sa" deleted
clusterrolebinding.rbac.authorization.k8s.io "cockroach-database-rolebinding" deleted
role.rbac.authorization.k8s.io "cockroach-operator-role" deleted
clusterrolebinding.rbac.authorization.k8s.io "cockroach-operator-rolebinding" deleted
clusterrole.rbac.authorization.k8s.io "cockroach-operator-role" deleted
serviceaccount "cockroach-operator-sa" deleted
rolebinding.rbac.authorization.k8s.io "cockroach-operator-default" deleted
deployment.apps "cockroach-operator" deleted
Error from server (Forbidden): error when deleting "https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/manifests/operator.yaml": namespaces "default" is forbidden: this namespace may not be deleted
```

## Delete the AKS cluster

```bash
az group delete --resource-group artem-rg
```


#### WIP 

Finally, let me show you what it looks like on a global map

This requires an enterprise license but given you have one, 

Docs to enable node map https://www.cockroachlabs.com/docs/v21.1/enable-node-map.html

Since we're using Azure, the Azure locations are listed [here](https://www.cockroachlabs.com/docs/v21.1/enable-node-map.html#location-coordinates)

```sql
	INSERT into system.locations VALUES ('region', 'eastus', 37.3719, -79.8164)
```

