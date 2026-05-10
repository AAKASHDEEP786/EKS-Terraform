provider "aws" {
  region = "ap-south-1"
}

# ---------------- VPC ----------------

resource "aws_vpc" "skyopsx_vpc" {
  cidr_block           = "172.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "skyopsx-vpc"
  }
}

# ---------------- Public Subnets ----------------

resource "aws_subnet" "skyopsx_subnet" {
  count = 2

  vpc_id                  = aws_vpc.skyopsx_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.skyopsx_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "skyopsx-subnet-${count.index}"

    "kubernetes.io/cluster/skyopsx-cluster" = "shared"
    "kubernetes.io/role/elb"                = "1"
  }
}

# ---------------- Internet Gateway ----------------

resource "aws_internet_gateway" "skyopsx_igw" {
  vpc_id = aws_vpc.skyopsx_vpc.id

  tags = {
    Name = "skyopsx-igw"
  }
}

# ---------------- Route Table ----------------

resource "aws_route_table" "skyopsx_route_table" {
  vpc_id = aws_vpc.skyopsx_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.skyopsx_igw.id
  }

  tags = {
    Name = "skyopsx-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count = 2

  subnet_id      = aws_subnet.skyopsx_subnet[count.index].id
  route_table_id = aws_route_table.skyopsx_route_table.id
}

# ---------------- Security Groups ----------------

resource "aws_security_group" "skyopsx_cluster_sg" {
  name   = "skyopsx-cluster-sg"
  vpc_id = aws_vpc.skyopsx_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skyopsx-cluster-sg"
  }
}

resource "aws_security_group" "skyopsx_node_sg" {
  name   = "skyopsx-node-sg"
  vpc_id = aws_vpc.skyopsx_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skyopsx-node-sg"
  }
}

# ---------------- IAM Role for EKS Cluster ----------------

resource "aws_iam_role" "skyopsx_cluster_role" {
  name = "skyopsx-cluster-role"

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
}

resource "aws_iam_role_policy_attachment" "skyopsx_cluster_role_policy" {
  role       = aws_iam_role.skyopsx_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------------- EKS Cluster ----------------

resource "aws_eks_cluster" "skyopsx" {
  name     = "skyopsx-cluster"
  role_arn = aws_iam_role.skyopsx_cluster_role.arn

  version = "1.34"

  vpc_config {
    subnet_ids         = aws_subnet.skyopsx_subnet[*].id
    security_group_ids = [aws_security_group.skyopsx_cluster_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.skyopsx_cluster_role_policy
  ]
}

# ---------------- IAM Role for Node Group ----------------

resource "aws_iam_role" "skyopsx_node_group_role" {
  name = "skyopsx-node-group-role"

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
}

resource "aws_iam_role_policy_attachment" "skyopsx_node_group_role_policy" {
  role       = aws_iam_role.skyopsx_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "skyopsx_node_group_cni_policy" {
  role       = aws_iam_role.skyopsx_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "skyopsx_node_group_registry_policy" {
  role       = aws_iam_role.skyopsx_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ---------------- EKS Node Group ----------------

resource "aws_eks_node_group" "skyopsx" {
  cluster_name    = aws_eks_cluster.skyopsx.name
  node_group_name = "skyopsx-node-group"
  node_role_arn   = aws_iam_role.skyopsx_node_group_role.arn

  version = aws_eks_cluster.skyopsx.version
  
  subnet_ids = aws_subnet.skyopsx_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name

    source_security_group_ids = [
      aws_security_group.skyopsx_node_sg.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.skyopsx_node_group_role_policy,
    aws_iam_role_policy_attachment.skyopsx_node_group_cni_policy,
    aws_iam_role_policy_attachment.skyopsx_node_group_registry_policy
  ]
}