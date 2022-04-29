module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.20"

  cluster_name    = var.cluster_name
  cluster_version = "1.22"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  eks_managed_node_groups = {
    az1 = {
      ## keep cluster cheap for now
      # desired_capacity                     = 1
      # max_capacity                         = 10
      # min_capacity                         = 1
      # instance_types                       = ["m5.large"]
      metadata_http_put_response_hop_limit = 2
    }
    az2 = {
      metadata_http_put_response_hop_limit = 2
    }
    # az3 = {
    #   metadata_http_put_response_hop_limit = 2
    # }
  }


  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
  }

}

resource "aws_eks_addon" "vpc-cni" {
  cluster_name = module.eks.cluster_id
  addon_name   = "vpc-cni"
}
