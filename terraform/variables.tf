variable "region" {
  default = "ap-south-1"
}

variable "cluster_name" {
  default = "prod-eks"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
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