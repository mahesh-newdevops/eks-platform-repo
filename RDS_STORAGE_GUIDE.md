# RDS & Persistent Storage Setup

This document explains how RDS PostgreSQL database and persistent EBS volumes have been integrated into the full-platform repository.

## Architecture Overview

The infrastructure now includes:

1. **AWS RDS PostgreSQL** - Managed relational database for microservices
2. **EBS Persistent Volumes** - Encrypted and unencrypted storage for caching and data
3. **StatefulSets** - Kubernetes StatefulSets for microservices instead of Deployments
4. **Storage Classes** - EBS-backed storage with automatic provisioning

## Components

### 1. RDS Database (`terraform/rds.tf`)

**Features:**
- PostgreSQL 15.3 on AWS RDS
- Encrypted storage (AWS KMS)
- Multi-AZ not enabled for dev (cost optimization)
- Automatic backups (7-day retention)
- CloudWatch Logs export enabled
- Security group restricts access to EKS cluster only

**Connection Details:**
- Database: `microservices`
- Username: `postgres`
- Port: `5432`
- Auto-generated endpoint available in Terraform outputs

**Security:**
- Credentials stored in Kubernetes Secrets
- Separate secrets created for each microservice namespace
- Master password configurable via `terraform.tfvars`

### 2. Storage Configuration (`kubernetes/storage/storage-class.yaml`)

**Storage Classes:**
1. **ebs-gp3-encrypted**
   - GP3 volume type
   - 3000 IOPS, 125 MB/s throughput
   - Encrypted with KMS
   - Use case: Production data

2. **ebs-gp3-standard**
   - GP3 volume type
   - 3000 IOPS, 125 MB/s throughput
   - Unencrypted (for caching)
   - Use case: Cache, temporary data

**Persistent Volumes Per Service:**
- **data**: 10Gi encrypted storage (RDS backup/recovery data)
- **cache**: 5Gi standard storage (application cache)

### 3. StatefulSets

All microservices converted from Deployments to StatefulSets:

**User Service** (`kubernetes/microservices/user-service/statefulset.yaml`)
- 3 replicas
- Headless service `user-service`
- Volume templates: `data` (10Gi), `cache` (5Gi)
- Pod naming: `user-service-0`, `user-service-1`, `user-service-2`

**Payment Service** (`kubernetes/microservices/payment-service/statefulset.yaml`)
- 2 replicas
- Volume templates: `data` (10Gi), `cache` (5Gi)
- Calls user-service via DNS: `user-service.user-service:8080`

**Order Service** (`kubernetes/microservices/order-service/statefulset.yaml`)
- 2 replicas
- Volume templates: `data` (10Gi), `cache` (5Gi)
- Calls user-service and payment-service

### 4. Database Secrets

Kubernetes secrets automatically created by Terraform:

```bash
# Each namespace has a secret with RDS connection details
kubectl get secret user-service-db-secret -n user-service
kubectl get secret payment-service-db-secret -n payment-service
kubectl get secret order-service-db-secret -n order-service
```

**Secret Keys:**
- `db.host` - RDS endpoint
- `db.port` - PostgreSQL port (5432)
- `db.name` - Database name
- `db.user` - Username
- `db.password` - Password

## Configuration

### Terraform Variables

Update `terraform/terraform.tfvars`:

```hcl
environment              = "dev"  # or "prod"
rds_instance_class       = "db.t3.micro"  # t3.micro, t3.small, etc.
rds_allocated_storage    = 20  # GB
rds_db_name              = "microservices"
rds_username             = "postgres"
rds_password             = "ChangeMe@12345"  # IMPORTANT: Change this!
backup_retention_days    = 7
```

### Production Settings

For production, modify `terraform/terraform.tfvars`:

```hcl
environment              = "prod"
rds_instance_class       = "db.t3.small"  # Increased capacity
rds_allocated_storage    = 100
backup_retention_days    = 30
# Enable multi-AZ in rds.tf: multi_az = true
```

## Deployment

### Deploy Infrastructure + RDS + Storage

```bash
# 1. Update terraform.tfvars with your password
cd terraform
vim terraform.tfvars  # Change rds_password

# 2. Initialize and apply
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 3. Get RDS endpoint
terraform output rds_endpoint
terraform output rds_connection_string  # Sensitive output
```

### Deploy Microservices with PVCs

