
# 2. Khởi tạo tài nguyên HTTP API Gateway
resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    allow_credentials = false
    max_age           = 300
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

# 3. Tạo CloudWatch Log Group cho Access logs
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.project_name}-api-logs"
  retention_in_days = 30

  tags = {
    Name = "/aws/apigateway/${var.project_name}-api-logs"
  }
}

# 4. Khởi tạo Stage của API Gateway hỗ trợ Access Logging
resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      latency        = "$context.responseLatency"
    })
  }

  tags = {
    Name = "${var.project_name}-api-stage-${replace(var.stage_name, "$", "")}"
  }
}

# 5. Khởi tạo Cognito JWT Authorizer (chỉ tạo nếu cung cấp Cognito Endpoint)
resource "aws_apigatewayv2_authorizer" "cognito" {
  count            = var.enable_cognito_authorizer ? 1 : 0
  api_id           = aws_apigatewayv2_api.this.id
  name             = "${var.project_name}-cognito-authorizer"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = var.cognito_client_ids
    issuer   = "https://${var.cognito_user_pool_endpoint}"
  }
}

# 6. Khởi tạo Lambda Proxy Integrations dùng cho các routes
resource "aws_apigatewayv2_integration" "this" {
  for_each = var.routes

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_arns[each.value.lambda_key]
  payload_format_version = "2.0" # Tiêu chuẩn cho HTTP APIs
}

# 7. Khởi tạo API Routes liên kết với các Integrations
resource "aws_apigatewayv2_route" "this" {
  for_each = var.routes

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.value.route_key
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"

  # Áp dụng xác thực nếu bật cờ và có cấu hình Cognito
  authorization_type = each.value.enable_authorizer && var.enable_cognito_authorizer ? "JWT" : "NONE"
  authorizer_id      = each.value.enable_authorizer && var.enable_cognito_authorizer ? aws_apigatewayv2_authorizer.cognito[0].id : null
}

# 8. Cấp quyền tự động cho API Gateway để kích hoạt (invoke) các Lambda Backend
resource "aws_lambda_permission" "api_gateway" {
  for_each = var.routes

  statement_id  = "AllowAPIGatewayInvoke-${var.project_name}-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arns[each.value.lambda_key]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
