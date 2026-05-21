# Partner service EC2 instance — a simple HTTP endpoint in VPC2

resource "aws_security_group" "partner" {
  name   = "partner-service"
  vpc_id = aws_vpc.partner.id

  ingress {
    description = "HTTP from app VPC via TGW"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = [var.app_vpc_cidr]
  }

  ingress {
    description = "Health check ICMP from app VPC"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = [var.app_vpc_cidr]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "partner-service-sg" }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "partner" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.partner_instance_type
  subnet_id              = aws_subnet.partner_private[0].id
  vpc_security_group_ids = [aws_security_group.partner.id]

  user_data = <<-'EOF'
#!/bin/bash
mkdir -p /srv/www/api/v1
echo '{"status":"healthy","service":"partner-api","version":"1.0"}' > /srv/www/health
echo '{"data":"partner-response"}' > /srv/www/api/v1/data

cat > /etc/systemd/system/partner-http.service <<'UNIT'
[Unit]
Description=Partner HTTP Server
After=network.target

[Service]
WorkingDirectory=/srv/www
ExecStart=/usr/bin/python3 -m http.server 80
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now partner-http
EOF

  user_data_replace_on_change = true

  tags = { Name = "partner-service" }
}
