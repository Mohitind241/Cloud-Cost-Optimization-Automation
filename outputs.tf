# ============================================================
# Root Outputs — Cloud Cost Optimization with Automation
# ============================================================

output "vpc_id" {
  description = "ID of the VPC created for this project"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.networking.public_subnet_id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = module.networking.private_subnet_id
}

output "cost_analyser_lambda_arn" {
  description = "ARN of the cost-analyser Lambda function"
  value       = module.cost_automation.lambda_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for cost alerts"
  value       = module.cost_automation.sns_topic_arn
}

output "cost_dashboard_url" {
  description = "URL of the CloudWatch cost-monitoring dashboard"
  value       = module.cost_automation.dashboard_url
}
