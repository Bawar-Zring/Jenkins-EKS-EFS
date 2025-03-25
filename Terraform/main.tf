provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

    tags = {
        Name = "main"
    }
}

resource "aws_subnet" "public-AZ1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
    tags = {
        Name = "public-AZ1"
    }
}

resource "aws_subnet" "private-AZ1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

    tags = {
        Name = "private-AZ1"
    }
}

resource "aws_subnet" "public-AZ2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
    tags = {
        Name = "public-AZ2"
    }
}

resource "aws_subnet" "private-AZ2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"

    tags = {
        Name = "private-AZ2"
    }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.main.id
    tags = {
        Name = "IGW"
    }  
}

resource "aws_route_table" "public-routes" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  
  tags = {
    Name = "Public-Routes"
  }
}

resource "aws_route_table_association" "public-AZ1" {
  subnet_id      = aws_subnet.public-AZ1.id
  route_table_id = aws_route_table.public-routes.id
}

resource "aws_route_table_association" "public-AZ2" {
  subnet_id      = aws_subnet.public-AZ2.id
  route_table_id = aws_route_table.public-routes.id
}

resource "aws_eip" "NAT-EIP" {
  domain = "vpc"
}

resource "aws_nat_gateway" "NAT-GW" {
  allocation_id = aws_eip.NAT-EIP.id
  subnet_id = aws_subnet.public-AZ1.id

  tags = {
    Name = "NAT-GW"
  }

  depends_on = [aws_internet_gateway.IGW]
}

resource "aws_route_table" "private-routes" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT-GW.id
  }

  tags = {
    Name = "Private-Routes"
  }
}

resource "aws_route_table_association" "private-AZ1" {
  subnet_id      = aws_subnet.private-AZ1.id
  route_table_id = aws_route_table.private-routes.id
}

resource "aws_route_table_association" "private-AZ2" {
  subnet_id      = aws_subnet.private-AZ2.id
  route_table_id = aws_route_table.private-routes.id
}

resource "aws_security_group" "eks-cluster" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_iam_role" "eks-role" {
  name = "eks-role-jenkins"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-role.name
}

resource "aws_eks_cluster" "eks-cluster" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks-role.arn
  vpc_config {
    subnet_ids = [aws_subnet.private-AZ1.id, aws_subnet.private-AZ2.id]
    security_group_ids = [aws_security_group.eks-cluster.id]
  }
}   

resource "aws_iam_role" "eks-node-role" {
  name = "eks-node-role-jenkins"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-node-role.name
}

resource "aws_eks_node_group" "eks-node-group" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks-node-role.arn
  subnet_ids      = [aws_subnet.private-AZ1.id, aws_subnet.private-AZ2.id]
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }
  instance_types = ["t3.medium"]
  ami_type       = "AL2_x86_64"
}

resource "aws_security_group" "efs_sg" {
  name        = "efs-security-group"
  description = "Security group for Amazon EFS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [aws_security_group.eks-cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-security-group"
  }
}

resource "aws_efs_file_system" "jenkins-efs" {
  creation_token = "jenkins-efs"
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"
}

resource "aws_efs_mount_target" "jenkins-efs-mount" {
  file_system_id = aws_efs_file_system.jenkins-efs.id
  subnet_id = aws_subnet.private-AZ1.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "jenkins-efs-mount2" {
  file_system_id = aws_efs_file_system.jenkins-efs.id
  subnet_id = aws_subnet.private-AZ2.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_access_point" "jenkins-efs-access-point" {
  file_system_id = aws_efs_file_system.jenkins-efs.id
  root_directory {
    path = "/jenkins"
  }
  posix_user {
    uid = 1000
    gid = 1000
  }
  tags = {
    Name = "jenkins-efs-access-point"
  }
}