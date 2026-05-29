# 1. Gọi module S3 để tạo 2 bucket: 1 cho Frontend và 1 cho Dữ liệu CSV
module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  buckets = {
    "frontend" = {}
    "csv-data" = {}
  }
}

# 2. Gọi module VPC để xây dựng hạ tầng mạng riêng tư bảo mật và tái sử dụng cao
module "vpc" {
  source = "../../modules/vpc"

  aws_region         = var.aws_region
  project_name       = var.project_name
  availability_zones = var.availability_zones
  vpc_cidr           = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  vpc_endpoints      = var.vpc_endpoints
}

# 3. Gọi module Security Group để khởi tạo nhóm bảo mật cho Lambda (IPv4 only)
module "lambda_sg" {
  source = "../../modules/security_group"

  project_name   = var.project_name
  vpc_id         = module.vpc.vpc_id
  sg_name_suffix = "lambda"
  description    = "Security group for application Lambda functions"
  egress_rules   = var.lambda_sg_egress_rules
}

locals {
  dynamic_lambdas = {
    for k, v in var.lambdas : k => merge(v, {
      environment_variables = merge(v.environment_variables, {
        "STORAGE_BUCKET"             = module.s3.bucket_ids["csv-data"]
        "USERSTORE_BACKEND"          = "postgres"
        "USERSTORE_POSTGRES_URL"     = "postgresql://dbadmin:${module.rds.db_password}@${module.rds.rds_db_endpoint}/${module.rds.rds_db_name}"
        "DISABLE_CLOUDWATCH_METRICS" = "true"
      })
      iam_policy_statements = concat(v.iam_policy_statements, [
        {
          effect    = "Allow"
          actions   = ["s3:PutObject", "s3:GetObject"]
          resources = ["${module.s3.bucket_arns["csv-data"]}/*", module.s3.bucket_arns["csv-data"]]
        }
      ])
    })
  }
}

# 4. Gọi module Lambda để khởi tạo các hàm Lambda trong VPC một cách sạch sẽ
module "lambda" {
  source = "../../modules/lambda"

  project_name           = var.project_name
  vpc_subnet_ids         = module.vpc.app_subnet_ids
  vpc_security_group_ids = [module.lambda_sg.security_group_id]
  lambdas                = local.dynamic_lambdas
}

# 5. Gọi module Cognito để quản lý định danh người dùng
module "cognito" {
  source = "../../modules/cognito"

  project_name = var.project_name
  clients      = var.cognito_clients
}

# 6. Gọi module API Gateway để tạo HTTP API định tuyến tới các Lambda một cách sạch sẽ
module "api_gateway" {
  source = "../../modules/api_gateway"

  project_name               = var.project_name
  stage_name                 = "$default"
  lambda_arns                = module.lambda.lambda_arns
  routes                     = var.api_gateway_routes
  enable_cognito_authorizer  = true
  cognito_user_pool_endpoint = module.cognito.user_pool_endpoint
  cognito_client_ids         = values(module.cognito.client_ids)
}

# 7. Gọi module CloudFront để phân phối Frontend qua giao thức HTTPS bảo mật
module "cloudfront" {
  source = "../../modules/cloudfront"

  project_name = var.project_name
  s3_origins = {
    "frontend_s3_origin" = {
      domain_name = module.s3.bucket_regional_domain_names["frontend"]
      bucket_id   = module.s3.bucket_ids["frontend"]
      bucket_arn  = module.s3.bucket_arns["frontend"]
    }
  }
  default_cache_behavior = var.cloudfront_default_cache_behavior
}

# 8. Gọi module RDS để khởi tạo cơ sở dữ liệu Single AZ tiết kiệm chi phí
module "rds" {
  source = "../../modules/rds"

  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  rds_subnet_ids        = module.vpc.rds_subnet_ids
  db_allocated_storage  = var.rds_db_allocated_storage
  db_instance_class     = var.rds_db_instance_class
  db_name               = var.rds_db_name
  app_security_group_id = module.lambda_sg.security_group_id
  multi_az              = var.rds_multi_az
}

# 9. Khởi tạo bảng DynamoDB cho Chat Sessions (On-Demand & TTL)
resource "aws_dynamodb_table" "sessions" {
  name         = "${var.project_name}-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Project     = "W7Capstone"
    Team        = "G9"
    Owner       = "G9"
    Environment = "hackathon"
  }
}


