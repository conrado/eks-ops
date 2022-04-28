variable "cluster_name" {
  type    = string
  default = "ice01"
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
