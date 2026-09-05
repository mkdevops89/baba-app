# -----------------------------------------------------------------------------
# Internal Application Security Group
# -----------------------------------------------------------------------------
# Security group for Baba App application workloads.
# Application ingress is restricted to resources originating inside the VPC.
resource "aws_security_group" "internal_app" {
  name        = "${var.project_name}-${var.environment}-internal-app-sg"
  description = "Internal application traffic for Baba App"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-internal-app-sg"
  }
}

# -----------------------------------------------------------------------------
# Backend Application Ingress
# -----------------------------------------------------------------------------
# Allows backend application traffic on TCP/8080 only from within the VPC.
resource "aws_vpc_security_group_ingress_rule" "backend" {
  security_group_id = aws_security_group.internal_app.id

  description = "Allow backend traffic from within the VPC"

  cidr_ipv4   = var.vpc_cidr
  from_port   = 8080
  to_port     = 8080
  ip_protocol = "tcp"
}

# -----------------------------------------------------------------------------
# Frontend Application Ingress
# -----------------------------------------------------------------------------
# Allows frontend application traffic on TCP/3000 only from within the VPC.
resource "aws_vpc_security_group_ingress_rule" "frontend" {
  security_group_id = aws_security_group.internal_app.id

  description = "Allow frontend traffic from within the VPC"

  cidr_ipv4   = var.vpc_cidr
  from_port   = 3000
  to_port     = 3000
  ip_protocol = "tcp"
}

# -----------------------------------------------------------------------------
# Outbound HTTPS
# -----------------------------------------------------------------------------
# Allows application workloads to reach AWS APIs, registries, package
# repositories, and external HTTPS services.
#
# The destination is currently unrestricted for TCP/443 and is documented as an
# accepted development-environment risk. Future phases can reduce this exposure
# using VPC endpoints and more restrictive egress controls.
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.internal_app.id

  description = "Allow outbound HTTPS traffic"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

