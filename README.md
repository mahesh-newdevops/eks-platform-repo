# EKS Platform Infrastructure

Terraform-managed AWS EKS platform infrastructure. This repository is scoped to the cluster platform only: Terraform, EKS, AWS-managed EKS add-ons, ArgoCD installation, and the ArgoCD root app bootstrap.

Application workloads and optional platform add-ons should live in a separate GitOps repository. Point the ArgoCD root app variables at that repository when you are ready to manage them externally.

## What This Deploys

- Dedicated AWS VPC with public subnets for EKS
- EKS cluster using `terraform-aws-modules/eks/aws`
- AWS EKS add-ons:
  - CoreDNS
  - kube-proxy
  - VPC CNI
  - EKS Pod Identity Agent
  - AWS EBS CSI Driver with IRSA
- ArgoCD installed by Helm
- ArgoCD root app bootstrapped as an app-of-apps

## Workflows

- `.github/workflows/s3-backend.yml` creates or destroys the S3 bucket and DynamoDB table used by the Terraform backend.
- `.github/workflows/aws-budget-alert.yml` creates, updates, or destroys an AWS monthly cost budget.
- `.github/workflows/eks-platform.yml` applies or destroys the EKS platform and bootstraps ArgoCD.
- `.github/workflows/iac-scan.yml` scans Terraform, Kubernetes bootstrap manifests, and workflows for IaC misconfigurations and committed secrets.

## Configure

Edit `terraform/terraform.tfvars` before applying:

```hcl
region                         = "ap-south-1"
environment                    = "dev"
cluster_name                   = "platform-eks"
argocd_root_app_repo_url        = "https://github.com/YOUR_ORG/platform-repo.git"
argocd_root_app_target_revision = "HEAD"
argocd_root_app_path            = "kubernetes/argocd/apps"
```

For an external add-ons repository, set `argocd_root_app_repo_url` to that repo URL and `argocd_root_app_path` to the folder that contains the child ArgoCD `Application` manifests.

## Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

After apply:

```bash
aws eks update-kubeconfig --region ap-south-1 --name dev-platform-eks
kubectl get nodes
kubectl get applications -n argocd
```
