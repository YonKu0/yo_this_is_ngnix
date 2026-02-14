resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB ingress from internet; egress only to app port in private subnet."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To app port in private subnet"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "App EC2: only ALB can reach the app port."
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "App port from ALB SG"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS for package installs, ECR auth/pull, and service APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS UDP to VPC resolver"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [format("%s/32", cidrhost(var.vpc_cidr, 2))]
  }

  egress {
    description = "DNS TCP to VPC resolver"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [format("%s/32", cidrhost(var.vpc_cidr, 2))]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-app-sg"
  })
}

resource "aws_security_group" "nat" {
  name        = "${var.name_prefix}-nat-sg"
  description = "NAT instance: allow forwarding for the private subnet."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Forwarded HTTP from private subnet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
  }

  ingress {
    description = "Forwarded HTTPS from private subnet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
  }

  ingress {
    description = "Forwarded DNS UDP from private subnet"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.private_subnet_cidr]
  }

  ingress {
    description = "Forwarded DNS TCP from private subnet"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
  }

  egress {
    description = "Outbound HTTP to internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound HTTPS to internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound DNS UDP to internet"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound DNS TCP to internet"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-nat-sg"
  })
}

