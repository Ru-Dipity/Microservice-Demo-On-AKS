# Sock Shop on AKS

Sock Shop Demo 在 Azure Kubernetes Service (AKS) 上的现代化交付方案，包含 **Helm Chart 封装**、**Terraform IaC** 与 **GitHub Actions CI/CD**。

## 目录结构

```
sock-shop-on-aks/
├── helm-chart/
│   ├── sock-shop/                 # Sock Shop 应用 Chart（14 个服务 + Secret + Ingress）
│   │   ├── Chart.yaml
│   │   ├── values.yaml            # 默认值（dev 基准）
│   │   ├── values-dev.yaml        # dev 环境覆盖
│   │   ├── values-prod.yaml       # prod 环境覆盖
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── namespace.yaml
│   │       ├── secret.yaml
│   │       ├── ingress.yaml
│   │       └── services/          # 每个服务一个模板（Deployment + Service）
│   └── monitoring/                # 监控 Chart（Prometheus + Grafana + Node Exporter）
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-prod.yaml
│       └── templates/
│           ├── namespace.yaml
│           ├── ingress.yaml
│           ├── prometheus/        # RBAC + ConfigMap + Deployment + Service
│           ├── grafana/           # ConfigMap + Deployment + Service
│           └── node-exporter/     # DaemonSet + Service
├── terraform/                      # IaC：RG + AKS 集群 + NGINX Ingress Controller
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── terraform.tfvars.example
├── .github/workflows/
│   ├── deploy.yml                 # 应用部署流水线（Lint + 部署）
│   └── terraform.yml              # 基础设施流水线（Plan + Apply）
└── all-in-one-deploy/                 # （保留）原始散落 YAML，可参考或删除
```

## 前置要求

| 工具       | 版本   | 验证命令                      |
|------------|--------|-------------------------------|
| Azure CLI  | ≥ 2.50 | `az --version`                |
| kubectl    | ≥ 1.28 | `kubectl version --client`    |
| Helm       | ≥ 3.13 | `helm version`                |
| Terraform  | ≥ 1.5  | `terraform version`           |

## 一、Terraform 基础设施（可选，一次性）

用 Terraform 创建 Resource Group、AKS 集群并安装 NGINX Ingress Controller：

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # 修改为你自己的值
terraform init
terraform plan
terraform apply -auto-approve
```

> **host 域名留空**：本方案不绑定具体域名，Ingress host 由你在 Helm values 中自行填写（如 `sockshop.lukas.cloud-ip.cc`）。

获取 kubeconfig：

```bash
export RESOURCE_GROUP="rg-sockshop"
export AKS_CLUSTER_NAME="aks-sockshop"
az aks get-credentials -g $RESOURCE_GROUP -n $AKS_CLUSTER_NAME --admin --overwrite-existing
```

## 二、Helm 部署 Sock Shop

### dev 环境

```bash
helm upgrade --install sock-shop helm-chart/sock-shop \
  -f helm-chart/sock-shop/values-dev.yaml \
  --namespace sock-shop-dev --create-namespace --wait
```

### prod 环境

```bash
helm upgrade --install sock-shop helm-chart/sock-shop \
  -f helm-chart/sock-shop/values-prod.yaml \
  --namespace sock-shop-prod --create-namespace --wait
```

### 配置 Ingress host 域名

编辑对应环境的 values 文件，填入你的域名：

```yaml
# helm-chart/sock-shop/values-dev.yaml
ingress:
  enabled: true
  className: nginx
  host: "sockshop-dev.lukas.cloud-ip.cc"   # <-- 自行填写
```

然后重新执行 `helm upgrade`。

## 三、Helm 部署 Monitoring

### dev 环境

```bash
helm upgrade --install monitoring helm-chart/monitoring \
  -f helm-chart/monitoring/values-dev.yaml \
  --namespace monitoring-dev --create-namespace --wait
```

### prod 环境

```bash
helm upgrade --install monitoring helm-chart/monitoring \
  -f helm-chart/monitoring/values-prod.yaml \
  --namespace monitoring-prod --create-namespace --wait
```

配置 Prometheus / Grafana 域名：

```yaml
# helm-chart/monitoring/values-dev.yaml
ingress:
  enabled: true
  className: nginx
  prometheusHost: "prometheus.lukas.cloud-ip.cc"   # <-- 自行填写
  grafanaHost: "grafana.lukas.cloud-ip.cc"         # <-- 自行填写
```

访问（默认 admin / admin123）：

```bash
kubectl port-forward svc/grafana -n monitoring-dev 3000:80
# → http://localhost:3000
```

## 四、GitHub Actions CI/CD

### 需要配置的 GitHub Secrets

| Secret | 说明 |
|--------|------|
| `AZURE_CREDENTIALS` | Azure 服务主体 JSON（用于应用部署） |
| `AZURE_CLIENT_ID` | 服务主体 Client ID（用于 Terraform） |
| `AZURE_CLIENT_SECRET` | 服务主体 Client Secret |
| `AZURE_SUBSCRIPTION_ID` | Azure 订阅 ID |
| `AZURE_TENANT_ID` | Azure 租户 ID |
| `RESOURCE_GROUP` | AKS 所在资源组 |
| `CLUSTER_NAME` | AKS 集群名称 |

### 创建服务主体

```bash
az ad sp create-for-rbac --name "sockshop-cicd" --role Contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/rg-sockshop \
  --sdk-auth
```

将输出的 JSON 存入 `AZURE_CREDENTIALS`。

### 流水线说明

- **`deploy.yml`**：push 到 `main`（或手动触发）→ `helm lint` + `helm template` 校验 → `az login` → `helm upgrade` 部署 sock-shop 与 monitoring。
- **`terraform.yml`**：push 到 `terraform/`（或手动触发）→ `terraform fmt/validate/plan/apply`。

## 清理

```bash
helm uninstall monitoring -n monitoring-dev
helm uninstall sock-shop -n sock-shop-dev
# 或删除整个集群
cd terraform && terraform destroy -auto-approve
```

## 常见问题排查

| 现象                      | 原因 & 修复命令                                                                 |
|---------------------------|---------------------------------------------------------------------------------|
| `ImagePullBackOff`        | 镜像拉不到：`az aks update -g $RG -n $AKS --attach-acr $ACR` 或改用公共镜像（默认） |
| 前端 Ingress 返回 503     | Pod 还没 Ready：`kubectl describe pod -n sock-shop-dev -l name=front-end`         |
| Java 服务启动慢           | Spring Boot 冷启动 60~120s，探针 initialDelaySeconds 已设 300                     |
| MongoDB Unauthorized      | 删 Pod 重建：`kubectl delete pod -n sock-shop-dev -l name=carts-db`               |
| catalogue-db Access denied| 密码没对上 Secret：`kubectl get secret catalogue-db-secret -n sock-shop-dev -o jsonpath={.data.MYSQL_ROOT_PASSWORD} \| base64 -d` |
