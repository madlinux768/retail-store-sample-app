# Transit Gateway connecting app VPC and partner VPC
#
# TGW is created in the networking account and shared via RAM to the app account.

resource "aws_ec2_transit_gateway" "demo" {
  description                     = "DevOps Agent networking demo"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments  = "enable"

  tags = { Name = "networking-demo-tgw" }
}

# Share TGW with app account via Resource Access Manager
resource "aws_ram_resource_share" "tgw" {
  name                      = "networking-demo-tgw-share"
  allow_external_principals = true
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.demo.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "app_account" {
  principal          = var.app_account_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

# Attach partner VPC to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "partner" {
  subnet_ids         = aws_subnet.partner_private[*].id
  transit_gateway_id = aws_ec2_transit_gateway.demo.id
  vpc_id             = aws_vpc.partner.id

  tags = { Name = "partner-vpc-attachment" }
}

# Wait for RAM share to propagate to app account
resource "time_sleep" "ram_propagation" {
  create_duration = "60s"

  depends_on = [aws_ram_principal_association.app_account]
}

# Attach app VPC to TGW (in app account)
resource "aws_ec2_transit_gateway_vpc_attachment" "app" {
  provider = aws.app

  subnet_ids         = var.app_private_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.demo.id
  vpc_id             = var.app_vpc_id

  tags = { Name = "app-vpc-attachment" }

  depends_on = [time_sleep.ram_propagation]
}

# Accept the attachment from the networking account (cross-account, not same org)
resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "app" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.app.id

  tags = { Name = "app-vpc-attachment" }
}

# Route in app VPC to partner network via TGW
resource "aws_route" "app_to_partner" {
  provider = aws.app

  route_table_id         = var.app_route_table_id
  destination_cidr_block = var.partner_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.demo.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.app]
}

