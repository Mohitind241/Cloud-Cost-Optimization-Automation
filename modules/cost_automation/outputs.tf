# ============================================================
# Cost Automation Module — Outputs
# ============================================================

output "lambda_arn" {
  description = "ARN of the cost-analyser Lambda function"
  value       = aws_lambda_function.cost_analyser.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic used for cost alerts"
  value       = aws_sns_topic.cost_alerts.arn
}

output "budget_id" {
  description = "ID of the AWS monthly budget"
  value       = aws_budgets_budget.monthly_cost_budget.id
}

output "dashboard_url" {
  description = "Deep-link URL to the CloudWatch cost dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.cost_dashboard.dashboard_name}"
}

output "cloudwatch_event_rule_arn" {
  description = "ARN of the CloudWatch Events rule that schedules Lambda"
  value       = aws_cloudwatch_event_rule.daily_cost_check.arn
}
