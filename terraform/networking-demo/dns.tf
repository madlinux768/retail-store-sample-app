# Route53 Private Hosted Zone for partner service
# Associated with the app VPC so ECS tasks can resolve partner.internal

resource "aws_route53_zone" "partner" {
  provider = aws.app

  name = "partner.internal"

  vpc {
    vpc_id = var.app_vpc_id
  }

  tags = { Name = "partner-internal-phz" }
}

resource "aws_route53_record" "partner_api" {
  provider = aws.app

  zone_id = aws_route53_zone.partner.zone_id
  name    = "api.partner.internal"
  type    = "A"
  ttl     = 60
  records = [aws_instance.partner.private_ip]
}

resource "aws_route53_record" "partner_health" {
  provider = aws.app

  zone_id = aws_route53_zone.partner.zone_id
  name    = "health.partner.internal"
  type    = "A"
  ttl     = 60
  records = [aws_instance.partner.private_ip]
}
