output "rds_db_endpoint" {
  description = "Connection endpoint của RDS database (đã bao gồm port)"
  value       = aws_db_instance.this.endpoint
}

output "rds_db_address" {
  description = "Địa chỉ hostname của RDS database (không bao gồm port)"
  value       = aws_db_instance.this.address
}

output "rds_db_port" {
  description = "Port kết nối tới RDS database"
  value       = aws_db_instance.this.port
}

output "rds_db_name" {
  description = "Tên database trong RDS"
  value       = aws_db_instance.this.db_name
}

output "db_password" {
  description = "Mật khẩu database"
  value       = random_password.db_password.result
  sensitive   = true
}
