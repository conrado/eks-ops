locals {
  appmesh_controller_serviceaccount_name = "aws-appmesh-controller"
}


resource "kubernetes_namespace" "appmesh_system" {
  metadata {
    name = "appmesh-system"
  }
}

data "aws_iam_policy_document" "appmesh_controller" {
  statement {
    effect = "Allow"
    actions = [
      "appmesh:*",
    ]
    resources = [
      "*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = [
      "arn:aws:iam::*:role/aws-service-role/appmesh.amazonaws.com/AWSServiceRoleForAppMesh",
    ]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values = [
        "appmesh.amazonaws.com",
      ]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "acm-pca:DescribeCertificateAuthority",
      "acm-pca:ListCertificateAuthorities",
    ]
    resources = [
      "*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "servicediscovery:CreateService",
      "servicediscovery:DeleteService",
      "servicediscovery:GetService",
      "servicediscovery:GetInstance",
      "servicediscovery:RegisterInstance",
      "servicediscovery:DeregisterInstance",
      "servicediscovery:ListInstances",
      "servicediscovery:ListNamespaces",
      "servicediscovery:ListServices",
      "servicediscovery:GetInstancesHealthStatus",
      "servicediscovery:UpdateInstanceCustomHealthStatus",
      "servicediscovery:GetOperation",
      "route53:GetHealthCheck",
      "route53:CreateHealthCheck",
      "route53:UpdateHealthCheck",
      "route53:ChangeResourceRecordSets",
      "route53:DeleteHealthCheck",
    ]
    resources = [
      "*",
    ]
  }
}

module "iam_policy_appmesh_controller" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  name        = "AWSAppMeshK8sControllerIAMPolicy"
  description = "Policy for appmesh-controller"
  policy      = data.aws_iam_policy_document.appmesh_controller.json
}

module "irsa_appmesh_controller" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.cluster_name}-irsa-appmesh-controller"

  role_policy_arns = {
    appmesh_controller = module.iam_policy_appmesh_controller.arn
  }

  oidc_providers = {
    kubesys = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "appmesh-system:${local.appmesh_controller_serviceaccount_name}",
      ]
    }
  }
}

resource "kubernetes_service_account" "aws_appmesh_controller" {
  automount_service_account_token = true
  metadata {
    name      = local.appmesh_controller_serviceaccount_name
    namespace = kubernetes_namespace.appmesh_system.metadata.0.name
    annotations = {
      # This annotation is only used when running on EKS which can
      # use IAM roles for service accounts.
      "eks.amazonaws.com/role-arn" = module.irsa_appmesh_controller.iam_role_arn
    }
    labels = {
      "app.kubernetes.io/name"       = "${local.appmesh_controller_serviceaccount_name}"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "appmesh_controller" {
  name       = "appmesh-controller"
  chart      = "appmesh-controller"
  repository = "https://aws.github.io/eks-charts"
  namespace  = kubernetes_namespace.appmesh_system.metadata.0.name
  version    = "1.5.0"

  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "serviceAccount.name"
    value = local.appmesh_controller_serviceaccount_name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "tracing.enabled"
    value = "true"
  }
  set {
    name  = "tracing.provider"
    value = "x-ray"
  }
}