```bash
# 1. Create storage classes and PVCs
kubectl apply -f kubernetes/storage/storage-class.yaml

# 2. Deploy microservices (StatefulSets)
kubectl apply -f kubernetes/microservices/user-service/statefulset.yaml
kubectl apply -f kubernetes/microservices/payment-service/statefulset.yaml
kubectl apply -f kubernetes/microservices/order-service/statefulset.yaml
```

### Access Database

```bash
# Port-forward to RDS (local development only)
kubectl port-forward -n user-service user-service-0 5432:5432

# Connect from local machine
psql -h localhost -U postgres -d microservices
```

## Monitoring

### Check PVC Status

```bash
# List all PVCs
kubectl get pvc -A

# Watch PVC creation
kubectl get pvc -n user-service -w

# Describe PVC details
kubectl describe pvc user-service-data -n user-service
```

### Check Pod Storage

```bash
# Verify volumes are mounted
kubectl describe pod user-service-0 -n user-service

# Check storage usage
kubectl exec user-service-0 -n user-service -- df -h
```

### RDS Monitoring

```bash
# View RDS details from Terraform
terraform show | grep -i rds

# AWS CLI
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,Engine,DBInstanceClass]'

# Check RDS events
aws rds describe-events --source-type db-instance --max-records 50
```

## Data Persistence

### What Persists

✅ **Persists across pod restarts:**
- `/data` volume (PVC backed by EBS)
- `/cache` volume (PVC backed by EBS)
- RDS database data

✅ **Persists across cluster recreation:**
- RDS database (AWS managed service)
- EBS volumes (unless cluster destroyed)

❌ **Does NOT persist:**
- `/tmp` (emptyDir volume)
- Pod local state when destroyed

### Data Backup Strategy

1. **RDS Automatic Backups** - 7 days (configurable)
   ```bash
   aws rds describe-db-snapshots
   ```

2. **EBS Volume Snapshots** - Create manually or use schedules
   ```bash
   aws ec2 describe-snapshots --owner-ids self
   ```

3. **Database Dumps** - Export to S3
   ```bash
   pg_dump -h RDS_ENDPOINT -U postgres microservices > backup.sql
   ```

## Cost Estimation

### RDS

| Instance | GB | Backup | Monthly Cost |
|----------|----|---------|-|
| db.t3.micro | 20 | 7-day | ~$15 |
| db.t3.small | 100 | 30-day | ~$45 |
| db.t3.medium | 200 | 30-day | ~$90 |

### EBS Storage

| Volume | Per GB | Services | Total |
|--------|--------|----------|-------|
| data (10Gi × 3 services) | $0.10 | 30Gi | ~$3 |
| cache (5Gi × 3 services) | $0.10 | 15Gi | ~$1.50 |

### Total Monthly

- **Dev Setup**: ~$20-25/month
- **Prod Setup**: ~$50-100/month

## Cleanup

### Destroy Infrastructure (all data lost!)

```bash
# CAUTION: This deletes RDS and EBS volumes
terraform destroy

# If final snapshot needed:
# - Modify rds.tf: skip_final_snapshot = false
# - Run terraform destroy
# - Snapshots saved in AWS
```

### Keep RDS, Destroy Cluster

```bash
# Comment out aws_db_instance in rds.tf
# Or set skip_final_snapshot = false for final backup
terraform destroy -target=module.eks -target=module.karpenter
```

## Troubleshooting

### RDS Not Reachable

```bash
# Check security group rules
aws ec2 describe-security-groups --filters Name=group-name,Values=rds-postgres-sg

# Check RDS status
aws rds describe-db-instances --db-instance-identifier microservices-db

# Test from pod
kubectl exec user-service-0 -n user-service -- nc -zv RDS_ENDPOINT 5432
```

### PVC Stuck in Pending

```bash
# Check PVC events
kubectl describe pvc user-service-data -n user-service

# Check storage class
kubectl get storageclass

# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi
```

### Pod Not Starting

```bash
# Check events
kubectl describe pod user-service-0 -n user-service

# Check logs
kubectl logs user-service-0 -n user-service
```

## Next Steps

1. **Implement database migrations** - Use Liquibase or Flyway
2. **Add HPA scaling** - Based on metrics from Prometheus
3. **Setup automated backups** - S3 export via Lambda
4. **Configure replication** - Read replicas for scaling reads
5. **Implement connection pooling** - PgBouncer for better performance

