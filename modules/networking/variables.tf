# ============================================================
# Networking Module — Input Variables
# ============================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
}

variable "availability_zone" {
  description = "AWS availability zone for the subnets"
  type        = string
}

variable "environment" {
  description = "Deployment environment label (dev / staging / prod)"
  type        = string
}
