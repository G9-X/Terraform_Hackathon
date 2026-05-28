aws_region         = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]
project_name       = "budget-bot"

vpc_cidr = "10.0.0.0/16"

public_subnets = {}

# Phân tách rõ ràng subnets cho Application (Lambda) và Database (RDS) theo tiêu chuẩn bảo mật
private_subnets = {
  "private-app-a" = {
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    type              = "app" # Subnet riêng tư cho các hàm Lambda (Chat & CSV parser)
  }
  "private-app-b" = {
    cidr_block        = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    type              = "app" # Subnet riêng tư dự phòng cho Application
  }
  "private-db-a" = {
    cidr_block        = "10.0.3.0/24"
    availability_zone = "us-east-1a"
    type              = "db" # Subnet riêng tư cho cơ sở dữ liệu RDS (Single AZ chạy tại đây)
  }
  "private-db-b" = {
    cidr_block        = "10.0.4.0/24"
    availability_zone = "us-east-1b"
    type              = "db" # Subnet riêng tư dự phòng phục vụ RDS DB Subnet Group bắt buộc
  }
}

# Cấu hình các VPC Endpoints động và cực kỳ tiết kiệm chi phí
vpc_endpoints = {
  "s3" = {
    service_name      = "com.amazonaws.us-east-1.s3"
    vpc_endpoint_type = "Gateway"
  }
  "bedrock-runtime" = {
    service_name        = "com.amazonaws.us-east-1.bedrock-runtime"
    vpc_endpoint_type   = "Interface"
    private_dns_enabled = true
    subnet_names        = ["private-app-a"] # Tiết kiệm 50% chi phí: chỉ triển khai Endpoint ở 1 AZ (us-east-1a)
  }
}

# Cấu hình Security Group Rule (IPv4 Outbound)
lambda_sg_egress_rules = [
  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound IPv4 traffic"
  }
]

# Cấu hình chi tiết các hàm Lambda Python
lambdas = {
  "chat" = {
    handler     = "index.handler"
    runtime     = "python3.11"
    memory_size = 128        # Cấu hình siêu tiết kiệm chi phí
    timeout     = 10         # Đủ thời gian gọi Bedrock API
    source_dir  = "src/chat" # Đường dẫn thư mục code nguồn của Chat Lambda
    iam_policy_statements = [
      {
        effect    = "Allow"
        actions   = ["bedrock:InvokeModel"]
        resources = ["arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-*"]
      }
    ]
  }
  "upload" = {
    handler     = "index.handler"
    runtime     = "python3.11"
    memory_size = 256          # Cấu hình lớn hơn con chat để parse file CSV
    timeout     = 30           # Timeout lớn hơn để xử lý đồng bộ
    source_dir  = "src/upload" # Đường dẫn thư mục code nguồn của Upload Lambda
    iam_policy_statements = [
      {
        effect    = "Allow"
        actions   = ["bedrock:InvokeModel"]
        resources = ["arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-*"]
      }
    ]
  }
}

# Cấu hình Routes cho API Gateway
api_gateway_routes = {
  "chat" = {
    route_key         = "POST /chat"
    lambda_key        = "chat"
    enable_authorizer = true
  }
  "upload" = {
    route_key         = "POST /upload"
    lambda_key        = "upload"
    enable_authorizer = true
  }
}

# Cấu hình RDS Single AZ tiết kiệm tối đa chi phí
rds_db_allocated_storage = 20
rds_db_instance_class    = "db.t3.micro"
rds_db_name              = "budgetdb"
rds_multi_az             = false

# Cấu hình Cognito
cognito_clients = {
  "web-client" = {
    generate_secret                      = false
    explicit_auth_flows                  = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
    allowed_oauth_flows_user_pool_client = false
    allowed_oauth_flows                  = []
  }
}

# Cấu hình CloudFront
cloudfront_default_cache_behavior = {
  target_origin_id       = "frontend_s3_origin"
  viewer_protocol_policy = "redirect-to-https"
  allowed_methods        = ["GET", "HEAD"]
  cached_methods         = ["GET", "HEAD"]
}

