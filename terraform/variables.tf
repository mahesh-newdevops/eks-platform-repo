variable "region" {
  default = "ap-south-1"
}

variable "cluster_name" {
  description = "Base EKS cluster name. The selected environment is prefixed automatically."
  type        = string
  default     = "platform-eks"
}

variable "project_name" {
  description = "Base project/platform name used in shared resource names."
  type        = string
  default     = "platform"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets. Use at least two for multi-AZ EKS."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "assign_public_ip_to_nodes" {
  description = "Assign public IPs to nodes launched in public subnets. Without NAT or VPC endpoints, this must stay true for nodes to reach AWS APIs and pull images."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. Keep broad for GitHub-hosted runners, restrict to office/VPN CIDRs for production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "argocd_chart_version" {
  description = "Optional ArgoCD Helm chart version. Leave null to use the latest chart version available at apply time."
  type        = string
  default     = null
}

variable "argocd_root_app_enabled" {
  description = "Create the ArgoCD app-of-apps root Application after ArgoCD is installed."
  type        = bool
  default     = true
}

variable "argocd_root_app_name" {
  description = "Name of the ArgoCD root Application."
  type        = string
  default     = "root-app"
}

variable "argocd_root_app_repo_url" {
  description = "Git repository URL that the ArgoCD root Application tracks."
  type        = string
  default     = "https://github.com/YOUR_ORG/platform-repo.git"
}

variable "argocd_root_app_target_revision" {
  description = "Git revision that the ArgoCD root Application tracks."
  type        = string
  default     = "HEAD"
}

variable "argocd_root_app_path" {
  description = "Path inside the Git repository containing child ArgoCD Applications."
  type        = string
  default     = "kubernetes/argocd/apps"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], lower(var.environment))
    error_message = "Environment must be dev, staging, or prod."
  }
}
