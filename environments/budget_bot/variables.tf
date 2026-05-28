variable "aws_region" {
  description = "Vùng AWS dùng để triển khai tài nguyên (ví dụ: us-east-1)"
  type        = string
}

variable "availability_zones" {
  description = "Danh sách các Availability Zone dùng để triển khai (ví dụ: ['us-east-1a', 'us-east-1b'])"
  type        = list(string)
}

variable "project_name" {
  description = "Tên dự án dùng để gán nhãn và làm tiền tố cho tài nguyên"
  type        = string
}

variable "vpc_cidr" {
  description = "Dải IP của VPC"
  type        = string
}

variable "public_subnets" {
  description = "Bản đồ cấu hình các subnet public"
  type = map(object({
    cidr_block        = string
    availability_zone = string
    type              = string # "alb" hoặc "nat"
  }))
  default = {}
}

variable "private_subnets" {
  description = "Bản đồ cấu hình các subnet private"
  type = map(object({
    cidr_block           = string
    availability_zone    = string
    type                 = string           # "app" hoặc "db"
    nat_gateway_route_to = optional(string) # Khóa của public subnet chứa NAT Gateway tương ứng, có thể null.
  }))
  default = {}
}

variable "vpc_endpoints" {
  description = "Bản đồ các VPC Endpoints cần tạo"
  type = map(object({
    service_name        = string
    vpc_endpoint_type   = string
    private_dns_enabled = optional(bool, false)
    subnet_names        = optional(list(string), [])
  }))
  default = {}
}

variable "lambda_sg_egress_rules" {
  description = "Danh sách các luật egress cho Lambda Security Group (IPv4 outbound)"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
}

variable "lambdas" {
  description = "Bản đồ cấu hình chi tiết cho các hàm Lambda cần tạo"
  type = map(object({
    handler                = string
    runtime                = string
    memory_size            = optional(number, 128)
    timeout                = optional(number, 3)
    environment_variables  = optional(map(string), {})
    vpc_subnet_ids         = optional(list(string), null)
    vpc_security_group_ids = optional(list(string), null)
    s3_bucket              = optional(string, null)
    s3_key                 = optional(string, null)
    source_dir             = optional(string, null)
    local_zip_path         = optional(string, null)
    iam_policy_statements = optional(list(object({
      effect    = string
      actions   = list(string)
      resources = list(string)
    })), [])
  }))
}

variable "api_gateway_routes" {
  description = "Bản đồ cấu hình các routes cho API Gateway"
  type = map(object({
    route_key  = string
    lambda_key = string
  }))
}

variable "rds_db_allocated_storage" {
  description = "Dung lượng storage cấp phát cho RDS (GB)"
  type        = number
}

variable "rds_db_instance_class" {
  description = "Instance class cho database (vd: db.t3.micro)"
  type        = string
}

variable "rds_db_name" {
  description = "Tên database khởi tạo"
  type        = string
}

variable "rds_multi_az" {
  description = "Bật/Tắt chế độ Multi-AZ cho RDS"
  type        = bool
}

variable "cognito_clients" {
  description = "Bản đồ cấu hình các Cognito User Pool Clients cần tạo"
  type = map(object({
    generate_secret     = optional(bool, false)
    explicit_auth_flows = optional(list(string), ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"])
  }))
  default = {}
}

variable "cloudfront_s3_origins" {
  description = "Bản đồ các S3 origins cho CloudFront"
  type = map(object({
    domain_name = string
    bucket_id   = string
    bucket_arn  = string
  }))
  default = {}
}

variable "cloudfront_default_cache_behavior" {
  description = "Cấu hình cache behavior mặc định cho CloudFront"
  type = object({
    target_origin_id       = string
    viewer_protocol_policy = optional(string, "redirect-to-https")
    allowed_methods        = optional(list(string), ["GET", "HEAD", "OPTIONS"])
    cached_methods         = optional(list(string), ["GET", "HEAD"])
  })
}
