# 🛍️ Sock Shop Demo · Azure Kubernetes Service (AKS) Edition

> A reference microservices demo (14 services across 4 runtimes, 3 databases, RabbitMQ + Redis), fully adapted for production-grade deployment on **Azure Kubernetes Service (AKS)** with end-to-end observability (Prometheus + Grafana).

---

## 1. Project Overview

The [Sock Shop](https://microservices-demo.github.io/) is a classic e-commerce microservices reference architecture. It simulates an online sock store with **14 interdependent microservices**:

| Tier          | Services                                                                 | Runtime / Stack                          |
|---------------|--------------------------------------------------------------------------|------------------------------------------|
| Front-end     | `front-end`                                                              | Node.js SPA, Redis-backed sessions       |
| Business APIs | `carts`, `catalogue`, `orders`, `payment`, `shipping`, `user`            | Java Spring Boot × 4, Go × 3             |
| Async worker  | `queue-master`                                                           | Java Spring Boot + RabbitMQ consumer     |
| Data stores   | `carts-db`, `orders-db`, `user-db`, `catalogue-db`, `session-db`, `rabbitmq` | MongoDB × 3, MariaDB, Redis, RabbitMQ    |

Each service is packaged as a container, and the entire stack is deployed onto AKS via Kustomize layered manifests under `manifests/aks/`. Observability is provided by the kube-prometheus-stack Helm chart: Prometheus scrapes in-cluster metrics via ServiceMonitors, Grafana ships with two pre-provisioned dashboards (AKS cluster + Sock Shop RED metrics), and Alertmanager fires SLO-based alerts.

### Key AKS adaptations applied in this repo

| Concern                        | Fix / Feature in `manifests/aks/`                                                                                                   |
|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| **Pod Security**               | `sock-shop` namespace enforces PSA `restricted` (runAsNonRoot, drop ALL caps, readOnlyRootFilesystem where possible).                |
| **Image Pull Policy**          | `IfNotPresent` everywhere — uses AKS node image cache, cuts pod startup time vs. `Always`.                                         |
| **Config / Secrets**           | All hostnames, ports, JVM flags, DB usernames/passwords injected through `ConfigMap` + `Secret` via `envFrom` / `secretKeyRef`.    |
| **Ingress**                    | Kubernetes `Ingress` (NGINX or AGIC) for `front-end`, **not** NodePort / OpenShift Route.                                          |
| **Probes**                     | Liveness + Readiness HTTP/exec probes with tuned `initialDelaySeconds` for each runtime stack.                                     |
| **Resource Governance**        | `ResourceQuota` + `LimitRange` in each namespace prevent noisy-neighbour issues.                                                   |
| **Observability**              | `prometheus.io/*` Pod annotations + explicit `ServiceMonitor` / `PodMonitor` CRs + SLO `PrometheusRule`s.                          |
| **Storage**                    | Databases use ephemeral `emptyDir` (demo-only). Prometheus and Grafana use `managed-csi` Azure Disk PVCs for durability.           |

---

## 2. Prerequisites Checklist

> ⚠️ **Please tick every item before you start.** Deploying without the prerequisites usually fails at the first `kubectl apply`.

### 2.1 Required tools on your workstation

| Tool         | Minimum version | Install / verify                                                                                              |
|--------------|-----------------|---------------------------------------------------------------------------------------------------------------|
| `az` CLI     | ≥ 2.50          | `brew install azure-cli` / [linux install](https://learn.microsoft.com/cli/azure/install-azure-cli-linux). Verify: `az --version` |
| `kubectl`    | ≥ 1.28          | `az aks install-cli` installs it for you. Verify: `kubectl version --client`                                  |
| `helm`       | ≥ 3.13          | `brew install helm` / [get.helm.sh](https://get.helm.sh). Verify: `helm version`                              |
| `docker`     | any             | Only required if you rebuild images and push to ACR.                                                          |

### 2.2 Azure resources & permissions

1. **An Azure subscription** with enough quota for at least one AKS cluster.
2. **AKS cluster** (recommended SKU: 1× `Standard_DS2_v2` System node + 2× `Standard_D2s_v3` User nodes — enough for the demo + monitoring).
   - Required add-ons / features:
     - **Azure CNI** networking (default is fine; Kubenet works too).
     - **Managed Identity** (`--enable-managed-identity`) — simpler than SPNs for ACR pull & CSI.
     - Optional: `--enable-addons http_application_routing` (if you want the built-in Ingress Controller + DNS) OR install NGINX separately (step 5.3).
3. **Azure Container Registry (ACR)** in the same tenant/region as AKS, with **`AcrPull` role assigned to the AKS kubelet identity** (the easy way is `az aks update -n $AKS -g $RG --attach-acr $ACR`).
4. **Your AAD identity** needs, at a minimum:
   - `Azure Kubernetes Service Cluster Admin Role` on the AKS resource (to merge kubeconfig via `az aks get-credentials --admin`).
   - `AcrPush` on the ACR resource if you intend to rebuild and push images.

### 2.3 Quick sanity tests before you deploy

```bash
# 1. Azure login & default subscription
az login
az account set --subscription "<your-subscription-id>"
az account show --query '{name:name,id:id}' -o tsv

# 2. Kubeconfig merged & cluster reachable
az aks get-credentials -g $RESOURCE_GROUP -n $AKS_CLUSTER_NAME --admin --overwrite-existing
kubectl cluster-info                  # should print "Kubernetes control plane ..."

# 3. ACR reachable from your laptop (push test images, optional)
az acr login -n $ACR_NAME
docker pull hello-world:latest
docker tag hello-world:latest ${ACR_NAME}.azurecr.io/hello-world:v1
docker push ${ACR_NAME}.azurecr.io/hello-world:v1
```

All three pass? Proceed.

---

## 3. Project Layout

```
sock-shop-on-aks/
├── Dockerfile/                       # Dockerfiles for the 10 app images
├── manifests/
│   ├── base/                         # Original OpenShift base (reference only)
│   ├── overlays/                     # Original OpenShift overlays (reference only)
│   ├── aks/                          # ⭐ PRIMARY DEPLOY TARGET: AKS-adapted Kustomize
│   │   ├── kustomization.yaml
│   │   ├── config.env                # ⚙️ Non-sensitive configs (hostnames, JVM flags…)
│   │   ├── 00-sock-shop-ns.yaml
│   │   ├── 00-sock-shop-configmap.yaml
│   │   ├── 00-sock-shop-secret.yaml  # 🔐 All credentials (DB usernames / passwords)
│   │   ├── 00-sock-shop-quota.yaml
│   │   ├── 01~28 {carts,catalogue,front-end,orders,payment,queue-master,rabbitmq,session-db,shipping,user}{-db} dep+svc
│   │   └── 10-front-end-ingress.yaml
│   └── monitoring/                   # 📊 Prometheus + Grafana Helm values + CRs
│       ├── 00-monitoring-ns.yaml
│       ├── 00-monitoring-quota.yaml
│       ├── kube-prometheus-stack-values.yaml
│       ├── sock-shop-servicemonitor.yaml
│       ├── sock-shop-podmonitor.yaml
│       ├── sock-shop-prometheusrules.yaml
│       ├── grafana-datasource.yaml
│       ├── grafana-dashboard-aks-cluster.yaml
│       ├── grafana-dashboard-sock-shop-app.yaml
│       ├── prometheus-standalone-values.yaml    # (optional) minimal Prometheus
│       └── grafana-standalone-values.yaml       # (optional) standalone Grafana
└── README.md                         # You are here
```

---

## 4. Step-by-Step Deployment Guide

Variables used in every command below — **copy/paste this block first** with your real values:

```bash
export RESOURCE_GROUP="rg-sockshop-aks"
export AKS_CLUSTER_NAME="aks-sockshop-001"
export ACR_NAME="acrsockshop001"
export AKS_REGION="westeurope"
export IMG_PREFIX="quay.io/powercloud"
export PUBLIC_HOSTNAME="sock-shop.example.com"
```

### Step 1 — Merge kubeconfig and verify AKS access

```bash
az aks get-credentials -g $RESOURCE_GROUP -n $AKS_CLUSTER_NAME --admin --overwrite-existing
kubectl get nodes -o wide
kubectl get ns
```

### Step 2 (Optional) — Mirror images to your Azure Container Registry

```bash
az acr login -n $ACR_NAME
for svc in carts catalogue catalogue-db front-end orders payment queue-master shipping user user-db; do
  SRC="quay.io/powercloud/sock-shop-${svc}:latest"
  DST="${ACR_NAME}.azurecr.io/sock-shop/${svc}:latest"
  docker pull $SRC && docker tag $SRC $DST && docker push $DST
done
for IMG in "mongo:4" "rabbitmq:3.11.19-management" "kbudde/rabbitmq-exporter:latest" "redis:7-alpine" "grafana/grafana:10.4.2"; do
  NAME=$(echo $IMG | tr '/' '_' | tr ':' '_')
  SRC=$IMG; DST="${ACR_NAME}.azurecr.io/middleware/${NAME}"
  docker pull $SRC && docker tag $SRC $DST && docker push $DST
done
```

### Step 3 — Dry-run the Kustomize manifests before apply

```bash
cd /root/sock-shop-on-aks/manifests/aks
kubectl kustomize . | grep "^kind:" | sort | uniq -c
kubectl kustomize . | kubectl apply --dry-run=server -f - 2>&1 | tail -15
```

### Step 4 — Deploy the Sock Shop application stack

```bash
kubectl apply -k .
watch -n 5 "kubectl get pods -n sock-shop -o wide"
```

<details>
<summary>❌ Troubleshoot: Pods in CrashLoopBackOff / Pending?</summary>

| State              | Typical root cause                                              | Next diagnostic command                                                                  |
|--------------------|-----------------------------------------------------------------|------------------------------------------------------------------------------------------|
| `ImagePullBackOff` | Missing ACR pull role, typo in `image:` tag                     | `kubectl describe pod <pod> -n sock-shop \| tail -20`                                    |
| `Pending`          | ResourceQuota exhausted or nodeSelector mismatch               | `kubectl describe pod <pod> -n sock-shop \| grep -A5 FailedScheduling`                   |
| `CrashLoopBackOff` | Bad env, cannot reach DB, wrong DB creds                        | `kubectl logs <pod> -n sock-shop --previous`                                             |
| `0/1 Running`      | Probe failing — readiness strips pod from Service endpoints     | `kubectl describe pod <pod> -n sock-shop \| grep -A3 "probe failed"`                     |

</details>

### Step 5 — Health-check three representative stacks

```bash
# carts (Java)
CARTSPOD=$(kubectl get pod -n sock-shop -l name=carts -o name | head -1)
kubectl exec -n sock-shop $CARTSPOD -- wget -qO- http://localhost:8080/actuator/health | jq .
# Expect: {"status":"UP"}

# user (Go)
USERPOD=$(kubectl get pod -n sock-shop -l name=user -o name | head -1)
kubectl exec -n sock-shop $USERPOD -- wget -qO- http://localhost:8080/health
# Expect: {"health":true}

# front-end (Node.js)
FEPOD=$(kubectl get pod -n sock-shop -l name=front-end -o name | head -1)
kubectl exec -n sock-shop $FEPOD -- wget -qO- http://localhost:8079/ | head -5
# Expect: <!DOCTYPE html>
```

### Step 6 — Install NGINX Ingress Controller (one-time, per cluster)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace --version 4.10.0 \
  --set controller.service.type=LoadBalancer --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux

INGRESS_PUB_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "NGINX ingress public IP: $INGRESS_PUB_IP"
export PUBLIC_HOSTNAME="sock-shop.${INGRESS_PUB_IP}.nip.io"
sed -i "s/sock-shop.example.com/${PUBLIC_HOSTNAME}/" /root/sock-shop-on-aks/manifests/aks/10-front-end-ingress.yaml
kubectl apply -k /root/sock-shop-on-aks/manifests/aks
```

### Step 7 — Reach the Sock Shop front-end

```bash
kubectl get ingress -n sock-shop
# Open http://<HOST> in a browser. Confirm: signup / login / add to cart / checkout all work.
```

---

## 5. Monitoring Stack Deployment (Prometheus + Grafana)

### Step 5.1 — Create monitoring namespace and quota

```bash
cd /root/sock-shop-on-aks/manifests/monitoring
kubectl apply -f 00-monitoring-ns.yaml
kubectl apply -f 00-monitoring-quota.yaml
```

### Step 5.2 — Install kube-prometheus-stack via Helm

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --version 58.0.0 \
  --values kube-prometheus-stack-values.yaml --timeout 10m0s
```

### Step 5.3 — Apply Sock Shop ServiceMonitor / PodMonitor / PrometheusRule CRs

```bash
kubectl apply -f sock-shop-servicemonitor.yaml
kubectl apply -f sock-shop-podmonitor.yaml
kubectl apply -f sock-shop-prometheusrules.yaml
```

### Step 5.4 — Apply Grafana datasource + pre-built dashboards

```bash
kubectl apply -f grafana-datasource.yaml
kubectl apply -f grafana-dashboard-aks-cluster.yaml
kubectl apply -f grafana-dashboard-sock-shop-app.yaml
```

### Step 5.5 — Verify everything is scraping

```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090 &
# browser: http://localhost:9090/targets — see serviceMonitor/monitoring/sock-shop-services
echo "Grafana creds: admin / admin123"
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 &
# browser: http://localhost:3000 — see two folders with dashboards.
```

---

## 6. Access URLs & Default Credentials

| Component          | Access method                                                                                                                     | Default credentials             |
|--------------------|-----------------------------------------------------------------------------------------------------------------------------------|---------------------------------|
| **Sock Shop UI**   | (1) Ingress `http://${PUBLIC_HOSTNAME}/`<br>(2) `kubectl port-forward svc/front-end -n sock-shop 8080:80`                        | Any in-app registration        |
| **Prometheus UI**  | (1) Ingress hostname from Helm values<br>(2) `kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090` | Anonymous, no login needed     |
| **Grafana**        | (1) Ingress hostname<br>(2) `kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80`                       | `admin` / `admin123`            |
| **RabbitMQ UI**    | `kubectl port-forward svc/rabbitmq -n sock-shop 15672:15672`                                                                      | `guest` / `guest`               |

---

## 7. Frequently Asked Troubleshooting (Top 10 Hits)

### ❓ Q1 · `ImagePullBackOff` / `ErrImagePull`

| Symptom | Fix |
|---------|-----|
| 401 Unauthorized on `<acr>.azurecr.io` | `az aks update -g $RG -n $AKS --attach-acr $ACR` |
| i/o timeout pulling from public registry | Mirror images to ACR (step 4.2). |
| manifest not found | Verify `image:` tag on Quay / ACR web UI. |

### ❓ Q2 · Ingress 503 Service Unavailable

503 = Service has 0 Endpoints. Check:
- Pods are Ready: `kubectl get pod -n sock-shop -l name=front-end`
- Service endpoints exist: `kubectl get ep front-end -n sock-shop` (should show `10.x.y.z:8079`).

### ❓ Q3 · Ingress 404

- `host:` value in `10-front-end-ingress.yaml` vs browser URL must match exactly.
- If using AGIC instead of NGINX: change ingress.class annotation to `azure/application-gateway`.

### ❓ Q4 · Java services stuck `0/1 Running` forever

Java Spring Boot boots slowly (60-120s). Diagnostic:
```bash
kubectl logs -f deploy/carts -n sock-shop  # wait for "Started ...Application in X seconds"
```
If liveness kills Pods pre-maturely: double `initialDelaySeconds` for liveness + readiness probes in the Deployment spec.

### ❓ Q5 · MongoDB Unauthorized ("not authorized on data to execute command")

Only two causes:
1. Deployment `env` doesn't inject creds. Inspect env vars.
2. Wrong DB name seeded vs queried. Fix then: `kubectl rollout restart deploy/user deploy/user-db -n sock-shop`

### ❓ Q6 · MariaDB "Access denied for user 'root'"

Catalogue DSN is `root:<pass>@tcp(catalogue-db:3306)/socksdb`. Password must equal `sock-shop-creds.mariadb-root-password` (base64 of `admin` by default). Rotate the Secret and delete the Pod (emptyDir re-seeds cleanly).

### ❓ Q7 · Prometheus shows no Sock Shop metrics

Bottom-up:
1. App metrics endpoint alive? `kubectl exec -n sock-shop <pod> -- wget -qO- http://localhost:8080/actuator/prometheus | head`
2. ServiceMonitor exists? `kubectl get sm -A -l release=kube-prometheus-stack`
3. Prometheus Targets: port-forward and check `/targets` for the SMon.

### ❓ Q8 · Grafana dashboards empty after ConfigMap apply

Wait 60-90s for the sidecar. If still empty:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard  # → JSON parse errors
```

### ❓ Q9 · "violates PodSecurity 'restricted'" on a custom container you added

Add `securityContext.runAsNonRoot: true`, `runAsUser: 10001`, `capabilities.drop: [ALL]`, `readOnlyRootFilesystem: true`.

### ❓ Q10 · AKS `InsufficientSubnetSize` / nodes stuck NotReady after scale

Rebuild cluster with larger subnet CIDR per [AKS CNI planning docs](https://learn.microsoft.com/azure/aks/configure-azure-cni#plan-ip-addressing-for-your-cluster).

---

## 8. Cleanup

```bash
helm uninstall kube-prometheus-stack -n monitoring
kubectl delete crds alertmanagerconfigs.monitoring.coreos.com alertmanagers.monitoring.coreos.com podmonitors.monitoring.coreos.com probes.monitoring.coreos.com prometheuses.monitoring.coreos.com prometheusrules.monitoring.coreos.com servicemonitors.monitoring.coreos.com thanosrulers.monitoring.coreos.com 2>/dev/null || true
kubectl delete ns sock-shop monitoring
az aks delete -g $RESOURCE_GROUP -n $AKS_CLUSTER_NAME --yes --no-wait
az acr delete -g $RESOURCE_GROUP -n $ACR_NAME --yes
```

---

## 9. What's Next? (Self-Study Exercises)

1. Use **Azure Workload Identity** + **Secrets Store CSI Driver** to source secrets from AKV (not base64).
2. Replace DB `emptyDir` with `managed-csi` PVCs → drain a node → confirm DB data survives.
3. Load-test (k6 / Locust) with services scaled to 2 replicas → observe p95 in Grafana.
4. Wire Slack / Teams through Alertmanager for `SockShopHigh5xxRate`.

Happy deploying on AKS! 🚀
