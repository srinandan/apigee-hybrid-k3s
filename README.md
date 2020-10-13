# Installing Apigee hybrid on k3s

## Purpose

**Demonstration and Experiments**
K3s is a lightweight Kubernetes which could be used by the field teams for demonstration purposes. This would be the technical equivalent of OPDK  [AIO](https://docs.apigee.com/private-cloud/v4.50.00/installation-topologies#allinoneinstallation). It can be installed on VMs ( [Ubuntu](https://rancher.com/docs/k3s/latest/en/installation/installation-requirements/#operating-systems)) with very little pre-requisites.

The following steps show a 2 VM/Node installation. **It can be brought down to one node.**

### When should I use this?

1. Be able to start and finish the installation in ~20-30 mins
2. You want to experiment with Apigee hybrid without setting up a full k8s/Anthos cluster

This is not an officially supported platform.

### Changes

The overrides used here change the min/max replicas for all components, change the default mem/cpu settings to be minimum and finally, most importantly, I used open source Istio and not ASM.

Tested with:

* Ubuntu 18.04
* Apigee hybrid v1.3.3
* Istio v1.7.3
* cert-manager v1.0.1

## Steps (Multiple Nodes)

Here are the steps to install Apigee hybrid on k3s

Step 1: Create an instance template in GCE. I used Ubuntu 18.04, e-standard-4 nodes (NOTE: If using a  single node, create a 8 vCPU VM). With public IPs.

```bash
export project=xxx
export region=us-west1
export zone=us-west1-a
export vpc_name=default

gcloud config set project $project

gcloud compute instance-templates create k3s \
  --project $project --region $region --network $vpc_name \
  --tags=https-server,apigee-envoy-proxy,gke-apigee-proxy \
  --machine-type e2-standard-8 --image-family ubuntu-minimal-1804-lts \
  --image-project ubuntu-os-cloud --boot-disk-size 20GB \
  --metadata=startup-script-url=https://raw.githubusercontent.com/srinandan/apigee-hybrid-k3s/main/install-cli.sh
```

If you're using > 1 node, change to e2-standard-4

Step 2: Create the first node (this will be the master node).

```bash
gcloud compute instances create k3s-1 \
    --source-instance-template=k3s --zone=$zone
```

Step 2a: Switch to root user and install k3s

```bash
gcloud compute ssh k3s-1 --zone=$zone

sudo su -

curl -sfL https://get.k3s.io |INSTALL_K3S_EXEC="--no-deploy traefik --node-ip=$(hostname -I) --write-kubeconfig-mode=644" INSTALL_K3S_VERSION=v1.16.15+k3s1 sh -
```

`--no-deploy` traefik will disable the default traefik based ingress controller. See  [here](https://rancher.com/docs/k3s/latest/en/networking/#traefik-ingress-controller).

`--node-ip` is the GCE VM IP Address

NOTE: It is critical that 1.16 is installed. The newer versions (1.18+) will fail.

Step 2b: Note the token for nodes to join the cluster

```bash
cat /var/lib/rancher/k3s/server/token
```

The output of this command will look like:

```bash
K10ca7b667cc369282e3fd39e2b46dd3e4b53b91da28a0f49693b6207f6a725b791::server:2db0194382554428786917c8247fff65
```

This will be used later.

Step 2c: Note kube config. This should be copied to each VM

```bash
cat /etc/rancher/k3s/k3s.yaml
```

This should look like this:

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJWakNCL3FBREFnRUNBZ0VBTUFvR0NDcUdTTTQ5QkFNQ01DTXhJVEFmQmdOVkJBTU1HR3N6Y3kxelpYSjIKWlhJdFkyRkFNVFl3TWpBME5qVTBOekFlRncweU1ERXdNRGN3TkRVMU5EZGFGdzB6TURFd01EVXdORFUxTkRkYQpNQ014SVRBZkJnTlZCQU1NR0dzemN5MXpaWEoyWlhJdFkyRkFNVFl3TWpBME5qVTBOekJaTUJNR0J5cUdTTTQ5CkFnRUdDQ3FHU000OUF3RUhBMElBQk1YYnhSU05ZU0hOdzM5UTE4eGxMaG1HK0JiU3NVcmNOQzlHeCt6bEVGYXoKaFVYdWhQV0JDbGtwOTljaFIzaE1TVU51Vlh3dWRyMHN2TURyK2RhT2didWpJekFoTUE0R0ExVWREd0VCL3dRRQpBd0lDcERBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUFvR0NDcUdTTTQ5QkFNQ0EwY0FNRVFDSUV0TkZOeGFvdTAzCjNKdU4rOTZmYlBCK1ZWS0s2YXlYNktEbjNQUDRaVG9hQWlCODNYVUE5blAvVTZGR2VZUGd1ZlBJNHdZN0tuQnIKTjlMaksrM3ZyS3FvWFE9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    server: https://127.0.0.1:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    password: f7d199139f7811255e9cc53802d9e9d4
    username: admin
```

**NOTE**: The following steps were performed on a worker node (new GCE VM) (if you want worker nodes, else skip them and go directly to Installing Apigee Components)

**For each worker node**, perform the following steps:

Step 3a: Copy the kube config from step 2c

```bash
export PATH=/snap/core18/1885/usr/bin:$PATH
mkdir ~/.kube
vi ~/.kube/config
```

Paste the contents from step 2c. Change the server to the actual IP of the master VM

```bash
server: https://127.0.0.1:6443 -----> server: https://10.x.x.x:6443
```

10.x.x.x = master node IP (private IP)

Step 3b: Install k3s

```bash
curl -sfL https://get.k3s.io |INSTALL_K3S_EXEC="--node-ip=$(hostname -I)" K3S_URL="https://10.138.0.32:6443" 
K3S_TOKEN="K10ca7b667cc369282e3fd39e2b46dd3e4b53b91da28a0f49693b6207f6a725b791::server:2db0194382554428786917c8247f
ff65" INSTALL_K3S_VERSION=v1.16.15+k3s1 sh -
```

`--node-ip` is the worker GCE VM IP Address
`K3S_TOKEN` is copied from Step 2b
`K3S_URL` is the IP address of the master node

Step 3c: Get nodes to confirm install

```bash
kubectl get nodes

NAME    STATUS   ROLES    AGE   VERSION
k3s-3   Ready    master   61m   v1.16.15+k3s1
k3s-4   Ready    <none>   53m   v1.16.15+k3s1
```

NOTE: In this case k3s-3 and k3s-4 are the VM names.

### Installing Apigee Components

Step 1: No changes to installing cert-manager

```bash
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.1/cert-manager.yaml
```

Step 2a: Create a new Istio profile.

```bash
cp ~/istio-1.7.3/manifests/profiles/minimal.yaml ~/istio-1.7.3/manifests/profiles/apigee-minimal.yaml
```

Step 2b: Edit the apigee-minimal profile to look like [this](./apigee-minimal.yaml)

Step 2c: Install istio (from the ISTIO_INSTALL folder)

```bash
istioctl install --manifests=./manifests --set profile=apigee-minimal
```

Step 2d: Ensure all the Apigee hybrid control plane components are created:

1. An Apigee org exists
2. An environment and environment group exist
3. A service account with all permissions
4. Run setSyncAuth to give the SA permissions to sync from ctrl plane

Step 2e: Install Apigee hybrid - no changes.

Create symlinks for `apigeectl`:

```bash
cd ~
ln -s ./apigeectl_1.3.3-4cbb601_linux_64/config config
ln -s ./apigeectl_1.3.3-4cbb601_linux_64/templates templates
ln -s ./apigeectl_1.3.3-4cbb601_linux_64/plugins plugins
ln -s ./apigeectl_1.3.3-4cbb601_linux_64/tools tools
```

Create self-signed certs:

```bash
cd ~ && mkdir certs && cd certs
openssl genrsa -out tls.key 2048
openssl req -x509 -new -nodes -key tls.key -subj "/CN=api.srinandans.com" -days 3650 -out tls.crt
```

NOTE: I've used a single GCP SA with:

* Apigee Organization Admin
* Apigee Runtime Agent
* Apigee Synchronizer Manager
* Apigee Connect Agent
* Apigee Analytics Agent
* Monitoring Admin

Here is a minimal [config](./overrides.yaml)

Install the hybrid pods

```bash
apigeectl init -f overrides.yaml

apigeectl apply -f overrides.yaml
```

Step 2f: Test an API Proxy

Get the port

```bash
kubectl get svc -n istio-system istio-ingressgateway -o wide
NAME                   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)              AGE    SELECTOR
istio-ingressgateway   NodePort    10.43.87.55   <none>        443:*31361*/TCP
```

Assuming you are logged into the VM where the pod is scheduled, you can try:

```bash
curl https://api.srinandans.com:*31361*/orders -kv --resolve "api.srinandans.com:31361:127.0.0.1"
```

Ensure the domain matches the environment group settings.

OPTIONAL

If you want to send traffic to the runtime pod directly:

Get the cluster IP of the the runtime pod

```bash
kubectl get svc -n apigee -l app=apigee-runtime | awk '{print $3}'

10.43.191.190
```

Run a cURL command

```bash
kubectl run curl --generator=run-pod/v1 -it --image=radial/busyboxplus:curl


curl https://10.43.191.190:8443/orders -vk
exit
```

### Access from Cloud Shell

Step 1:  Create a firewall rule for k3s http port, 6443

gcloud compute firewall-rules create https-k3s \

--action ALLOW --rules tcp:6443 \

--source-ranges 0.0.0.0/0 --direction INGRESS --network $NETWORK

Step 2: Add tag to a node, ie, k3s-1 to expose the 6443 port

```bash
gcloud compute instances add-tags k3s-1 \
    --zone $zone \
    --tags https-k3s
```

Step 3: To configure kubectl setting to access our default cluster, create/edit the .kube/config at cloudshell:

```bash
mkdir ~/.kube

vi ~/.kube/config
```

Paste the content into the file

```yaml
## remove certificate, edit server ip, change admin password
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://xxxxxx:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
users:
- name: default
  user:
    password: 80ebf32a09b2400dbbc7921543e76088
    username: admin
```

You should be able to use kubectl from cloud shell