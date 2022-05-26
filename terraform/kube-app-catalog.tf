resource "kubernetes_namespace" "prodcatalog" {
  metadata {
    name = "prodcatalog-ns"
  }
}

# seems a bit too permissive, but this is what's in the tutorial...
data "aws_iam_policy_document" "kube-app-prodcatalog" {
  statement {
    effect = "Allow"
    actions = [
      "appmesh:*",
      "xray:*",
      "logs:*",
    ]
    resources = [
      "*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "acm:ExportCertificate",
      "acm-pca:GetCertificateAuthorityCerificate",
    ]
    resources = [
      "*",
    ]
  }
}

module "iam_policy_for_kube-app-prodcatalog" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  name        = "ProdEnvoyNamespaceIAMPolicy"
  description = "Policy for kube-app-prodcatalog"
  policy      = data.aws_iam_policy_document.kube-app-prodcatalog.json
}

module "irsa_prodcatalog_envoy_proxies" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.cluster_name}-irsa-prodcatalog-envoy-proxies"
  oidc_providers = {
    kubesys = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "prodcatalog-ns:prodcatalog-envoy-proxies",
      ]
    }
  }
}

resource "kubernetes_service_account" "prodcatalog-envoy-proxies" {
  automount_service_account_token = true
  metadata {
    name      = "prodcatalog-envoy-proxies"
    namespace = kubernetes_namespace.prodcatalog.metadata[0].name
    annotations = {
      # This annotation is only used when running on EKS which can
      # use IAM roles for service accounts.
      "eks.amazonaws.com/role-arn" = module.irsa_prodcatalog_envoy_proxies.iam_role_arn
    }
    labels = {
      "app.kubernetes.io/name"       = "prodcatalog-envoy-proxies"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "prodcatalog_fargate_profile" {
  name = "eks-fargate-profile-example"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "prodcatalog_fargate_podexec" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.prodcatalog_fargate_profile.name
}



resource "aws_eks_fargate_profile" "prodcatalog-envoy-proxies" {
  cluster_name           = var.cluster_name
  fargate_profile_name   = "prodcatalog-fargate-profile"
  pod_execution_role_arn = aws_iam_role.prodcatalog_fargate_profile.arn
  subnet_ids             = module.vpc.private_subnets
  selector {
    namespace = kubernetes_namespace.prodcatalog.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "prodcatalog-envoy-proxies"
    }
  }
}

