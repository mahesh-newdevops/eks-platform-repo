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
  default = "10.0.0.0/16"
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
