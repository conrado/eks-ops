provider "aws" {
  region = "sa-east-1"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

module "irsa_role_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "ice01-irsa"

  oidc_providers = {
    blue = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:blue", "canary:blue"]
    }
    green = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:green", "canary:green"]
    }
  }

  role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ]
}

module "irsa_role_cert_manager_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                  = "ice01-irsa-cert-manager"
  attach_cert_manager_policy = true
  cert_manager_hosted_zone_arns = [
    "arn:aws:route53:::hostedzone/ZKN5BA79XG7M3", # icekernelcloud01.com
  ]

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cert-manager"]
    }
  }
}

module "irsa_role_cluster_autoscaler_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                        = "ice01-irsa-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [module.eks.cluster_id]

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

module "irsa_role_ebs_csi_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "ice01-irsa-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-ebs-csi-driver"]
    }
  }
}

module "irsa_role_efs_csi_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "ice01-irsa-efs-csi"
  attach_efs_csi_policy = true

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}

module "irsa_role_external_dns_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                  = "ice01-irsa-external-dns"
  attach_external_dns_policy = true

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

module "irsa_role_external_secrets_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                      = "ice01-irsa-external-secrets"
  attach_external_secrets_policy = true

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:kubernetes-external-secrets"]
    }
  }
}

module "irsa_role_fsx_lustre_csi_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                    = "ice01-irsa-fsx-lustre-csi"
  attach_fsx_lustre_csi_policy = true

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:fsx-csi-controller-sa"]
    }
  }
}

module "irsa_role_karpenter_controller_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                          = "ice01-irsa-karpenter-controller"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_id         = module.eks.cluster_id
  karpenter_controller_node_iam_role_arns = [module.eks.eks_managed_node_groups["blue"].iam_role_arn, module.eks.eks_managed_node_groups["blue"].iam_role_arn]

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }
}

module "irsa_role_load_balancer_controller_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "ice01-irsa-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# module "irsa_role_appmesh_controller_ice01" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

#   role_name                        = "ice01-irsa-appmesh-controller"
#   attach_appmesh_controller_policy = true

#   oidc_providers = {
#     kubesys = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["appmesh-system:appmesh-controller"]
#     }
#   }
# }

module "irsa_role_appmesh_envoy_proxy_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                         = "ice01-irsa-appmesh-envoy-proxy"
  attach_appmesh_envoy_proxy_policy = true

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["appmesh-system:appmesh-envoy-proxy"]
    }
  }
}

module "irsa_role_amazon_managed_service_prometheus_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                                       = "ice01-irsa-amazon-managed-service-prometheus"
  attach_amazon_managed_service_prometheus_policy = true

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["prometheus:amp-ingest"]
    }
  }
}

module "irsa_role_node_termination_handler_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "ice01-irsa-node-termination-handler"
  attach_node_termination_handler_policy = true

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

module "irsa_role_velero_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "ice01-irsa-velero"
  attach_velero_policy  = true
  velero_s3_bucket_arns = ["arn:aws:s3:::ice01-velero-backups"]

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["velero:velero"]
    }
  }
}

module "irsa_role_vpc_cni_ice01" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "ice01-irsa-vpc-cni"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  vpc_cni_enable_ipv6   = true

  oidc_providers = {
    kubesys = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  config_path            = "~/.kube/config"
  config_context         = "arn:aws:eks:sa-east-1:711054401116:cluster/ice01"
  # config_context        = local.cluster_name
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name = "ice01"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.14"

  name                 = "ice01"
  cidr                 = "172.16.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets       = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.20"

  cluster_name    = local.cluster_name
  cluster_version = "1.22"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  eks_managed_node_groups = {
    blue = {}
    green = {
      desired_capacity = 1
      max_capacity     = 10
      min_capacity     = 1
      instance_types   = ["m5.large"]
    }
  }
}
