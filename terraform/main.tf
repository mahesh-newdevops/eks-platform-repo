module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.20.0"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = aws_vpc.this.id
  subnet_ids         = aws_subnet.public[*].id

  endpoint_public_access                   = true
  endpoint_public_access_cidrs             = var.cluster_endpoint_public_access_cidrs
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {}

    eks-pod-identity-agent = {}

    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    default = {
      subnet_ids     = aws_subnet.public[*].id
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2

      network_interfaces = [
        {
          associate_public_ip_address = var.assign_public_ip_to_nodes
          delete_on_termination       = true
          device_index                = 0
        }
      ]
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = {
    Environment              = local.environment
    Terraform                = "true"
    "karpenter.sh/discovery" = local.cluster_name
  }
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.20.0"

  cluster_name                  = module.eks.cluster_name
  enable_inline_policy          = true
  node_iam_role_name            = "KarpenterNodeRole-${local.cluster_name}"
  node_iam_role_use_name_prefix = false
  queue_name                    = "Karpenter-${local.cluster_name}"

  tags = {
    Environment = local.environment
    Terraform   = "true"
  }
}

resource "helm_release" "karpenter" {
  namespace        = "kube-system"
  create_namespace = false

  name = "karpenter"

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.3.1"

  values = [
    <<EOF
settings:
  clusterName: ${module.eks.cluster_name}
  interruptionQueue: ${module.karpenter.queue_name}

serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
EOF
  ]

  depends_on = [
    module.eks,
    module.karpenter
  ]
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  values = [
    <<EOF
clusterName: ${module.eks.cluster_name}
EOF
  ]

  depends_on = [
    module.eks
  ]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  depends_on = [
    module.eks
  ]
}

# Monitoring Stack - Prometheus
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "57.0.0"

  values = [
    file("${path.module}/../kubernetes/monitoring/prometheus-values.yaml")
  ]

  depends_on = [
    module.eks
  ]
}

# Monitoring Stack - Loki for Log Aggregation
resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "2.10.1"

  values = [
    file("${path.module}/../kubernetes/monitoring/loki-values.yaml")
  ]

  depends_on = [
    module.eks,
    helm_release.prometheus
  ]
}

# Service Mesh - Linkerd for traffic management and observability
resource "helm_release" "linkerd" {
  name             = "linkerd"
  repository       = "https://helm.linkerd.io"
  chart            = "linkerd2"
  namespace        = "linkerd"
  create_namespace = true
  version          = "1.16.0"

  values = [
    <<EOF
identityTrustAnchorsPEM: |
  ${indent(2, tls_self_signed_cert.linkerd_root.cert_pem)}
identity:
  issuer:
    tls:
      crtPEM: |
        ${indent(8, tls_locally_signed_cert.linkerd_issuer.cert_pem)}
      keyPEM: |
        ${indent(8, tls_private_key.linkerd_issuer.private_key_pem)}
EOF
  ]

  depends_on = [
    module.eks
  ]
}

# Distributed Tracing - Jaeger for request tracing across microservices
resource "helm_release" "jaeger" {
  name             = "jaeger"
  repository       = "https://jaegertracing.github.io/helm-charts"
  chart            = "jaeger"
  namespace        = "monitoring"
  create_namespace = true
  version          = "0.71.0"

  values = [
    <<EOF
jaeger:
  ingress:
    enabled: false
  storage:
    type: badger
  collector:
    enabled: true
  query:
    enabled: true
  agent:
    enabled: true
EOF
  ]

  depends_on = [
    module.eks,
    helm_release.prometheus
  ]
}

# TLS Certificates for Linkerd
resource "tls_private_key" "linkerd_root" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "linkerd_root" {
  private_key_pem       = tls_private_key.linkerd_root.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 8760
  allowed_uses = [
    "cert_signing",
    "key_encipherment",
  ]

  subject {
    common_name  = "root.linkerd.cluster.local"
    organization = "Linkerd"
  }
}

resource "tls_private_key" "linkerd_issuer" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "linkerd_issuer" {
  private_key_pem = tls_private_key.linkerd_issuer.private_key_pem

  subject {
    common_name  = "identity.linkerd.cluster.local"
    organization = "Linkerd"
  }
}

resource "tls_locally_signed_cert" "linkerd_issuer" {
  cert_request_pem      = tls_cert_request.linkerd_issuer.cert_request_pem
  ca_private_key_pem    = tls_private_key.linkerd_root.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.linkerd_root.cert_pem
  validity_period_hours = 8760
  allowed_uses = [
    "cert_signing",
    "key_encipherment",
  ]
}
