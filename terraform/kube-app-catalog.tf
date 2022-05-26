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
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
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
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
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
        container {
          name = "cloudwatch-agent"
          # image = "amazon/cloudwatch-agent:1.247350.0b251814"
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
