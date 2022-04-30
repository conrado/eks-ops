resource "kubernetes_deployment_v1" "sample_app" {
  metadata {
    name = "hello-kubernetes"
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        name = "hello-kubernetes"
      }
    }
    template {
      metadata {
        labels = {
          name = "hello-kubernetes"
        }
      }
      spec {
        container {
          name  = "app"
          image = "paulbouwer/hello-kubernetes:1.8"
          port {
            container_port = 8080
          }
        }
      }
    }
  }
  depends_on = [
    module.eks,
  ]
}

resource "kubernetes_service_v1" "sample_app" {
  metadata {
    name = "hello-kubernetes"
  }
  spec {
    selector = {
      name = "hello-kubernetes"
    }
    port {
      port        = 8080
      target_port = 8080
    }
    type = "NodePort"
  }
  depends_on = [
    module.eks,
  ]
}

resource "kubernetes_ingress_v1" "sample_app" {
  wait_for_load_balancer = true
  metadata {
    name = "hello-kubernetes"
    labels = {
      "app.kubernetes.io/name"       = "hello-kubernetes"
      "app.kubernetes.io/managed-by" = "terraform"
    }
    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/certificate-arn" = module.origin_certificate.acm_certificate_arn
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
  depends_on = [
    module.irsa_role_load_balancer_controller,
    helm_release.aws_load_balancer_controller,
    module.vpc,
    module.eks,
  ]
}

resource "aws_route53_record" "origin" {
  name    = "origin.icekernelcloud01.com"
  type    = "CNAME"
  zone_id = data.aws_route53_zone.zone.zone_id
  ttl     = 360
  records = [
    kubernetes_ingress_v1.sample_app.status[0].load_balancer[0].ingress[0].hostname,
  ]
}
