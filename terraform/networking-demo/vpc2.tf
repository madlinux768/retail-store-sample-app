# Partner VPC in the networking account

resource "aws_vpc" "partner" {
  cidr_block           = var.partner_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "partner-network" }
}

resource "aws_subnet" "partner_private" {
  count             = 2
  vpc_id            = aws_vpc.partner.id
  cidr_block        = cidrsubnet(var.partner_vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "partner-private-${count.index}" }
}

resource "aws_route_table" "partner_private" {
  vpc_id = aws_vpc.partner.id
  tags   = { Name = "partner-private-rt" }
}

resource "aws_route" "partner_to_app" {
  route_table_id         = aws_route_table.partner_private.id
  destination_cidr_block = var.app_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.demo.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.partner]
}

resource "aws_route_table_association" "partner_private" {
  count          = 2
  subnet_id      = aws_subnet.partner_private[count.index].id
  route_table_id = aws_route_table.partner_private.id
}
