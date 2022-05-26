variable "aws_region" {
  description = "The AWS region we deploy to"
  default     = "sa-east-1"
}

variable "cluster_name" {
  type    = string
  default = "ice"
}

variable "domain_name" {
  type    = string
  default = "icekernelcloud01.com"
}

variable "eks_ingress_subdomain" {
  default = "origin"
}

variable "cloudfront_subdomain" {
  default = "www"
}

variable "tags" {
  default = {
    ManagedBy = "terraform"
  }
}

