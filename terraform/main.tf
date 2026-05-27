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
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  addons = {
    coredns = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      before_compute = true
      most_recent    = true
    }

    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }

    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
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

  tags = {
    Environment = local.environment
    Terraform   = "true"
  }
}

data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${local.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json

  tags = {
    Environment = local.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  timeout          = 900

  depends_on = [
    module.eks
  ]
}

resource "kubectl_manifest" "argocd_root_app" {
  count = var.argocd_root_app_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = var.argocd_root_app_name
      namespace = "argocd"
    }

    spec = {
      project = "default"

      source = {
        repoURL        = var.argocd_root_app_repo_url
        targetRevision = var.argocd_root_app_target_revision
        path           = var.argocd_root_app_path
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }

        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })

  depends_on = [
    helm_release.argocd
  ]
}
