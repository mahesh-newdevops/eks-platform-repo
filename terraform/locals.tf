locals {
  environment = lower(var.environment)

  cluster_name    = "${local.environment}-${var.cluster_name}"
  resource_prefix = "${local.environment}-${var.project_name}"
  rds_name        = "${local.resource_prefix}-db"
}
