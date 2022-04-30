module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 2.9.3"

  aliases         = [var.domain_name, "${var.subdomain}.${var.domain_name}"]
  is_ipv6_enabled = true

  ## PriceClass_All is most expensive: check where your audience lives!
  # price_class         = "PriceClass_All"
  # price_class         = "PriceClass_200"
  price_class = "PriceClass_100"

  wait_for_deployment = false

  origin = {
    default = {
      domain_name = "origin.${var.domain_name}"
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
      ## do not uncomment these lines with `enabled = false` or terraform keeps
      ## complaining about the changes that don't exist
      # origin_shield = {
      #   ## origin shield incurs extra charges
      #   enabled              = true
      #   origin_shield_region = var.aws_region
      # }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "default"
    viewer_protocol_policy = "redirect-to-https"

    compress     = true
    query_string = true

    allowed_methods = [
      "HEAD",
      "GET",
      "OPTIONS",
      "PUT",
      "PATCH",
      "POST",
      "DELETE"
    ]
    cached_methods = [
      "HEAD",
      "GET",
    ]
  }

  viewer_certificate = {
    acm_certificate_arn = module.acm.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }

  tags = var.tags
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3.4.1"

  domain_name               = var.domain_name
  zone_id                   = data.aws_route53_zone.zone.id
  subject_alternative_names = ["${var.subdomain}.${var.domain_name}"]

  # the location must be us-east-1 for cloudfront to find the certificate
  providers = {
    aws = aws.virginia
  }
}

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "2.0.0" # @todo: revert to "~> 2.0" once 2.1.0 is fixed properly

  zone_id = data.aws_route53_zone.zone.zone_id

  records = [
    {
      name = ""
      type = "A"
      alias = {
        name    = module.cloudfront.cloudfront_distribution_domain_name
        zone_id = module.cloudfront.cloudfront_distribution_hosted_zone_id
      }
    },
    {
      name = var.subdomain
      type = "A"
      alias = {
        name    = module.cloudfront.cloudfront_distribution_domain_name
        zone_id = module.cloudfront.cloudfront_distribution_hosted_zone_id
      }
    },
    {
      name = ""
      type = "AAAA"
      alias = {
        name    = module.cloudfront.cloudfront_distribution_domain_name
        zone_id = module.cloudfront.cloudfront_distribution_hosted_zone_id
      }
    },
    {
      name = var.subdomain
      type = "AAAA"
      alias = {
        name    = module.cloudfront.cloudfront_distribution_domain_name
        zone_id = module.cloudfront.cloudfront_distribution_hosted_zone_id
      }
    },
  ]
}
