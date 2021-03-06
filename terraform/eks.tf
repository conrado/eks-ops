module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.21"

  cluster_name    = var.cluster_name
  cluster_version = "1.22"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  # cluster_addons = {
  #   coredns = {
  #     resolve_conflicts = "OVERWRITE"
  #   }
  #   kube-proxy = {}
  #   vpc-cni = {
  #     resolve_conflicts = "OVERWRITE"
  #   }
  # }

  # let's not set this in demo mode... destroying it is a pain
  # cluster_encryption_config = [{
  #   provider_key_arn = aws_kms_key.eks.arn
  #   resources        = ["secrets"]
  # }]

  cluster_enabled_log_types = [
    "audit",
    "api",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  eks_managed_node_group_defaults = {
    desired_capacity                     = 3
    max_capacity                         = 10
    min_capacity                         = 1
    instance_types                       = ["m5.large"]
    metadata_http_put_response_hop_limit = 2
    # key_name                             = "conrado@icekernel.com"
  }

  eks_managed_node_groups = {
    ng1 = {}
    ng2 = {}
    # ng3 = {}
  }

  # fargate_profiles = {
  #   fargate_productcatalog = {
  #     name = "fargate-productcatalog"
  #     selectors = [
  #       {
  #         namespace = "prodcatalog-ns"
  #       }
  #     ]
  #   }
  # }

  node_security_group_additional_rules = {

    # ingress_allow_ssh_from_bastion = {
    #   type                     = "ingress"
    #   protocol                 = "tcp"
    #   from_port                = 22
    #   to_port                  = 22
    #   source_security_group_id = module.bastion.bastion_sg
    #   description              = "Allow SSH from bastion"
    # }

    # ingress_self_all = {
    #   description = "Node to node all ports/protocols"
    #   protocol    = "-1"
    #   from_port   = 0
    #   to_port     = 0
    #   type        = "ingress"
    #   self        = true
    # }

    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }

    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
}

# resource "aws_kms_key" "eks" {
#   description             = "EKS Secret Encryption Key"
#   deletion_window_in_days = 7
#   enable_key_rotation     = true

#   tags = local.tags
# }
