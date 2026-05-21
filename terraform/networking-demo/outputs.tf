output "transit_gateway_id" {
  value       = aws_ec2_transit_gateway.demo.id
  description = "Transit Gateway ID"
}

output "partner_vpc_id" {
  value       = aws_vpc.partner.id
  description = "Partner VPC ID"
}

output "partner_instance_id" {
  value       = aws_instance.partner.id
  description = "Partner EC2 instance ID"
}

output "partner_private_ip" {
  value       = aws_instance.partner.private_ip
  description = "Partner EC2 private IP"
}

output "partner_security_group_id" {
  value       = aws_security_group.partner.id
  description = "Partner EC2 security group ID (for fault injection)"
}

output "nlb_dns_name" {
  value       = aws_lb.partner.dns_name
  description = "Partner NLB DNS name"
}

output "route53_zone_id" {
  value       = aws_route53_zone.partner.zone_id
  description = "Partner Route53 private hosted zone ID (for fault injection)"
}

output "tgw_route_table_id" {
  value       = aws_ec2_transit_gateway.demo.association_default_route_table_id
  description = "TGW default route table ID (for fault injection)"
}
