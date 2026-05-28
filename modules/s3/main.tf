resource "random_string" "suffix" {
  for_each = var.buckets
  length   = 6
  special  = false
  upper    = false
}

resource "aws_s3_bucket" "this" {
  for_each = var.buckets

  bucket        = "${var.project_name}-${each.key}-${random_string.suffix[each.key].result}"
  force_destroy = true # Hỗ trợ hủy nhanh tài nguyên khi dọn dẹp môi trường

  tags = {
    Name = "${var.project_name}-${each.key}"
  }
}

# Cấu hình mã hóa dữ liệu mặc định bằng SSE-S3 (không phát sinh thêm chi phí)
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = var.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Chặn hoàn toàn truy cập public để bảo mật tuyệt đối dữ liệu
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = var.buckets

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
