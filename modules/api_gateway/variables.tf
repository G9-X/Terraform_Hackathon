variable "project_name" {
  description = "Tên dự án dùng để gán Name tag và định danh tài nguyên"
  type        = string
}

variable "stage_name" {
  description = "Tên của API Gateway Stage (ví dụ: $default, dev, prod)"
  type        = string
  default     = "$default"
}

variable "cognito_user_pool_endpoint" {
  description = "Endpoint của Cognito User Pool dùng để xác thực JWT (để trống nếu không sử dụng Cognito)"
  type        = string
  default     = null
}

variable "cognito_client_ids" {
  description = "Danh sách Client IDs được phép xác thực thông qua API Gateway JWT"
  type        = list(string)
  default     = []
}

variable "routes" {
  description = "Bản đồ các routes cấu hình cho API Gateway. Key là định danh duy nhất (ví dụ: get_users, create_order)."
  type = map(object({
    route_key         = string # Ví dụ: "GET /users", "POST /orders", "ANY /"
    lambda_key        = string # Khóa của Lambda trong bản đồ lambda_arns (ví dụ: "chat", "upload")
    enable_authorizer = optional(bool, false)
  }))
  default = {}
}

variable "lambda_arns" {
  description = "Bản đồ các ARN của Lambda (để ánh xạ động vào routes theo lambda_key)"
  type        = map(string)
  default     = {}
}

variable "enable_cognito_authorizer" {
  description = "Bật/tắt Cognito JWT Authorizer cho API Gateway"
  type        = bool
  default     = false
}
