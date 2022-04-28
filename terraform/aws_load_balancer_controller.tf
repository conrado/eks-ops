
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

# should we use just a kubernetes_role here?
resource "kubernetes_cluster_role" "aws_load_balancer_controller" {
  metadata {
    name = "aws-load-balancer-controller"

    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = [
      "",
      "extensions",
    ]

    resources = [
      "configmaps",
      "endpoints",
      "events",
      "ingresses",
      "ingresses/status",
      "services",
    ]

    verbs = [
      "create",
      "get",
      "list",
      "update",
      "watch",
      "patch",
    ]
  }

  rule {
    api_groups = [
      "",
      "extensions",
    ]

    resources = [
      "nodes",
      "pods",
      "secrets",
      "services",
      "namespaces",
    ]

    verbs = [
      "get",
      "list",
      "watch",
    ]
  }
}

resource "kubernetes_cluster_role_binding" "aws_load_balancer_controller" {
  metadata {
    name = "aws-load-balancer-controller"

    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.aws_load_balancer_controller.metadata[0].name
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
    namespace = kubernetes_service_account.aws_load_balancer_controller.metadata[0].namespace
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

  # set {
  #   name  = "alb\\.ingress\\.kubernetes\\.io/certificate-arn"
  #   value = aws_acm_certificate.ice01.arn
  # }
}

resource "kubernetes_ingress_v1" "ice01" {
  metadata {
    name = "hello-kubernetes"
    labels = {
      "app.kubernetes.io/name"       = "hello-kubernetes"
      "app.kubernetes.io/managed-by" = "terraform"
    }
    annotations = {
      "kubernetes.io/ingress.class"      = "alb"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      # "alb.ingress.kubernetes.io/listen-ports" = "[{'HTTP': 80}, {'HTTPS': 443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.ice01.arn
    }
  }
  spec {
    default_backend {
      service {
        name = "hello-kubernetes"
        port { number = 8080 }
      }
    }
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "hello-kubernetes"
              port { number = 8080 }
            }
          }
        }
      }
    }
  }

}

resource "aws_route53_record" "ice01_naked" {
  name    = "origin.icekernelcloud01.com"
  type    = "CNAME"
  zone_id = data.aws_route53_zone.zone.zone_id
  ttl     = 360
  records = [
    kubernetes_ingress_v1.ice01.status[0].load_balancer[0].ingress[0].hostname,
  ]
}
