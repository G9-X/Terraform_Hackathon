variable "project_name" {
  description = "Tên dự án dùng để gán Name tag và định danh tài nguyên"
  type        = string
}

variable "allow_self_sign_up" {
  description = "Cho phép người dùng tự đăng ký tài khoản"
  type        = bool
  default     = true
}

variable "password_min_length" {
  description = "Độ dài tối thiểu của mật khẩu"
  type        = number
  default     = 8
}

variable "password_require_lowercase" {
  description = "Yêu cầu mật khẩu có ít nhất một ký tự viết thường"
  type        = bool
  default     = true
}

variable "password_require_uppercase" {
  description = "Yêu cầu mật khẩu có ít nhất một ký tự viết hoa"
  type        = bool
  default     = true
}

variable "password_require_numbers" {
  description = "Yêu cầu mật khẩu có ít nhất một ký số"
  type        = bool
  default     = true
}

variable "password_require_symbols" {
  description = "Yêu cầu mật khẩu có ít nhất một ký tự đặc biệt"
  type        = bool
  default     = true
}

variable "auto_verified_attributes" {
  description = "Danh sách các thuộc tính tự động xác thực khi đăng ký (ví dụ: email, phone_number)"
  type        = list(string)
  default     = ["email"]
}

variable "email_verification_subject" {
  description = "Tiêu đề email xác thực đăng ký"
  type        = string
  default     = "Mã xác thực tài khoản của bạn"
}

variable "email_verification_message" {
  description = "Nội dung email xác thực đăng ký. Phải chứa tham số {####} để hiển thị mã xác thực."
  type        = string
  default     = "Cảm ơn bạn đã đăng ký. Mã xác thực của bạn là {####}."
}

variable "domain_prefix" {
  description = "Tiền tố tên miền được cấp bởi Cognito cho Hosted UI (ví dụ: my-app-auth). Để null nếu không cần dùng Hosted UI."
  type        = string
  default     = null
}

variable "clients" {
  description = "Bản đồ cấu hình các Cognito User Pool Clients cần tạo. Key là hậu tố định danh của client."
  type = map(object({
    generate_secret                      = optional(bool, false)
    explicit_auth_flows                  = optional(list(string), ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"])
    supported_identity_providers         = optional(list(string), ["COGNITO"])
    callback_urls                        = optional(list(string), [])
    logout_urls                          = optional(list(string), [])
    allowed_oauth_flows                  = optional(list(string), [])
    allowed_oauth_scopes                 = optional(list(string), [])
    allowed_oauth_flows_user_pool_client = optional(bool, false)
  }))
  default = {}
}
