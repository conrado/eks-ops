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

module "irsa_cloudwatch_agent" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  # or perhaps we should use this one instead
  # source = "terraform-aws-modules/iam/aws//modules/iam-eks-role"

  role_name = "${var.cluster_name}-irsa-cloudwatch"

  provider_url = module.eks.oidc_provider

  role_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
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

# data "aws_iam_policy_document" "assume_role" {
#   statement {
#     effect  = "Allow"
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["eks-fargate-pods.amazonaws.com"]
#     }
#   }
# }

# resource "aws_iam_role" "prodcatalog_fargate_profile" {
#   name = "eks-fargate-profile"

#   assume_role_policy = jsonencode({
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "eks-fargate-pods.amazonaws.com"
#       }
#     }]
#     Version = "2012-10-17"
#   })
# }

# resource "aws_iam_role_policy_attachment" "prodcatalog_fargate_podexec" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
#   role       = aws_iam_role.prodcatalog_fargate_profile.name
# }



# resource "aws_eks_fargate_profile" "prodcatalog-envoy-proxies" {
#   cluster_name           = var.cluster_name
#   fargate_profile_name   = "prodcatalog-fargate-profile"
#   pod_execution_role_arn = aws_iam_role.prodcatalog_fargate_profile.arn
#   subnet_ids             = module.vpc.private_subnets
#   selector {
#     namespace = kubernetes_namespace.prodcatalog.metadata[0].name
#     labels = {
#       "app.kubernetes.io/name" = "prodcatalog-envoy-proxies"
#     }
#   }
# }

resource "kubernetes_namespace" "amazon_cloudwatch" {
  metadata {
    name = "amazon-cloudwatch"
  }
}

