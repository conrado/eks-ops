variable "aws_region" {
  description = "The AWS region we deploy to"
  default     = "us-west-2"
}

variable "cluster_name" {
  type    = string
  default = "ice"
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

