# EKS Cluster
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

# OIDC Provider
output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS workload identity"
  value       = module.eks.oidc_provider_arn
}

# Karpenter
output "karpenter_iam_role_arn" {
  description = "ARN of the Karpenter controller IAM role"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_iam_role_name" {
  description = "Name of the Karpenter controller IAM role"
  value       = module.karpenter.iam_role_name
}

# Access Configuration
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ap-south-1 --name ${module.eks.cluster_name}"
}

output "deployment_summary" {
  description = "Summary of deployed components"
  value = {
    cluster_name     = module.eks.cluster_name
    region           = "ap-south-1"
    kubernetes_addons = [
      "vpc-cni",
      "eks-pod-identity-agent",
      "aws-ebs-csi-driver"
    ]
    helm_releases = [
      "karpenter",
      "aws-load-balancer-controller",
      "argocd",
      "prometheus",
      "loki"
    ]
  }
}

# RDS Database
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS PostgreSQL address (without port)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "rds_master_username" {
  description = "RDS master username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "rds_connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${var.rds_username}:${var.rds_password}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.rds_db_name}"
  sensitive   = true
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "rds_storage_encrypted" {
  description = "Whether RDS storage is encrypted"
  value       = aws_db_instance.postgres.storage_encrypted
}