resource "kubernetes_service_account" "eks_cloudwatch_agent" {
  automount_service_account_token = true
  metadata {
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
    annotations = {
      # This annotation is only used when running on EKS which can
      # use IAM roles for service accounts.
      "eks.amazonaws.com/role-arn" = module.irsa_cloudwatch_agent.iam_role_arn
    }
    labels = {
      "app.kubernetes.io/name"       = "cloudwatch-agent"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_service_account" "eks_fluentd" {
  automount_service_account_token = true
  metadata {
    name      = "fluentd"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
    annotations = {
      # This annotation is only used when running on EKS which can
      # use IAM roles for service accounts.
      "eks.amazonaws.com/role-arn" = module.irsa_cloudwatch_agent.iam_role_arn
    }
    labels = {
      "app.kubernetes.io/name"       = "fluentd"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_cluster_role_v1" "cloudwatch_agent_role" {

  metadata {
    name = "cloudwatch-agent-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "endpoints"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/proxy"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/stats", "configmaps", "events"]
    verbs      = ["create"]
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cwagent-clusterleader"]
    verbs          = ["get", "update"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "cloudwatch_agent_role_binding" {
  metadata {
    name = "cloudwatch-agent-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.cloudwatch_agent_role.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.eks_cloudwatch_agent.metadata.0.name
    namespace = kubernetes_service_account.eks_cloudwatch_agent.metadata.0.namespace
  }
}

resource "kubernetes_config_map_v1" "cwagentconfig" {
  metadata {
    name      = "cwagentconfig"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }
  data = {
    "cwagentconfig.json" = <<CONFIG
{
  "agent": {
    "region": "${var.aws_region}"
  },
  "logs": {
    "metrics_collected": {
      "kubernetes": {
        "cluster_name": "${var.cluster_name}",
        "metrics_collection_interval": 60
      }
    },
    "force_flush_interval": 5
  }
}
CONFIG
  }
}

resource "kubernetes_daemon_set_v1" "cwagentdaemonset" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }
  spec {
    selector {
      match_labels = {
        name = "cloudwatch-agent"
      }
    }
    template {
      metadata {
        labels = {
          name = "cloudwatch-agent"
        }
      }
      spec {
        host_network = true
        container {
          name  = "cloudwatch-agent"
          image = "amazon/cloudwatch-agent:1.247350.0b251814-amd64"
          resources {
            limits = {
              cpu    = "200m"
              memory = "200Mi"
            }
            requests = {
              cpu    = "200m"
              memory = "200Mi"
            }
          }
          env {
            name = "HOST_IP"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }
          env {
            name = "HOST_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
          env {
            name = "K8S_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          env {
            name  = "CI_VERSION"
            value = "k8s/1.3.9"
          }
          volume_mount {
            name       = "cwagentconfig"
            mount_path = "/etc/cwagentconfig"
          }
          volume_mount {
            name       = "rootfs"
            mount_path = "/rootfs"
          }
          volume_mount {
            name       = "dockersock"
            mount_path = "/var/run/docker.sock"
            read_only  = true
          }
          volume_mount {
            name       = "varlibdocker"
            mount_path = "/var/lib/docker"
            read_only  = true
          }
          volume_mount {
            name       = "containerdsock"
            mount_path = "/run/containerd/containerd.sock"
            read_only  = true
          }
          volume_mount {
            name       = "sys"
            mount_path = "/sys"
            read_only  = true
          }
          volume_mount {
            name       = "devdisk"
            mount_path = "/dev/disk"
            read_only  = true
          }
        }
        volume {
          name = "cwagentconfig"
          config_map {
            name = kubernetes_config_map_v1.cwagentconfig.metadata.0.name
          }
        }
        volume {
          name = "rootfs"
          host_path {
            path = "/"
          }
        }
        volume {
          name = "dockersock"
          host_path {
            path = "/var/run/docker.sock"
          }
        }
        volume {
          name = "varlibdocker"
          host_path {
            path = "/var/lib/docker"
          }
        }
        volume {
          name = "containerdsock"
          host_path {
            path = "/run/containerd/containerd.sock"
          }
        }
        volume {
          name = "sys"
          host_path {
            path = "/sys"
          }
        }
        volume {
          name = "devdisk"
          host_path {
            path = "/dev/disk"
          }
        }
        termination_grace_period_seconds = 60
        service_account_name             = kubernetes_service_account.eks_cloudwatch_agent.metadata.0.name
      }
    }
  }
}

resource "kubernetes_config_map_v1" "cluster_info" {
  metadata {
    name      = "cluster-info"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }
  data = {
    "cluster.name" = "${var.cluster_name}"
    "logs.region"  = "${var.aws_region}"
  }
}

resource "kubernetes_cluster_role_v1" "fluentd_role" {

  metadata {
    name = "fluentd-role"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "pods/logs"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "fluentd_role_binding" {
  metadata {
    name = "fluentd-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.fluentd_role.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.eks_fluentd.metadata.0.name
    namespace = kubernetes_service_account.eks_fluentd.metadata.0.namespace
  }
}

resource "kubernetes_config_map_v1" "fluentd_config" {
  metadata {
    name      = "fluentd-config"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
    labels = {
      "k8s-app" = "fluentd-cloudwatch"
    }
  }
  data = {
    "fluent.conf"     = <<CONFIG
    @include containers.conf
    @include systemd.conf
    @include host.conf

    <match fluent.**>
      @type null
    </match>
CONFIG
    "containers.conf" = <<CONFIG
    <source>
      @type tail
      @id in_tail_container_logs
      @label @containers
      path /var/log/containers/*.log
      exclude_path ["/var/log/containers/cloudwatch-agent*", "/var/log/containers/fluentd*"]
      pos_file /var/log/fluentd-containers.log.pos
      tag *
      read_from_head true
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
      </parse>
    </source>

    <source>
      @type tail
      @id in_tail_cwagent_logs
      @label @cwagentlogs
      path /var/log/containers/cloudwatch-agent*
      pos_file /var/log/cloudwatch-agent.log.pos
      tag *
      read_from_head true
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
      </parse>
    </source>

    <source>
      @type tail
      @id in_tail_fluentd_logs
      @label @fluentdlogs
      path /var/log/containers/fluentd*
      pos_file /var/log/fluentd.log.pos
      tag *
      read_from_head true
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
      </parse>
    </source>

    <label @fluentdlogs>
      <filter **>
        @type kubernetes_metadata
        @id filter_kube_metadata_fluentd
        watch false
      </filter>

      <filter **>
        @type record_transformer
        @id filter_fluentd_stream_transformer
        <record>
          stream_name $${tag_parts[3]}
        </record>
      </filter>

      <match **>
        @type relabel
        @label @NORMAL
      </match>
    </label>

    <label @containers>
      <filter **>
        @type kubernetes_metadata
        @id filter_kube_metadata
        watch false
      </filter>

      <filter **>
        @type record_transformer
        @id filter_containers_stream_transformer
        <record>
          stream_name $${tag_parts[3]}
        </record>
      </filter>

      <filter **>
        @type concat
        key log
        multiline_start_regexp /^\S/
        separator ""
        flush_interval 5
        timeout_label @NORMAL
      </filter>

      <match **>
        @type relabel
        @label @NORMAL
      </match>
    </label>

    <label @cwagentlogs>
      <filter **>
        @type kubernetes_metadata
        @id filter_kube_metadata_cwagent
        watch false
      </filter>

      <filter **>
        @type record_transformer
        @id filter_cwagent_stream_transformer
        <record>
          stream_name $${tag_parts[3]}
        </record>
      </filter>

      <filter **>
        @type concat
        key log
        multiline_start_regexp /^\d{4}[-/]\d{1,2}[-/]\d{1,2}/
        separator ""
        flush_interval 5
        timeout_label @NORMAL
      </filter>

      <match **>
        @type relabel
        @label @NORMAL
      </match>
    </label>

    <label @NORMAL>
      <match **>
        @type cloudwatch_logs
        @id out_cloudwatch_logs_containers
        region "#{ENV.fetch('AWS_REGION')}"
        log_group_name "/aws/containerinsights/#{ENV.fetch('CLUSTER_NAME')}/application"
        log_stream_name_key stream_name
        remove_log_stream_name_key true
        auto_create_stream true
        <buffer>
          flush_interval 5
          chunk_limit_size 2m
          queued_chunks_limit_size 32
          retry_forever true
        </buffer>
      </match>
    </label>
CONFIG
    "systemd.conf"    = <<CONFIG
    <source>
      @type systemd
      @id in_systemd_kubelet
      @label @systemd
      filters [{ "_SYSTEMD_UNIT": "kubelet.service" }]
      <entry>
        field_map {"MESSAGE": "message", "_HOSTNAME": "hostname", "_SYSTEMD_UNIT": "systemd_unit"}
        field_map_strict true
      </entry>
      path /var/log/journal
      <storage>
        @type local
        persistent true
        path /var/log/fluentd-journald-kubelet-pos.json
      </storage>
      read_from_head true
      tag kubelet.service
    </source>

    <source>
      @type systemd
      @id in_systemd_kubeproxy
      @label @systemd
      filters [{ "_SYSTEMD_UNIT": "kubeproxy.service" }]
      <entry>
        field_map {"MESSAGE": "message", "_HOSTNAME": "hostname", "_SYSTEMD_UNIT": "systemd_unit"}
        field_map_strict true
      </entry>
      path /var/log/journal
      <storage>
        @type local
        persistent true
        path /var/log/fluentd-journald-kubeproxy-pos.json
      </storage>
      read_from_head true
      tag kubeproxy.service
    </source>

    <source>
      @type systemd
      @id in_systemd_docker
      @label @systemd
      filters [{ "_SYSTEMD_UNIT": "docker.service" }]
      <entry>
        field_map {"MESSAGE": "message", "_HOSTNAME": "hostname", "_SYSTEMD_UNIT": "systemd_unit"}
        field_map_strict true
      </entry>
      path /var/log/journal
      <storage>
        @type local
        persistent true
        path /var/log/fluentd-journald-docker-pos.json
      </storage>
      read_from_head true
      tag docker.service
    </source>

    <label @systemd>
      <filter **>
        @type kubernetes_metadata
        @id filter_kube_metadata_systemd
        watch false
      </filter>

      <filter **>
        @type record_transformer
        @id filter_systemd_stream_transformer
        <record>
          stream_name $${tag}-$${record["hostname"]}
        </record>
      </filter>

      <match **>
        @type cloudwatch_logs
        @id out_cloudwatch_logs_systemd
        region "#{ENV.fetch('AWS_REGION')}"
        log_group_name "/aws/containerinsights/#{ENV.fetch('CLUSTER_NAME')}/dataplane"
        log_stream_name_key stream_name
        auto_create_stream true
        remove_log_stream_name_key true
        <buffer>
          flush_interval 5
          chunk_limit_size 2m
          queued_chunks_limit_size 32
          retry_forever true
        </buffer>
      </match>
    </label>
CONFIG
    "host.conf"       = <<CONFIG
    <source>
      @type tail
      @id in_tail_dmesg
      @label @hostlogs
      path /var/log/dmesg
      pos_file /var/log/dmesg.log.pos
      tag host.dmesg
      read_from_head true
      <parse>
        @type syslog
      </parse>
    </source>

    <source>
      @type tail
      @id in_tail_secure
      @label @hostlogs
      path /var/log/secure
      pos_file /var/log/secure.log.pos
      tag host.secure
      read_from_head true
      <parse>
        @type syslog
      </parse>
    </source>

    <source>
      @type tail
      @id in_tail_messages
      @label @hostlogs
      path /var/log/messages
      pos_file /var/log/messages.log.pos
      tag host.messages
      read_from_head true
      <parse>
        @type syslog
      </parse>
    </source>

    <label @hostlogs>
      <filter **>
        @type kubernetes_metadata
        @id filter_kube_metadata_host
        watch false
      </filter>

      <filter **>
        @type record_transformer
        @id filter_containers_stream_transformer_host
        <record>
          stream_name $${tag}-$${record["host"]}
        </record>
      </filter>

      <match host.**>
        @type cloudwatch_logs
        @id out_cloudwatch_logs_host_logs
        region "#{ENV.fetch('AWS_REGION')}"
        log_group_name "/aws/containerinsights/#{ENV.fetch('CLUSTER_NAME')}/host"
        log_stream_name_key stream_name
        remove_log_stream_name_key true
        auto_create_stream true
        <buffer>
          flush_interval 5
          chunk_limit_size 2m
          queued_chunks_limit_size 32
          retry_forever true
        </buffer>
      </match>
    </label>
CONFIG
  }
}

resource "kubernetes_daemon_set_v1" "fluentd_cloudwatch" {
  metadata {
    name      = "fluentd-cloudwatch"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }
  spec {
    selector {
      match_labels = {
        name = "fluentd-cloudwatch"
      }
    }
    template {
      metadata {
        labels = {
          name = "fluentd-cloudwatch"
        }
        annotations = {
          "configHash" = "8915de4cf9c3551a8dc74c0137a3e83569d28c71044b0359c2578d2e0461825"
        }
      }
      spec {
        termination_grace_period_seconds = 30
        service_account_name             = kubernetes_service_account.eks_fluentd.metadata.0.name
        init_container {
          name    = "copy-fluentd-config"
          image   = "busybox"
          command = ["sh", "-c", "cp /config-volume/..data/* /fluentd/etc"]
          volume_mount {
            name       = "config-volume"
            mount_path = "/config-volume"
          }
          volume_mount {
            name       = "fluentdconf"
            mount_path = "/fluentd/etc"
          }
        }
        init_container {
          name    = "update-log-driver"
          image   = "busybox"
          command = ["sh", "-c", ""]
        }
        container {
          name  = "fluentd-cloudwatch"
          image = "fluent/fluentd-kubernetes-daemonset:v1.14-debian-cloudwatch-1"
          resources {
            limits = {
              memory = "400Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
          }
          env {
            name = "AWS_REGION"
            value_from {
              config_map_key_ref {
                name = "cluster-info"
                key  = "logs.region"
              }
            }
          }
          env {
            name = "CLUSTER_NAME"
            value_from {
              config_map_key_ref {
                name = "cluster-info"
                key  = "cluster.name"
              }
            }
          }
          env {
            name  = "CI_VERSION"
            value = "k8s/1.3.9"
          }
          volume_mount {
            name       = "config-volume"
            mount_path = "/config-volume"
          }
          volume_mount {
            name       = "fluentdconf"
            mount_path = "/fluentd/etc"
          }
          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
          }
          volume_mount {
            name       = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only  = true
          }
          volume_mount {
            name       = "runlogjournal"
            mount_path = "/run/log/journal"
            read_only  = true
          }
          volume_mount {
            name       = "dmesg"
            mount_path = "/var/log/dmesg"
            read_only  = true
          }
        }
        volume {
          name = "config-volume"
          config_map {
            name = "fluentd-config"
          }
        }
        volume {
          name = "fluentdconf"
          empty_dir {}
        }
        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }
        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }
        volume {
          name = "runlogjournal"
          host_path {
            path = "/run/log/journal"
          }
        }
        volume {
          name = "dmesg"
          host_path {
            path = "/var/log/dmesg"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_account" "eks_cwagent_prometheus" {
  automount_service_account_token = true
  metadata {
    name      = "cwagent-prometheus"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
    annotations = {
      # This annotation is only used when running on EKS which can
      # use IAM roles for service accounts.
      "eks.amazonaws.com/role-arn" = module.irsa_cloudwatch_agent.iam_role_arn
    }
    labels = {
      "app.kubernetes.io/name"       = "cwagent-prometheus"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}


resource "kubernetes_config_map_v1" "prometheus_cwagentconfig" {
  metadata {
    name      = "prometheus-cwagentconfig"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }
  data = {

    "cwagentconfig.json" = <<CONFIG
    {
      "logs": {
        "metrics_collected": {
          "prometheus": {
            "prometheus_config_path": "/etc/prometheusconfig/prometheus.yaml",
            "emf_processor": {
              "metric_declaration": [
                {
                  "source_labels": ["Service"],
                  "label_matcher": ".*nginx.*",
                  "dimensions": [["Service","Namespace","ClusterName"]],
                  "metric_selectors": [
                    "^nginx_ingress_controller_(requests|success)$",
                    "^nginx_ingress_controller_nginx_process_connections$",
                    "^nginx_ingress_controller_nginx_process_connections_total$",
                    "^nginx_ingress_controller_nginx_process_resident_memory_bytes$",
                    "^nginx_ingress_controller_nginx_process_cpu_seconds_total$",
                    "^nginx_ingress_controller_config_last_reload_successful$"
                  ]
                },
                {
                  "source_labels": ["Service"],
                  "label_matcher": ".*nginx.*",
                  "dimensions": [["Service","Namespace","ClusterName","ingress"],["Service","Namespace","ClusterName","status"]],
                  "metric_selectors": ["^nginx_ingress_controller_requests$"]
                },
                {
                  "source_labels": ["Service", "frontend"],
                  "label_matcher": ".*haproxy-ingress-.*metrics;(httpfront-shared-frontend|httpfront-default-backend|httpsfront|_front_http)",
                  "dimensions": [["Service","Namespace","ClusterName","frontend","code"]],
                  "metric_selectors": [
                    "^haproxy_frontend_http_responses_total$"
                  ]
                },
                {
                  "source_labels": ["Service", "backend"],
                  "label_matcher": ".*haproxy-ingress-.*metrics;(httpback-shared-backend|httpback-default-backend|httpsback-shared-backend|_default_backend)",
                  "dimensions": [["Service","Namespace","ClusterName","backend","code"]],
                  "metric_selectors": [
                    "^haproxy_backend_http_responses_total$"
                  ]
                },
                {
                  "source_labels": ["Service"],
                  "label_matcher": ".*haproxy-ingress-.*metrics",
                  "dimensions": [["Service","Namespace","ClusterName"]],
                  "metric_selectors": [
                    "^haproxy_backend_up$",
                    "^haproxy_backend_status$",
                    "^haproxy_backend_bytes_(in|out)_total$",
                    "^haproxy_backend_connections_total$",
                    "^haproxy_backend_connection_errors_total$",
                    "^haproxy_backend_current_sessions$",
                    "^haproxy_frontend_bytes_(in|out)_total$",
                    "^haproxy_frontend_connections_total$",
                    "^haproxy_frontend_http_requests_total$",
                    "^haproxy_frontend_request_errors_total$",
                    "^haproxy_frontend_requests_denied_total$",
                    "^haproxy_frontend_current_sessions$"
                  ]
                },
                {
                  "source_labels": ["Service"],
                  "label_matcher": ".*memcached.*",
                  "dimensions": [["Service","Namespace","ClusterName"]],
                  "metric_selectors": [
                    "^memcached_current_(bytes|items|connections)$",
                    "^memcached_items_(reclaimed|evicted)_total$",
                    "^memcached_(written|read)_bytes_total$",
                    "^memcached_limit_bytes$",
                    "^memcached_commands_total$"
                  ]
                },
                {
                  "source_labels": ["Service", "status", "command"],
                  "label_matcher": ".*memcached.*;hit;get",
                  "dimensions": [["Service","Namespace","ClusterName","status","command"]],
                  "metric_selectors": [
                    "^memcached_commands_total$"
                  ]
                },
                {
                  "source_labels": ["Service", "command"],
                  "label_matcher": ".*memcached.*;(get|set)",
                  "dimensions": [["Service","Namespace","ClusterName","command"]],
                  "metric_selectors": [
                    "^memcached_commands_total$"
                  ]
                },
                {
                  "source_labels": ["container_name"],
                  "label_matcher": "^envoy$",
                  "dimensions": [["ClusterName","Namespace"]],
                  "metric_selectors": [
                    "^envoy_http_downstream_rq_(total|xx)$",
                    "^envoy_cluster_upstream_cx_(r|t)x_bytes_total$",
                    "^envoy_cluster_membership_(healthy|total)$",
                    "^envoy_server_memory_(allocated|heap_size)$",
                    "^envoy_cluster_upstream_cx_(connect_timeout|destroy_local_with_active_rq)$",
                    "^envoy_cluster_upstream_rq_(pending_failure_eject|pending_overflow|timeout|per_try_timeout|rx_reset|maintenance_mode)$",
                    "^envoy_http_downstream_cx_destroy_remote_active_rq$",
                    "^envoy_cluster_upstream_flow_control_(paused_reading_total|resumed_reading_total|backed_up_total|drained_total)$",
                    "^envoy_cluster_upstream_rq_retry$",
                    "^envoy_cluster_upstream_rq_retry_(success|overflow)$",
                    "^envoy_server_(version|uptime|live)$"
                  ]
                },
                {
                  "source_labels": ["container_name"],
                  "label_matcher": "^envoy$",
                  "dimensions": [["ClusterName","Namespace","envoy_http_conn_manager_prefix","envoy_response_code_class"]],
                  "metric_selectors": [
                    "^envoy_http_downstream_rq_xx$"
                  ]
                },
                {
                  "source_labels": ["container_name"],
                  "label_matcher": "^fluent-bit.*$",
                  "dimensions": [["ClusterName","Namespace","NodeName"]],
                  "metric_selectors": [
                    "^fluentbit_output_errors_total$",
                    "^fluentbit_input_bytes_total$",
                    "^fluentbit_output_proc_bytes_total$",
                    "^fluentbit_input_records_total$",
                    "^fluentbit_output_proc_records_total$",
                    "^fluentbit_output_retries_(total|failed_total)$"
                  ]
                },
                {
                  "source_labels": ["job"],
                  "label_matcher": "^kubernetes-pod-jmx$",
                  "dimensions": [["ClusterName","Namespace"]],
                  "metric_selectors": [
                    "^jvm_threads_(current|daemon)$",
                    "^jvm_classes_loaded$",
                    "^java_lang_operatingsystem_(freephysicalmemorysize|totalphysicalmemorysize|freeswapspacesize|totalswapspacesize|systemcpuload|processcpuload|availableprocessors|openfiledescriptorcount)$",
                    "^catalina_manager_(rejectedsessions|activesessions)$",
                    "^jvm_gc_collection_seconds_(count|sum)$",
                    "^catalina_globalrequestprocessor_(bytesreceived|bytessent|requestcount|errorcount|processingtime)$"
                  ]
                },
                {
                  "source_labels": ["job"],
                  "label_matcher": "^kubernetes-pod-jmx$",
                  "dimensions": [["ClusterName","Namespace","area"]],
                  "metric_selectors": [
                    "^jvm_memory_bytes_used$"
                  ]
                },
                {
                  "source_labels": ["job"],
                  "label_matcher": "^kubernetes-pod-jmx$",
                  "dimensions": [["ClusterName","Namespace","pool"]],
                  "metric_selectors": [
                    "^jvm_memory_pool_bytes_used$"
                  ]
                }
              ]
            }
          }
        },
        "force_flush_interval": 5
      }
    }
CONFIG
  }
}

resource "kubernetes_config_map_v1" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }
  data = {
    "prometheus.yaml" = <<CONFIG
        global:
      scrape_interval: 1m
      scrape_timeout: 10s
    scrape_configs:
    - job_name: 'kubernetes-pod-appmesh-envoy'
      sample_limit: 10000
      metrics_path: /stats/prometheus
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_container_name]
        action: keep
        regex: '^envoy$'
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: ${1}:9901
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: Namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod_name
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container_name
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_controller_name
        target_label: pod_controller_name
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_controller_kind
        target_label: pod_controller_kind
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_phase
        target_label: pod_phase

    - job_name: 'kubernetes-pod-fluentbit-plugin'
      sample_limit: 10000
      metrics_path: /api/v1/metrics/prometheus
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_container_name]
        action: keep
        regex: '^fluent-bit.*$'
      - source_labels: [__address__]
        action: replace
        regex: ([^:]+)(?::\d+)?
        replacement: ${1}:2020
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: Namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod_name
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container_name
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_controller_name
        target_label: pod_controller_name
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_controller_kind
        target_label: pod_controller_kind
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_phase
        target_label: pod_phase
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: NodeName

    - job_name: kubernetes-service-endpoints
      sample_limit: 10000
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape
      - action: replace
        regex: (https?)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scheme
        target_label: __scheme__
      - action: replace
        regex: (.+)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        source_labels:
        - __address__
        - __meta_kubernetes_service_annotation_prometheus_io_port
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: Namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_service_name
        target_label: Service
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: kubernetes_node
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod_name
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container_name
      metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'go_gc_duration_seconds.*'
        action: drop
      - source_labels: [__name__, proxy]
        regex: "haproxy_frontend.+;(.+)"
        target_label: frontend
        replacement: "$1"
      - source_labels: [__name__, proxy]
        regex: "haproxy_server.+;(.+)"
        target_label: backend
        replacement: "$1"
      - source_labels: [__name__, proxy]
        regex: "haproxy_backend.+;(.+)"
        target_label: backend
        replacement: "$1"
      - regex: proxy
        action: labeldrop

    - job_name: 'kubernetes-pod-jmx'
      sample_limit: 10000
      metrics_path: /metrics
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__address__]
        action: keep
        regex: '.*:9404$'
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: Namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod_name
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container_name
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_controller_name
        target_label: pod_controller_name
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_controller_kind
        target_label: pod_controller_kind
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_phase
        target_label: pod_phase
      metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'jvm_gc_collection_seconds.*'
        action: drop
CONFIG
  }
}

resource "kubernetes_cluster_role_v1" "cwagent_prometheus" {

  metadata {
    name = "cwagent-prometheus-role"
  }

  rule {
    api_groups = [""]
    resources = [
      "nodes",
      "nodes/proxy",
      "services",
      "endpoints",
      "pods",
    ]
    verbs = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "cwagent_prometheus_role_binding" {
  metadata {
    name = "cwagent-prometheus-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.cwagent_prometheus.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.eks_cwagent_prometheus.metadata.0.name
    namespace = kubernetes_service_account.eks_cwagent_prometheus.metadata.0.namespace
  }
}

resource "kubernetes_deployment_v1" "cwagent_prometheus" {
  metadata {
    name      = "cwagent-prometheus"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name
    labels = {
      name                           = "cwagent-prometheus"
      app                            = "cwagent-prometheus"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "cwagent-prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "cwagent-prometheus"
        }
      }
      spec {
        host_network = true
        container {
          name              = "cwagent-prometheus"
          image             = "amazon/cloudwatch-agent:1.247350.0b251814-amd64"
          image_pull_policy = "Always"
          resources {
            limits = {
              cpu    = "1000m"
              memory = "1000Mi"
            }
            requests = {
              cpu    = "200m"
              memory = "200Mi"
            }
          }
          env {
            name  = "CI_VERSION"
            value = "k8s/1.3.9"
          }
          volume_mount {
            name       = "prometheus-cwagentconfig"
            mount_path = "/etc/cwagentconfig"
          }
          volume_mount {
            name       = "prometheus-config"
            mount_path = "/etc/prometheusconfig"
          }
        }
        volume {
          name = "prometheus-cwagentconfig"
          config_map {
            name = "prometheus-cwagentconfig"
          }
        }
        volume {
          name = "prometheus-config"
          config_map {
            name = "prometheus-config"
          }
        }
        termination_grace_period_seconds = 60
        service_account_name             = kubernetes_service_account.eks_cwagent_prometheus.metadata.0.name
      }
    }
  }
}
