region             = "ap-south-1"
cluster_name       = "platform-eks"
project_name       = "platform"
kubernetes_version = "1.33"
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]
assign_public_ip_to_nodes = true
cluster_endpoint_public_access_cidrs = [
  "0.0.0.0/0"
]
argocd_root_app_enabled         = true
argocd_root_app_repo_url        = "https://github.com/YOUR_ORG/platform-repo.git"
argocd_root_app_target_revision = "HEAD"
argocd_root_app_path            = "kubernetes/argocd/apps"
environment                     = "dev"
