region             = "ap-south-1"
cluster_name       = "platform-eks"
project_name       = "microservices"
kubernetes_version = "1.33"

# RDS Configuration
environment           = "dev"
rds_instance_class    = "db.t3.micro"
rds_allocated_storage = 20
rds_db_name           = "microservices"
rds_username          = "postgres"
rds_password          = "ChangeMe@12345" # IMPORTANT: Change this in production!
backup_retention_days = 7
