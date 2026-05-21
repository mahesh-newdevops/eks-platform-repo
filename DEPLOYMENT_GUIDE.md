# Full Platform Deployment Guide

This repository contains Infrastructure as Code (IaC) for deploying a **production-ready EKS cluster** with integrated AWS services, Kubernetes add-ons, and a complete observability stack.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Options](#deployment-options)
- [Post-Deployment Setup](#post-deployment-setup)
- [Accessing Services](#accessing-services)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

---

## 🏗️ Architecture Overview

### Core Components

```
┌─────────────────────────────────────────────────────┐
│              AWS EKS Cluster (v1.27)                │
│  ┌──────────────────────────────────────────────┐  │
│  │      Kubernetes Add-ons                      │  │
│  │  • VPC-CNI (Networking)                      │  │
│  │  • EKS Pod Identity Agent (Workload Auth)    │  │
│  │  • AWS EBS CSI Driver (Storage)              │  │
│  └──────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────┐  │
│  │      Helm Deployments                        │  │
│  │  • Karpenter (Auto-scaling)                  │  │
│  │  • AWS Load Balancer Controller (Ingress)    │  │
│  │  • ArgoCD (GitOps)                           │  │
│  │  • Prometheus + Grafana (Metrics)            │  │
│  │  • Loki + Promtail (Logging)                 │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
        │
        ├─ OIDC Provider (Workload Identity)
        ├─ IAM Roles & Policies
        ├─ Security Groups
        ├─ VPC & Subnets
        └─ CloudWatch Logs
```

### Deployed Services

| Service | Type | Purpose |
|---------|------|---------|
| **EKS Cluster** | Core Infrastructure | Managed Kubernetes cluster |
| **Karpenter** | Auto-scaler | Dynamic node provisioning |
| **ALB Controller** | Ingress | Load balancing for applications |
| **ArgoCD** | GitOps | Declarative continuous deployment |
| **Prometheus** | Monitoring | Metrics collection & alerting |
| **Grafana** | Visualization | Dashboards for monitoring |
| **Loki** | Logging | Log aggregation & querying |

---

## 📋 Prerequisites

### Local Requirements

1. **AWS CLI v2**
   ```bash
   aws --version
   ```

2. **Terraform v1.7+**
   ```bash
   terraform version
   ```

3. **kubectl v1.27+**
   ```bash
   kubectl version --client
   ```

4. **Helm v3.12+**
   ```bash
   helm version
   ```

### AWS Account Requirements

1. **AWS Account with appropriate permissions:**
   - EC2, VPC, IAM, EKS, CloudWatch

2. **AWS Role ARN** (for GitHub Actions)
   - Format: `arn:aws:iam::ACCOUNT-ID:role/ROLE-NAME`
   - Set as GitHub organization secret: `TERRAFORMAWS`

3. **AWS Credentials**
   ```bash
   export AWS_ACCESS_KEY_ID=<your-access-key>
   export AWS_SECRET_ACCESS_KEY=<your-secret-key>
   export AWS_DEFAULT_REGION=ap-south-1
   ```

---

## 🚀 Quick Start

### Local Deployment

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd full-platform-repo
   ```

2. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   ```

3. **Plan the deployment**
   ```bash
   terraform plan -out=tfplan
   ```

4. **Apply the configuration**
   ```bash
   terraform apply tfplan
   ```

5. **Configure kubectl**
   ```bash
   aws eks update-kubeconfig --region ap-south-1 --name my-cluster
   kubectl get nodes
   ```

---

## 🔧 Deployment Options

### Option 1: GitHub Actions (Recommended for CI/CD)

1. **Set up GitHub secrets**
   - In your GitHub organization, add secret `TERRAFORMAWS`
   - Value: `arn:aws:iam::ACCOUNT-ID:role/github-actions-eks-role`

2. **Trigger workflow**
   - Go to **Actions** tab
   - Select **EKS Platform Deployment**
   - Click **Run workflow**
   - Choose action: `apply` or `destroy`

3. **Monitor deployment**
   - View logs in the workflow run

### Option 2: Local Deployment

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Option 3: Destroy Infrastructure

```bash
cd terraform
terraform destroy
```

---

## 📡 Post-Deployment Setup

### 1. Verify Cluster Health

```bash
# Check node status
kubectl get nodes

# Check add-ons
kubectl get daemonsets -n kube-system
kubectl get deployments -n kube-system

# Check pod status
kubectl get pods --all-namespaces
```

### 2. Configure ArgoCD

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forward to access ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Access at: https://localhost:8080
```

### 3. Configure Prometheus & Grafana

```bash
# Port forward to Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access at: http://localhost:3000
# Default credentials: admin/admin123
```

### 4. Verify Karpenter

```bash
# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Check provisioners
kubectl get provisioners

# Check nodes provisioned by Karpenter
kubectl get nodes -L karpenter.sh/provisioner-name
```

---

## 🌐 Accessing Services

### ArgoCD WebUI
- **URL:** `https://<cluster-alb>:443/argocd` (when ingress configured)
- **Local:** `kubectl port-forward -n argocd svc/argocd-server 8080:443`
- **Default credentials:** admin / (retrieve from secret)

### Grafana Dashboards
- **URL:** `http://<cluster-alb>/grafana` (when ingress configured)
- **Local:** `kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80`
- **Default credentials:** admin / admin123

### Prometheus
- **URL:** `http://<cluster-alb>/prometheus` (when ingress configured)
- **Local:** `kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090`

### Loki Logs
- **Access via Grafana:** Explore → Select `Loki` as data source

---

## 📊 Monitoring & Observability

### Key Metrics to Monitor

1. **Cluster Health**
   - Node count and utilization
   - Pod count and status
   - API server latency

2. **Application Metrics**
   - Request rate and latency
   - Error rate
   - Resource utilization

3. **System Logs**
   - Application logs (via Loki)
   - System events
   - Error traces

### Sample Queries

**Prometheus:**
```promql
# CPU usage per node
node_cpu_seconds_total

# Memory usage
node_memory_MemAvailable_bytes

# Pod restarts
rate(kube_pod_container_status_restarts_total[15m])
```

**Loki:**
```logql
# All logs from namespace
{namespace="default"}

# Error logs
{job="kubelet"} | "error"

# Specific pod logs
{pod_name="my-pod", namespace="default"}
```

---

## 🔍 Troubleshooting

### Nodes Not Scaling with Karpenter

```bash
# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# Verify provisioner configuration
kubectl describe provisioner

# Check if consolidation is enabled
kubectl get provisioner -o yaml
```

### ArgoCD Applications Stuck

```bash
# Check application status
kubectl get applications -n argocd

# Describe specific app
kubectl describe application <app-name> -n argocd

# Sync app manually
argocd app sync <app-name>
```

### High Memory Usage

```bash
# Check resource requests/limits
kubectl describe node <node-name>

# Identify memory-heavy pods
kubectl top pods --all-namespaces --sort-by=memory

# Check metrics in Grafana
```

### Network Issues

```bash
# Test pod-to-pod connectivity
kubectl exec -it <pod-name> -- sh
ping <target-pod-ip>

# Check security groups
aws ec2 describe-security-groups --region ap-south-1

# View VPC flow logs (if enabled)
```

---

## 🧹 Cleanup

### Destroy All Infrastructure

```bash
cd terraform
terraform destroy

# Confirm by typing 'yes'
```

### Manual Cleanup (if needed)

```bash
# Remove Helm releases manually
helm uninstall -n monitoring prometheus
helm uninstall -n monitoring loki
helm uninstall -n argocd argocd
helm uninstall -n karpenter karpenter
helm uninstall -n kube-system aws-load-balancer-controller

# Delete EKS cluster (if terraform destroy fails)
aws eks delete-cluster --name my-cluster --region ap-south-1

# Clean up VPC and subnets
aws ec2 describe-vpcs --region ap-south-1
```

---

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Karpenter Documentation](https://karpenter.sh/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)

---

## 📝 Configuration Files

| File | Purpose |
|------|---------|
| `terraform/main.tf` | Core Terraform configuration |
| `terraform/outputs.tf` | Output values and resource identifiers |
| `terraform/providers.tf` | Provider configurations |
| `terraform/variables.tf` | Input variables |
| `terraform/versions.tf` | Terraform and provider versions |
| `kubernetes/monitoring/prometheus-values.yaml` | Prometheus Helm values |
| `kubernetes/monitoring/loki-values.yaml` | Loki Helm values |
| `.github/workflows/eks-platform.yml` | GitHub Actions workflow |

---

## 🤝 Support

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review logs: `kubectl logs`, `terraform show`
3. Open an issue with:
   - Error messages
   - Terraform state (sanitized)
   - kubectl diagnostics output

---

**Last Updated:** May 20, 2026
**Version:** 1.0.0
