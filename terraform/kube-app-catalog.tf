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
