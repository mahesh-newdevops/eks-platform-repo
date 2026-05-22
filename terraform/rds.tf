# RDS PostgreSQL Database for Microservices

data "aws_rds_engine_version" "postgres" {
  engine       = "postgres"
  version      = var.rds_engine_version
  default_only = var.rds_engine_version == null
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${local.resource_prefix}-rds-postgres-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = [
      module.eks.node_security_group_id
    ]
    description = "PostgreSQL access"
  }

  tags = {
    Name        = "${local.resource_prefix}-rds-postgres-sg"
    Environment = local.environment
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "rds" {
  name       = "${local.resource_prefix}-rds-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name        = "${local.resource_prefix}-rds-subnet-group"
    Environment = local.environment
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier        = local.rds_name
  engine            = "postgres"
  engine_version    = data.aws_rds_engine_version.postgres.version
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.rds_db_name
  username = var.rds_username
  password = var.rds_password

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                  = false
  publicly_accessible       = false
  skip_final_snapshot       = local.environment == "dev" ? true : false
  final_snapshot_identifier = local.environment == "dev" ? null : "${local.rds_name}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql"]
  deletion_protection             = var.rds_deletion_protection

  parameter_group_name = aws_db_parameter_group.postgres.name

  tags = {
    Name        = local.rds_name
    Environment = local.environment
  }
}

# DB Parameter Group for PostgreSQL
resource "aws_db_parameter_group" "postgres" {
  name   = "${local.resource_prefix}-postgres-params"
  family = data.aws_rds_engine_version.postgres.parameter_group_family

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name        = "${local.resource_prefix}-postgres-params"
    Environment = local.environment
  }
}

# Kubernetes Secret for RDS credentials
resource "kubernetes_secret" "rds_credentials" {
  metadata {
    name      = "rds-credentials"
    namespace = "default"
  }

  data = {
    host     = base64encode(aws_db_instance.postgres.address)
    port     = base64encode(tostring(aws_db_instance.postgres.port))
    username = base64encode(var.rds_username)
    password = base64encode(var.rds_password)
    dbname   = base64encode(var.rds_db_name)
  }

  depends_on = [module.eks]
}

# Kubernetes secrets for each microservice
resource "kubernetes_secret" "user_service_db" {
  metadata {
    name      = "user-service-db-secret"
    namespace = "user-service"
  }

  data = {
    "db.host"     = aws_db_instance.postgres.address
    "db.port"     = tostring(aws_db_instance.postgres.port)
    "db.name"     = var.rds_db_name
    "db.user"     = var.rds_username
    "db.password" = var.rds_password
  }

  depends_on = [
    kubernetes_namespace.user_service,
    aws_db_instance.postgres
  ]
}

resource "kubernetes_secret" "payment_service_db" {
  metadata {
    name      = "payment-service-db-secret"
    namespace = "payment-service"
  }

  data = {
    "db.host"     = aws_db_instance.postgres.address
    "db.port"     = tostring(aws_db_instance.postgres.port)
    "db.name"     = var.rds_db_name
    "db.user"     = var.rds_username
    "db.password" = var.rds_password
  }

  depends_on = [
    kubernetes_namespace.payment_service,
    aws_db_instance.postgres
  ]
}

resource "kubernetes_secret" "order_service_db" {
  metadata {
    name      = "order-service-db-secret"
    namespace = "order-service"
  }

  data = {
    "db.host"     = aws_db_instance.postgres.address
    "db.port"     = tostring(aws_db_instance.postgres.port)
    "db.name"     = var.rds_db_name
    "db.user"     = var.rds_username
    "db.password" = var.rds_password
  }

  depends_on = [
    kubernetes_namespace.order_service,
    aws_db_instance.postgres
  ]
}

# Kubernetes namespaces for microservices
resource "kubernetes_namespace" "user_service" {
  metadata {
    name = "user-service"
    labels = {
      "linkerd.io/inject"                = "enabled"
      "pod-security.kubernetes.io/audit" = "restricted"
      "pod-security.kubernetes.io/warn"  = "restricted"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "payment_service" {
  metadata {
    name = "payment-service"
    labels = {
      "linkerd.io/inject"                = "enabled"
      "pod-security.kubernetes.io/audit" = "restricted"
      "pod-security.kubernetes.io/warn"  = "restricted"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "order_service" {
  metadata {
    name = "order-service"
    labels = {
      "linkerd.io/inject"                = "enabled"
      "pod-security.kubernetes.io/audit" = "restricted"
      "pod-security.kubernetes.io/warn"  = "restricted"
    }
  }

  depends_on = [module.eks]
}
