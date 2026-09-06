# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
# Creates the primary Baba App development VPC.
# DNS support and hostnames are enabled for AWS service discovery and future EKS
# workloads.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Default VPC security group hardening
# -----------------------------------------------------------------------------
# Explicitly manages the VPC default security group with no ingress or egress
# rules. Baba App workloads must use purpose-built security controls instead of
# inheriting permissive default VPC behavior.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []

  tags = {
    Name = "${var.project_name}-${var.environment}-default-sg-restricted"
  }
}


# Retrieve the current AWS account ID.
# Used when constructing resource-specific KMS policies without hard-coding
# account identifiers.
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
# Provides internet connectivity for resources that use the public route table.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# -----------------------------------------------------------------------------
# Public Subnets
# -----------------------------------------------------------------------------
# Public subnets span multiple Availability Zones and are intended for resources
# such as load balancers and the NAT Gateway.
#
# Automatic public IPv4 assignment is intentionally disabled to reduce
# accidental resource exposure. A subnet is still considered public because its
# route table contains a default route through the Internet Gateway.
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"

    "kubernetes.io/role/elb" = "1"
  }
}

# -----------------------------------------------------------------------------
# Private Subnets
# -----------------------------------------------------------------------------
# Private subnets are intended for application workloads and EKS worker nodes.
# They do not have a direct route to the Internet Gateway.
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${var.availability_zones[count.index]}"

    "kubernetes.io/role/internal-elb" = "1"
  }
}

# -----------------------------------------------------------------------------
# Public Routing
# -----------------------------------------------------------------------------
# Public route table used by both public subnets.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

# Routes internet-bound traffic from public subnets through the Internet Gateway.
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Associates all public subnets with the public route table.
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------
# Elastic IP assigned to the NAT Gateway.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip"
  }
}

# A single NAT Gateway is used for the development environment to reduce cost.
# A production architecture would typically deploy one NAT Gateway per
# Availability Zone for improved resiliency.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [
    aws_internet_gateway.this
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-nat"
  }
}

# -----------------------------------------------------------------------------
# Private Routing
# -----------------------------------------------------------------------------
# Private route table shared by the private subnets in the development
# environment.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt"
  }
}

# Routes outbound internet traffic from private subnets through the NAT Gateway.
resource "aws_route" "private_nat_access" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

# Associates all private subnets with the private route table.
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# VPC Flow Log - CloudWatch Log Group
# -----------------------------------------------------------------------------
# Stores VPC Flow Logs for network visibility and security analysis.
# Logs are retained for one year and encrypted with a dedicated customer-managed
# KMS key.
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}/flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.vpc_flow_logs.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
  }
}

# -----------------------------------------------------------------------------
# VPC Flow Log IAM Role
# -----------------------------------------------------------------------------
# Dedicated IAM role assumed only by the VPC Flow Logs service.
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project_name}-${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-flow-logs-role"
  }
}

# -----------------------------------------------------------------------------
# VPC Flow Log IAM Policy
# -----------------------------------------------------------------------------
# Grants only the CloudWatch Logs permissions required to deliver VPC Flow Logs.
# Access is scoped to the Baba App Flow Log Log Group.
resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.project_name}-${var.environment}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]

        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# VPC Flow Logs
# -----------------------------------------------------------------------------
# Captures accepted and rejected network traffic for the entire VPC.
resource "aws_flow_log" "this" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-flow-log"
  }
}

# -----------------------------------------------------------------------------
# VPC Flow Log KMS Key
# -----------------------------------------------------------------------------
# Customer-managed KMS key used to encrypt the CloudWatch Log Group containing
# VPC Flow Logs.
resource "aws_kms_key" "vpc_flow_logs" {
  description             = "KMS key for Baba App VPC Flow Logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableAccountAdministration"
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"

        Principal = {
          Service = "logs.us-east-1.amazonaws.com"
        }

        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]

        Resource = "*"

        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc/${var.project_name}-${var.environment}/flow-logs"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-flow-logs-kms"
  }
}

resource "aws_kms_alias" "vpc_flow_logs" {
  name          = "alias/${var.project_name}-${var.environment}-vpc-flow-logs"
  target_key_id = aws_kms_key.vpc_flow_logs.key_id
}