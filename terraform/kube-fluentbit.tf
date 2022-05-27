resource "kubernetes_namespace" "aws_observability" {
  metadata {
    name = "aws-observability"
  }
}

resource "kubernetes_config_map_v1" "aws_logging" {
  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace.aws_observability.metadata.0.name
  }
  data = {
    "output.conf" = <<CONFIG
[OUTPUT]
  Name cloudwatch_logs
  Match   *
  region ${var.aws_region}
  log_group_name fluent-bit-cloudwatch
  log_stream_prefix from-fluent-bit-
  auto_create_group true
CONFIG
  }
}

data "aws_iam_policy_document" "fluentbit_fargate" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      "*",
    ]
  }
}

module "iam_policy_fluentbit" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  name        = "FluentBitEKSFargate"
  description = "Policy for fluentbit"
  policy      = data.aws_iam_policy_document.fluentbit_fargate.json
}

module "irsa_fluentbit" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  role_name = "${var.cluster_name}-irsa-fluentbit"

  provider_url = module.eks.oidc_provider

  role_policy_arns = [
    module.iam_policy_fluentbit.arn,
  ]
}
