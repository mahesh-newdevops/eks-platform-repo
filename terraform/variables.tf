variable "region" {
  default = "ap-south-1"
}

variable "cluster_name" {
  description = "Base EKS cluster name. The selected environment is prefixed automatically."
  type        = string
  default     = "platform-eks"
}

variable "project_name" {
  description = "Base project/application name used in shared resource names."
  type        = string
  default     = "microservices"
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
  default     = ["203.0.113.10/32"]
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

variable "rds_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_db_name" {
  description = "Database name"
  type        = string
  default     = "microservices"
  sensitive   = false
}

variable "rds_username" {
  description = "Master username for RDS"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "rds_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "Whether deletion protection is enabled for the RDS instance"
  type        = bool
  default     = false
}
