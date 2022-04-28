module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 1.0"

  zones = {
    (var.domain_name) = {
    }
  }
}

resource "aws_acm_certificate" "ice01" {
  domain_name       = "origin.${var.domain_name}"
  validation_method = "DNS"

  tags = var.tags
}

resource "aws_route53_record" "ice01_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ice01.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone.zone_id
}

resource "aws_acm_certificate_validation" "dns_validation" {
  certificate_arn         = aws_acm_certificate.ice01.arn
  validation_record_fqdns = [for record in aws_route53_record.ice01_validation : record.fqdn]
}
