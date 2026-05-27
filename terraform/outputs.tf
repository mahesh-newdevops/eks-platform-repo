# EKS Cluster
output "vpc_id" {
  description = "Dedicated VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by EKS and ALB"
  value       = aws_subnet.public[*].id
}

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

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN used by AWS Load Balancer Controller through EKS Pod Identity"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN used by External Secrets through EKS Pod Identity"
  value       = aws_iam_role.external_secrets.arn
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN used by Karpenter through EKS Pod Identity"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_node_role_name" {
  description = "IAM role name used by nodes launched by Karpenter"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_interruption_queue_name" {
  description = "SQS interruption queue name used by Karpenter"
  value       = module.karpenter.queue_name
}

# Access Configuration
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "deployment_summary" {
  description = "Summary of deployed components"
  value = {
    cluster_name = module.eks.cluster_name
    environment  = local.environment
    region       = var.region
    kubernetes_addons = [
      "vpc-cni",
      "eks-pod-identity-agent",
      "aws-ebs-csi-driver"
    ]
    helm_releases = [
      "argocd"
    ]
    addon_iam = {
      aws_load_balancer_controller_role_arn = aws_iam_role.aws_load_balancer_controller.arn
      external_secrets_role_arn             = aws_iam_role.external_secrets.arn
      karpenter_controller_role_arn         = module.karpenter.iam_role_arn
      karpenter_node_role_name              = module.karpenter.node_iam_role_name
      karpenter_interruption_queue_name     = module.karpenter.queue_name
    }
    argocd_root_app = var.argocd_root_app_enabled ? {
      name            = var.argocd_root_app_name
      repo_url        = var.argocd_root_app_repo_url
      target_revision = var.argocd_root_app_target_revision
      path            = var.argocd_root_app_path
    } : null
  }
}
