variable "hosted_zone_id" {
  type = string
}

data "aws_route53_zone" "domain" {
  zone_id = var.hosted_zone_id
}

provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

resource "aws_acm_certificate" "certificate" {
  domain_name       = data.aws_route53_zone.domain.name
  validation_method = "DNS"

  provider = aws.us_east
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  name    = each.value.name
  records = [each.value.record]
  ttl     = 60
  type    = each.value.type
  zone_id = data.aws_route53_zone.domain.zone_id
}

resource "aws_acm_certificate_validation" "validated_cert" {
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]

  provider = aws.us_east
}

resource "aws_appsync_domain_name" "domain" {
  domain_name     = data.aws_route53_zone.domain.name
  certificate_arn = aws_acm_certificate_validation.validated_cert.certificate_arn
}

resource "aws_appsync_domain_name_api_association" "association" {
  api_id      = aws_appsync_graphql_api.appsync.id
  domain_name = aws_appsync_domain_name.domain.domain_name
}

resource "aws_route53_record" "a" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = data.aws_route53_zone.domain.name
  type    = "A"

  alias {
    name                   = aws_appsync_domain_name.domain.appsync_domain_name
    zone_id                = aws_appsync_domain_name.domain.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "aaaa" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = data.aws_route53_zone.domain.name
  type    = "AAAA"

  alias {
    name                   = aws_appsync_domain_name.domain.appsync_domain_name
    zone_id                = aws_appsync_domain_name.domain.hosted_zone_id
    evaluate_target_health = true
  }
}
