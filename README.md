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
- `.github/workflows/eks-platform.yml` plans, applies, or destroys the EKS platform and bootstraps ArgoCD.
- `.github/workflows/iac-scan.yml` scans Terraform, Kubernetes bootstrap manifests, and workflows for IaC misconfigurations and committed secrets.

## Configure

Edit `terraform/terraform.tfvars` before applying:

```hcl
region                         = "ap-south-1"
environment                    = "dev"
cluster_name                   = "platform-eks"
argocd_root_app_repo_url        = "https://github.com/mahesh-newdevops/gitops-platform.git"
argocd_root_app_target_revision = "main"
argocd_root_app_path            = "argocd"
```

For an external add-ons repository, set `argocd_root_app_repo_url` to that repo URL and `argocd_root_app_path` to the folder that contains the child ArgoCD `Application` manifests.

## GitHub Actions Deploy

Run `.github/workflows/eks-platform.yml` manually and choose:

```text
action:
  plan
  apply
  destroy

layer:
  all
  cluster-foundation
  aws-addons
  compute
  argocd-bootstrap
```

Use `all` for first-time creation and regular drift checks. The layer options use Terraform targeting for staged production operations, for example:

```text
1. cluster-foundation  -> EKS control plane/VPC-oriented changes
2. aws-addons          -> CoreDNS, kube-proxy, VPC CNI, EBS CSI, Pod Identity Agent
3. compute             -> managed node groups, Karpenter AWS-side resources, platform IAM
4. argocd-bootstrap    -> ArgoCD Helm install and root Application
```

For production destroy, the workflow requires `confirm_destroy=destroy-prod`. Destroy in reverse order:

```text
1. Remove/sync-prune microservice Applications from gitops-platform
2. Remove/sync-prune external add-ons from gitops-platform
3. Destroy argocd-bootstrap
4. Destroy compute
5. Destroy aws-addons
6. Destroy cluster-foundation or all
```

## Local Deploy

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

## External Add-on Upgrades

This repo owns AWS/EKS foundation changes. External add-ons are upgraded from the GitOps repo:

```text
gitops-platform/argocd/apps/*.yaml
gitops-platform/argocd/microservices/*.yaml
```

Change the ArgoCD `targetRevision` or Helm values there, open a PR, merge it, and ArgoCD automatically syncs the new desired state because the Applications use:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```
