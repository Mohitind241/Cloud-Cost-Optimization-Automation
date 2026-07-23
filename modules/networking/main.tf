# ============================================================
# Networking Module — VPC, Subnets, Security Groups
# Project: Cloud Cost Optimization with Automation
# ============================================================

# ─── VPC ──────────────────────────────────────────────────────
resource "aws_vpc" "cost_opt_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-cost-opt-vpc"
  }
}

# ─── Internet Gateway ─────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cost_opt_vpc.id

  tags = {
    Name = "${var.environment}-cost-opt-igw"
  }
}

# ─── Public Subnet ────────────────────────────────────────────
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.cost_opt_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-cost-opt-public-sn"
    Tier = "public"
  }
}

# ─── Private Subnet ───────────────────────────────────────────
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.cost_opt_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.environment}-cost-opt-private-sn"
    Tier = "private"
  }
}

# ─── Route Table (Public) ─────────────────────────────────────
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cost_opt_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.environment}-cost-opt-public-rt"
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ─── Security Group for Lambda ────────────────────────────────
resource "aws_security_group" "lambda_sg" {
  name        = "${var.environment}-lambda-cost-sg"
  description = "Security group for the cost-analyser Lambda function"
  vpc_id      = aws_vpc.cost_opt_vpc.id

  # Lambda only needs outbound HTTPS to call AWS APIs
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS service endpoints"
  }

  tags = {
    Name = "${var.environment}-lambda-cost-sg"
  }
}
