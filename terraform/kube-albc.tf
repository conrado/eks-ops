
module "irsa_role_load_balancer_controller" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "${var.cluster_name}-irsa-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    kubesys = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "kube-system:aws-load-balancer-controller",
      ]
    }
  }
}

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  automount_service_account_token = true
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      # This annotation is only used when running on EKS which can
      # use IAM roles for service accounts.
      "eks.amazonaws.com/role-arn" = module.irsa_role_load_balancer_controller.iam_role_arn
    }
    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name            = "aws-load-balancer-controller"
  chart           = "aws-load-balancer-controller"
  repository      = "https://aws.github.io/eks-charts"
  namespace       = "kube-system"
  cleanup_on_fail = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  depends_on = [
    kubernetes_service_account.aws_load_balancer_controller,
  ]
}

module "origin_certificate" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3.4.1"

  domain_name = "origin.${var.domain_name}"
  zone_id     = data.aws_route53_zone.zone.id

  tags = var.tags

  ## terraform likes to destroy these before we get a chance to use them to
  ## destroy the ALB we created that uses this certificate. so prevent destroy
  depends_on = [
    module.irsa_role_load_balancer_controller,
    helm_release.aws_load_balancer_controller,
    module.vpc,
    module.eks,
  ]
}
