# ============================================================
# Variables — Cloud Cost Optimization with Automation
# ============================================================

variable "aws_region" {
  description = "AWS region where all resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Team or individual responsible for this project"
  type        = string
  default     = "devops-team"
}

# ─── Networking ───────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.10.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone for subnets"
  type        = string
  default     = "us-east-1a"
}

# ─── Cost Alerting ────────────────────────────────────────────

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD. Alert triggers at 80 percent."
  type        = number
  default     = 100
}

variable "cost_alert_email" {
  description = "Email address to receive cost-anomaly and budget alerts"
  type        = string
  default     = "your-email@example.com"
}

# ─── Lambda ───────────────────────────────────────────────────

variable "lambda_schedule_expression" {
  description = "CloudWatch Events schedule for the Lambda cost-analyser (cron or rate)"
  type        = string
  default     = "rate(1 day)"
}

variable "idle_resource_threshold_days" {
  description = "Number of days a resource must be idle before Lambda flags it"
  type        = number
  default     = 7
}

# ─── S3 State Backend ─────────────────────────────────────────

variable "tf_state_bucket" {
  description = "S3 bucket used to store Terraform remote state"
  type        = string
  default     = "cloud-cost-opt-tfstate"
}

variable "tf_state_key" {
  description = "Key (path) within the S3 bucket for the state file"
  type        = string
  default     = "terraform/prod/terraform.tfstate"
}

variable "tf_state_dynamodb_table" {
  description = "DynamoDB table for Terraform state locking"
  type        = string
  default     = "cloud-cost-opt-tf-lock"
}
