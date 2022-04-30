variable "aws_region" {
  description = "The AWS region we deploy to"
  default     = "sa-east-1"
}

variable "cluster_name" {
  type    = string
  default = "my-cluster"
}

variable "domain_name" {
  type    = string
  default = "icekernelcloud01.com"
}

variable "subdomain" {
  default = "www"
}

variable "tags" {
  default = {
    ManagedBy = "terraform"
  }
}

