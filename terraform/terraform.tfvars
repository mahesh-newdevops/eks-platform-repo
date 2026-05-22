region             = "ap-south-1"
cluster_name       = "platform-eks"
project_name       = "microservices"
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

# RDS Configuration
environment           = "dev"
rds_instance_class    = "db.t3.micro"
rds_engine_version    = null
rds_allocated_storage = 20
rds_db_name           = "microservices"
rds_username          = "postgres"
rds_password          = "ChangeMe@12345" # IMPORTANT: Change this in production!
backup_retention_days = 7
