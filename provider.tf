# ============================================================
# Provider Configuration
# Project: Cloud Cost Optimization with Automation
# Tools: AWS Cost Explorer, Lambda, CloudWatch, Terraform
# ============================================================

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "cloud-cost-optimization"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}
