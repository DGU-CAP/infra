# ──────────────────────────────────────────
# CI Alert: GitHub Actions 실패 → Bedrock 분석 → Slack 알림
# 구성: Lambda + API Gateway (HTTP) + Secrets Manager
# ──────────────────────────────────────────

data "archive_file" "ci_alert" {
  type        = "zip"
  source_file = "${path.module}/../lambda/ci_alert/handler.py"
  output_path = "${path.module}/../lambda/ci_alert/handler.zip"
}

# ──────────────────────────────────────────
# Secrets Manager (값은 콘솔에서 직접 입력)
# ──────────────────────────────────────────
resource "aws_secretsmanager_secret" "ci_alert" {
  name        = "${var.project_name}-ci-alert-secrets"
  description = "CI Alert Lambda용 시크릿 (slack_webhook_url / github_token / github_webhook_secret)"

  tags = {
    Name        = "${var.project_name}-ci-alert-secrets"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "ci_alert_init" {
  secret_id = aws_secretsmanager_secret.ci_alert.id
  secret_string = jsonencode({
    slack_webhook_url     = "REPLACE_ME"
    github_token          = "REPLACE_ME"
    github_webhook_secret = "REPLACE_ME"
  })

  # 콘솔에서 값 교체 후 Terraform이 덮어쓰지 않도록
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ──────────────────────────────────────────
# IAM Role for Lambda
# ──────────────────────────────────────────
resource "aws_iam_role" "ci_alert_lambda" {
  name = "${var.project_name}-ci-alert-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-ci-alert-lambda-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "ci_alert_lambda" {
  name = "${var.project_name}-ci-alert-lambda-policy"
  role = aws_iam_role.ci_alert_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.ci_alert.arn
      },
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-5-sonnet-20240620-v1:0"
      },
      {
        Effect   = "Allow"
        Action   = ["aws-marketplace:ViewSubscriptions", "aws-marketplace:Subscribe"]
        Resource = "*"
      },
    ]
  })
}

# ──────────────────────────────────────────
# Lambda Function
# ──────────────────────────────────────────
resource "aws_lambda_function" "ci_alert" {
  function_name    = "${var.project_name}-ci-alert"
  role             = aws_iam_role.ci_alert_lambda.arn
  filename         = data.archive_file.ci_alert.output_path
  source_code_hash = data.archive_file.ci_alert.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.ci_alert.arn
    }
  }

  tags = {
    Name        = "${var.project_name}-ci-alert"
    Environment = var.environment
  }
}

# ──────────────────────────────────────────
# API Gateway (HTTP API)
# ──────────────────────────────────────────
resource "aws_apigatewayv2_api" "ci_alert" {
  name          = "${var.project_name}-ci-alert-api"
  protocol_type = "HTTP"

  tags = {
    Name        = "${var.project_name}-ci-alert-api"
    Environment = var.environment
  }
}

resource "aws_apigatewayv2_stage" "ci_alert" {
  api_id      = aws_apigatewayv2_api.ci_alert.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "ci_alert" {
  api_id                 = aws_apigatewayv2_api.ci_alert.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ci_alert.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "ci_alert" {
  api_id    = aws_apigatewayv2_api.ci_alert.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.ci_alert.id}"
}

resource "aws_lambda_permission" "ci_alert_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ci_alert.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ci_alert.execution_arn}/*/*"
}

# ──────────────────────────────────────────
# Output: GitHub Webhook에 등록할 URL
# ──────────────────────────────────────────
output "ci_alert_webhook_url" {
  description = "GitHub Webhook에 등록할 URL (Settings > Webhooks)"
  value       = "${aws_apigatewayv2_stage.ci_alert.invoke_url}/webhook"
}
