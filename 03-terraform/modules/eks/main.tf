# -----------------------------------------------------------------------------
# EKS Control Plane IAM Role
# -----------------------------------------------------------------------------
# IAM role assumed by the Amazon EKS service to manage the Kubernetes control
# plane.
resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cluster-role"
  }
}

# Attach the AWS-managed permissions required by the EKS control plane.
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# -----------------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------------
# Creates the managed Kubernetes control plane.
#
# The cluster uses private subnets from the Phase 03 VPC foundation.
# Private API access is enabled for resources inside the VPC.
# Public API access remains enabled for administration from outside AWS but is
# restricted to explicitly approved CIDR blocks.
# Trivy exception: public EKS API access is intentionally retained for the
# development environment and restricted to explicitly approved /32 CIDRs.
# Private API access remains enabled. Production hardening can move to
# private-only control-plane access.
# trivy:ignore:AWS-0040 trivy:ignore:AWS-0041
resource "aws_eks_cluster" "this" {
  name     = "${var.project_name}-${var.environment}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  # Export all EKS control-plane log types to CloudWatch for
  # security auditing, authentication visibility, and troubleshooting.
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.cluster_public_access_cidrs
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-eks"
  }
}

# -----------------------------------------------------------------------------
# EKS Managed Node IAM Role
# -----------------------------------------------------------------------------
# IAM role assumed by EC2 instances in the EKS managed node group.
resource "aws_iam_role" "nodes" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-node-role"
  }
}

# Allows worker nodes to communicate with and participate in the EKS cluster.
resource "aws_iam_role_policy_attachment" "worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

# Allows worker nodes to pull Baba App container images from Amazon ECR.
resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

# Grants the permissions required by the Amazon VPC CNI plugin.
#
# This is sufficient for the initial cluster foundation. A later security
# hardening step can move CNI permissions to a dedicated workload identity
# rather than leaving them attached to the EC2 node role.
resource "aws_iam_role_policy_attachment" "cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

# -----------------------------------------------------------------------------
# EKS Managed Node Group
# -----------------------------------------------------------------------------
# Worker nodes run in private subnets and do not require direct public IP
# addressing. Outbound internet access is provided through the Phase 03 NAT
# Gateway when required.
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-${var.environment}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types

  # Development scaling configuration balances availability and AWS cost.
  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # Limits disruption during managed node-group updates.
  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node,
    aws_iam_role_policy_attachment.ecr_read_only,
    aws_iam_role_policy_attachment.cni
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-node-group"
  }
}
