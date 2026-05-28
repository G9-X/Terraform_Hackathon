locals {
  # Chỉ tạo OAC nếu có S3 origins
  has_s3_origin = length(var.s3_origins) > 0
}

# 1. Khởi tạo Origin Access Control (OAC) cho các S3 origins
resource "aws_cloudfront_origin_access_control" "this" {
  count                             = local.has_s3_origin ? 1 : 0
  name                              = "${var.project_name}-oac"
  description                       = "Origin Access Control cho S3 bucket tĩnh của ${var.project_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 2. Khởi tạo tài nguyên CloudFront Distribution
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront Distribution cho dự án ${var.project_name}"
  default_root_object = "index.html"
  aliases             = var.aliases

  # Cấu hình S3 Origins (sử dụng OAC mới nhất)
  dynamic "origin" {
    for_each = var.s3_origins
    content {
      domain_name              = origin.value.domain_name
      origin_id                = origin.key
      origin_access_control_id = length(aws_cloudfront_origin_access_control.this) > 0 ? aws_cloudfront_origin_access_control.this[0].id : null
    }
  }

  # Cấu hình Custom Origins (ALB/API Gateway)
  dynamic "origin" {
    for_each = var.custom_origins
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.key

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = origin.value.origin_protocol_policy
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

# 1.5 CloudFront Function để sửa lỗi định tuyến Next.js App Router (Static Export)
resource "aws_cloudfront_function" "uri_rewrite" {
  name    = "${var.project_name}-uri-rewrite"
  runtime = "cloudfront-js-1.0"
  comment = "Thêm index.html vào URI cho thư mục con (Next.js trailingSlash)"
  publish = true
  code    = <<-EOT
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // Nếu request yêu cầu Next.js payload (_next/data) thì giữ nguyên
    if (uri.startsWith('/_next/')) {
        return request;
    }
    
    // Thêm index.html nếu URI kết thúc bằng /
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    } 
    // Nếu URI không chứa đuôi mở rộng (ví dụ .css, .js)
    else if (!uri.includes('.')) {
        request.uri += '/index.html';
    }

    return request;
}
  EOT
}

  # Cache Behavior Mặc định
  default_cache_behavior {
    target_origin_id       = var.default_cache_behavior.target_origin_id
    viewer_protocol_policy = var.default_cache_behavior.viewer_protocol_policy
    allowed_methods        = var.default_cache_behavior.allowed_methods
    cached_methods         = var.default_cache_behavior.cached_methods
    compress               = var.default_cache_behavior.compress
    default_ttl            = var.default_cache_behavior.default_ttl
    min_ttl                = var.default_cache_behavior.min_ttl
    max_ttl                = var.default_cache_behavior.max_ttl

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.uri_rewrite.arn
    }
  }

  # Cache Behaviors có thứ tự ưu tiên (Ví dụ định tuyến /api/* tới ALB)
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      allowed_methods        = ordered_cache_behavior.value.allowed_methods
      cached_methods         = ordered_cache_behavior.value.cached_methods
      compress               = ordered_cache_behavior.value.compress
      default_ttl            = ordered_cache_behavior.value.default_ttl
      min_ttl                = ordered_cache_behavior.value.min_ttl
      max_ttl                = ordered_cache_behavior.value.max_ttl

      forwarded_values {
        query_string = ordered_cache_behavior.value.query_string
        headers      = ordered_cache_behavior.value.headers

        cookies {
          forward = ordered_cache_behavior.value.cookies_forward
        }
      }
    }
  }

  # Cấu hình phản hồi lỗi tùy chỉnh (Single Page Application routing)
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # Hạn chế địa lý (Mặc định không giới hạn quốc gia)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Chứng chỉ SSL/TLS
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null ? true : false
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != null ? "TLSv1.2_2021" : null
  }

  lifecycle {
    ignore_changes = [
      aliases,
      viewer_certificate
    ]
  }

  tags = {
    Name = "${var.project_name}-cloudfront"
  }
}

# 4. Tự động đính kèm S3 Bucket Policy cho các S3 origins, chỉ cho phép Cloudfront truy cập
resource "aws_s3_bucket_policy" "allow_cloudfront" {
  for_each = var.s3_origins

  bucket = each.value.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${each.value.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  })
}
