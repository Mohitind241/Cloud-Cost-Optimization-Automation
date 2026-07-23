# ============================================================
# Cost Automation Module — Input Variables
# ============================================================

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from the networking module"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID from the networking module"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID — Lambda is placed here"
  type        = string
}

variable "lambda_sg_id" {
  description = "Security group ID for the Lambda function"
  type        = string
}

variable "cost_alert_email" {
  description = "Email for budget and cost-anomaly notifications"
  type        = string
}

variable "monthly_budget_limit" {
  description = "Monthly budget cap in USD"
  type        = number
}

variable "lambda_schedule_expression" {
  description = "CloudWatch schedule expression for triggering Lambda"
  type        = string
}

variable "idle_resource_threshold_days" {
  description = "Days of idle time before a resource is flagged"
  type        = number
}
