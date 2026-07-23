# ============================================================
# Cost Automation Module
# Resources: IAM, Lambda, SNS, CloudWatch, AWS Budgets
# Project: Cloud Cost Optimization with Automation
# ============================================================

# ─── SNS Topic for Cost Alerts ────────────────────────────────
resource "aws_sns_topic" "cost_alerts" {
  name = "${var.environment}-cost-optimization-alerts"

  tags = {
    Name = "${var.environment}-cost-alerts"
  }
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.cost_alert_email
}

# ─── IAM Role for Lambda ──────────────────────────────────────
resource "aws_iam_role" "lambda_cost_role" {
  name = "${var.environment}-lambda-cost-analyser-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "lambda_cost_policy" {
  name        = "${var.environment}-lambda-cost-analyser-policy"
  description = "Grants Lambda access to Cost Explorer, EC2 describe, SNS publish, and CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CostExplorerRead"
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetCostForecast",
          "ce:GetReservationUtilization",
          "ce:GetSavingsPlansUtilization",
          "ce:GetAnomalies",
          "ce:ListCostAllocationTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2DescribeForIdleDetection"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeAddresses",
          "ec2:DescribeLoadBalancers"
        ]
        Resource = "*"
      },
      {
        Sid      = "SNSPublishAlerts"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.cost_alerts.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_cost_attach" {
  role       = aws_iam_role.lambda_cost_role.name
  policy_arn = aws_iam_policy.lambda_cost_policy.arn
}

# Attach basic VPC execution policy so Lambda can run inside VPC
resource "aws_iam_role_policy_attachment" "lambda_vpc_attach" {
  role       = aws_iam_role.lambda_cost_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ─── Lambda: Cost Analyser ────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda"
  output_path = "${path.module}/../../lambda/cost_analyser.zip"
}

resource "aws_lambda_function" "cost_analyser" {
  function_name    = "${var.environment}-cost-analyser"
  role             = aws_iam_role.lambda_cost_role.arn
  handler          = "cost_analyser.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 300
  memory_size      = 256

  environment {
    variables = {
      SNS_TOPIC_ARN                = aws_sns_topic.cost_alerts.arn
      ENVIRONMENT                  = var.environment
      IDLE_THRESHOLD_DAYS          = tostring(var.idle_resource_threshold_days)
      AWS_ACCOUNT_REGION           = var.aws_region
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_id]
    security_group_ids = [var.lambda_sg_id]
  }

  tags = {
    Name = "${var.environment}-cost-analyser-lambda"
  }
}

# ─── CloudWatch Log Group for Lambda ──────────────────────────
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.cost_analyser.function_name}"
  retention_in_days = 14

  tags = {
    Name = "${var.environment}-lambda-cost-logs"
  }
}

# ─── CloudWatch Events: Daily Schedule ───────────────────────
resource "aws_cloudwatch_event_rule" "daily_cost_check" {
  name                = "${var.environment}-daily-cost-analyser"
  description         = "Triggers Lambda cost-analyser on a daily schedule"
  schedule_expression = var.lambda_schedule_expression
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_cost_check.name
  target_id = "cost-analyser-lambda"
  arn       = aws_lambda_function.cost_analyser.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_analyser.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cost_check.arn
}

# ─── AWS Budget: Monthly Spend Alert ─────────────────────────
resource "aws_budgets_budget" "monthly_cost_budget" {
  name              = "${var.environment}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = tostring(var.monthly_budget_limit)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.cost_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.cost_alert_email]
  }
}

# ─── CloudWatch Dashboard ─────────────────────────────────────
resource "aws_cloudwatch_dashboard" "cost_dashboard" {
  dashboard_name = "${var.environment}-cloud-cost-optimization"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Cost Analyser Invocations"
          region = var.aws_region
          metrics = [
            ["AWS/Lambda", "Invocations",
             "FunctionName", aws_lambda_function.cost_analyser.function_name,
             { stat = "Sum", period = 86400 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Errors"
          region = var.aws_region
          metrics = [
            ["AWS/Lambda", "Errors",
             "FunctionName", aws_lambda_function.cost_analyser.function_name,
             { stat = "Sum", period = 86400, color = "#d62728" }]
          ]
          view = "timeSeries"
        }
      }
    ]
  })
}
