# Sock Shop on AKS

A modern delivery solution for the [Sock Shop](https://github.com/microservices-demo/microservices-demo) demo application on **Azure Kubernetes Service (AKS)**, featuring **Helm Chart packaging**, **Terraform IaC**, and **GitHub Actions CI/CD**.

This repository provides two deployment paths:

- **Method 1 — Local / All-in-One Deployment (Quickstart):** apply raw Kubernetes manifests or local Helm commands for fast local testing.
- **Method 2 — Production-Grade GitOps / CI/CD Deployment (Advanced):** provision AKS with Terraform, manage the application and monitoring lifecycle with Helm Charts (multi-environment values), and automate everything with GitHub Actions.

---

## Table of Contents

- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
- [Method 1: Local / All-in-One Deployment (Quickstart)](#method-1-local--all-in-one-deployment-quickstart)
  - [Option A: Raw Kubernetes Manifests](#option-a-raw-kubernetes-manifests)
  - [Option B: Local Helm Deployment](#option-b-local-helm-deployment)
- [Method 2: Production-Grade GitOps / CI/CD Deployment (Advanced)](#method-2-production-grade-gitops--cicd-deployment-advanced)
  - [Step 1: Provision Infrastructure with Terraform](#step-1-provision-infrastructure-with-terraform)
  - [Step 2: Deploy with Helm Charts](#step-2-deploy-with-helm-charts)
  - [Step 3: Automate with GitHub Actions](#step-3-automate-with-github-actions)
- [Demo & Verification Commands](#demo--verification-commands)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)

---

## Directory Structure

```
sock-shop-on-aks/
├── helm-chart/
│   ├── sock-shop/                 # Sock Shop application chart (14 services + Secret + Ingress)
│   │   ├── Chart.yaml
│   │   ├── values.yaml            # Default values (dev baseline)
│   │   ├── values-dev.yaml        # dev environment overrides
│   │   ├── values-prod.yaml       # prod environment overrides
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── secret.yaml
│   │       ├── ingress.yaml
│   │       └── services/          # One template per service (Deployment + Service)
│   └── monitoring/                # Monitoring chart (Prometheus + Grafana + Node Exporter)
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── ingress.yaml
│           ├── prometheus/        # RBAC + ConfigMap + Deployment + Service
│           ├── grafana/           # ConfigMap + Deployment + Service
│           └── node-exporter/     # DaemonSet + Service
├── terraform/                      # IaC: Resource Group + AKS cluster + NGINX Ingress Controller
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── terraform.tfvars.example
├── .github/workflows/
│   ├── deploy.yml                 # Application deployment pipeline (Lint + Deploy)
│   └── terraform.yml              # Infrastructure pipeline (Plan + Apply)
└── all-in-one-deploy/             # (Retained) original loose YAML manifests, for reference or removal
```

> **Note:** The `monitoring` chart currently ships a single `values.yaml`. The `sock-shop` chart ships `values.yaml`, `values-dev.yaml`, and `values-prod.yaml` for multi-environment overrides.

---

## Prerequisites

| Tool       | Version   | Verification Command          |
|------------|-----------|-------------------------------|
| Azure CLI  | ≥ 2.50    | `az --version`                |
| kubectl    | ≥ 1.28    | `kubectl version --client`    |
| Helm       | ≥ 3.13    | `helm version`                |
| Terraform  | ≥ 1.5     | `terraform version`           |

---

## Method 1: Local / All-in-One Deployment (Quickstart)

This method is ideal for quick local testing. It assumes you already have an AKS cluster (or any Kubernetes cluster) with the **NGINX Ingress Controller** installed.

### Option A: Raw Kubernetes Manifests

Apply the loose manifests in [`all-in-one-deploy/`](all-in-one-deploy) directly with `kubectl`:

```bash
# Create the sock-shop namespace
kubectl apply -f all-in-one-deploy/namespace.yaml

# Deploy the Sock Shop microservices and the catalogue-db Secret
kubectl apply -f all-in-one-deploy/secret.yaml
kubectl apply -f all-in-one-deploy/deployment.yaml

# Deploy the monitoring stack (Prometheus + Grafana + Node Exporter)
kubectl apply -f all-in-one-deploy/monitoring.yaml

# Apply the Ingress rules (edit the hosts first if needed)
kubectl apply -f all-in-one-deploy/ingress.yaml
```

> **Note:** The manifests in [`all-in-one-deploy/`](all-in-one-deploy) use the `sock-shop` and `monitoring` namespaces. Edit the `host` fields in [`all-in-one-deploy/ingress.yaml`](all-in-one-deploy/ingress.yaml) to match your own domain.

### Option B: Local Helm Deployment

Deploy the charts directly from this repository with Helm:

```bash
# Deploy the Sock Shop application (dev environment)
helm upgrade --install sock-shop helm-chart/sock-shop \
  -f helm-chart/sock-shop/values-dev.yaml \
  --namespace sock-shop-dev --create-namespace --wait

# Deploy the monitoring stack
helm upgrade --install monitoring helm-chart/monitoring \
  -f helm-chart/monitoring/values.yaml \
  --namespace monitoring --create-namespace --wait
```

For a **prod** environment, use the corresponding values file:

```bash
helm upgrade --install sock-shop helm-chart/sock-shop \
  -f helm-chart/sock-shop/values-prod.yaml \
  --namespace sock-shop-prod --create-namespace --wait
```

---

## Method 2: Production-Grade GitOps / CI/CD Deployment (Advanced)

This method provisions the infrastructure with Terraform, manages the application and monitoring lifecycle with Helm Charts, and automates the whole flow with GitHub Actions.

### Step 1: Provision Infrastructure with Terraform

Terraform creates the Resource Group, the AKS cluster, and installs the NGINX Ingress Controller:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit with your own values
terraform init
terraform plan
terraform apply -auto-approve
```

> **Host domain left empty:** This solution does not bind a specific domain. Fill in the Ingress `host` yourself in the Helm values (e.g. `sockshop.lukas.cloud-ip.cc`).

Retrieve the kubeconfig:

```bash
export RESOURCE_GROUP="rg-sockshop"
export AKS_CLUSTER_NAME="aks-sockshop"
az aks get-credentials -g $RESOURCE_GROUP -n $AKS_CLUSTER_NAME --admin --overwrite-existing
```

### Step 2: Deploy with Helm Charts

#### Sock Shop — dev environment

```bash
helm upgrade --install sock-shop helm-chart/sock-shop \
  -f helm-chart/sock-shop/values-dev.yaml \
  --namespace sock-shop-dev --create-namespace --wait
```

#### Sock Shop — prod environment

```bash
helm upgrade --install sock-shop helm-chart/sock-shop \
  -f helm-chart/sock-shop/values-prod.yaml \
  --namespace sock-shop-prod --create-namespace --wait
```

#### Configure the Ingress host domain

Edit the values file for the target environment and fill in your domain:

```yaml
# helm-chart/sock-shop/values-dev.yaml
ingress:
  enabled: true
  className: nginx
  host: "sockshop-dev.lukas.cloud-ip.cc"   # <-- fill in your own value
```

Then re-run the corresponding `helm upgrade` command.

#### Monitoring

The unified monitoring chart (Prometheus + Grafana + Node Exporter) is deployed with a single `values.yaml`:

```bash
helm upgrade --install monitoring helm-chart/monitoring \
  -f helm-chart/monitoring/values.yaml \
  --namespace monitoring --create-namespace --wait
```

Configure the Prometheus / Grafana domains:

```yaml
# helm-chart/monitoring/values.yaml
ingress:
  enabled: true
  className: nginx
  prometheusHost: "prometheus.lukas.cloud-ip.cc"   # <-- fill in your own value
  grafanaHost: "grafana.lukas.cloud-ip.cc"         # <-- fill in your own value
```

Access Grafana (default `admin` / `admin123`):

```bash
kubectl port-forward svc/grafana -n monitoring 3000:80
# → http://localhost:3000
```

### Step 3: Automate with GitHub Actions

#### Required GitHub Secrets

| Secret                    | Description                                              |
|---------------------------|----------------------------------------------------------|
| `AZURE_CREDENTIALS`       | Azure service principal JSON (used for application deployment) |
| `AZURE_CLIENT_ID`         | Service principal Client ID (used for Terraform)         |
| `AZURE_CLIENT_SECRET`     | Service principal Client Secret                          |
| `AZURE_SUBSCRIPTION_ID`   | Azure subscription ID                                    |
| `AZURE_TENANT_ID`         | Azure tenant ID                                          |
| `AZURE_RESOURCE_GROUP`    | Resource group containing the AKS cluster                |
| `AZURE_CLUSTER_NAME`      | AKS cluster name                                         |

#### Create a Service Principal

```bash
az ad sp create-for-rbac --name "sockshop-cicd" --role Contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/rg-sockshop \
  --sdk-auth
```

Store the returned JSON in the `AZURE_CREDENTIALS` secret.

#### Pipeline Overview

The two workflows are orchestrated so that infrastructure is provisioned **before** the application is deployed:

1. **[`terraform.yml`](.github/workflows/terraform.yml):** triggered on push to `terraform/` (or manually) → `terraform fmt/validate/plan/apply` to provision the Resource Group, AKS cluster, and NGINX Ingress Controller.
2. **[`deploy.yml`](.github/workflows/deploy.yml):** triggered on push to `main` (or manually), **and automatically after `terraform.yml` completes successfully** (via `workflow_run`) → `helm lint` + `helm template` validation → `az login` → `helm upgrade` to deploy the Sock Shop and monitoring stacks.

> **Note:** When `deploy.yml` is triggered by `workflow_run`, the deployment environment defaults to `dev` (the `workflow_dispatch` `environment` input is not available in that trigger). Use the manual trigger to select `prod`.

---

## Demo & Verification Commands

Use these commands for live demos and quick validation.

### Check Pod status across namespaces

```bash
kubectl get pods -n sock-shop-dev
kubectl get pods -n monitoring
```

For the prod environment:

```bash
kubectl get pods -n sock-shop-prod
```

### Retrieve the public LoadBalancer IP of the Ingress Controller

The NGINX Ingress Controller is deployed as a `LoadBalancer` service. Get its public IP to configure DNS (e.g. in ClouDNS):

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Point your domain's `A` record (or `CNAME`) to the `EXTERNAL-IP` shown in the output.

### Port-forwarding for quick local validation

```bash
# Access the Sock Shop front-end
kubectl port-forward svc/front-end -n sock-shop-dev 8080:80
# → http://localhost:8080

# Access Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80
# → http://localhost:3000

# Access Prometheus
kubectl port-forward svc/prometheus -n monitoring 9090:9090
# → http://localhost:9090
```

### Health checks

```bash
# Verify the front-end service responds
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/

# Check the readiness of all pods in a namespace
kubectl get pods -n sock-shop-dev -o wide
kubectl describe pod -n sock-shop-dev -l name=front-end
```

---

## Cleanup

```bash
# Uninstall the Helm releases
helm uninstall monitoring -n monitoring
helm uninstall sock-shop -n sock-shop-dev

# Or destroy the entire cluster
cd terraform && terraform destroy -auto-approve
```

---

## Troubleshooting

| Symptom                    | Cause & Fix                                                                                       |
|----------------------------|---------------------------------------------------------------------------------------------------|
| `ImagePullBackOff`         | Image cannot be pulled: `az aks update -g $RG -n $AKS --attach-acr $ACR` or switch to public images (default) |
| Front-end Ingress returns 503 | Pod is not Ready yet: `kubectl describe pod -n sock-shop-dev -l name=front-end`                  |
| Java services start slowly | Spring Boot cold start takes 60–120s; probe `initialDelaySeconds` is already set to 300            |
| MongoDB Unauthorized       | Delete and recreate the Pod: `kubectl delete pod -n sock-shop-dev -l name=carts-db`                |
| catalogue-db Access denied | Password does not match the Secret: `kubectl get secret catalogue-db-secret -n sock-shop-dev -o jsonpath={.data.MYSQL_ROOT_PASSWORD} \| base64 -d` |
