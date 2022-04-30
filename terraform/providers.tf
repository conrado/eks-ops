terraform {
  required_version = ">= 1.1.9"
  required_providers {
    kubernetes = "~> 2.10"
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

provider "kubernetes" {

  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token

  ## sometimes when changing some values on EKS cluster, it may need to be
  ##   destroyed for the new values to be applied. That causes localhost to be
  ##   dialed instead of the actual cluster endpoint.
  ##   uncommenting the following and setting the correct values is a
  ##   workaround to avoid the error. be sure to generate the config file too
  # config_path    = "~/.kube/config"
  # config_context = "arn:aws:eks:sa-east-1:711054401116:cluster/ice01"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  }
}
