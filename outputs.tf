# ===== Output Values =====

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.backroom_vpc.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private_subnets[*].id
}

# ===== Database Outputs =====
output "database_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.backroom_db.endpoint
  sensitive   = true
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.backroom_db.db_name
}

output "database_username" {
  description = "Database username"
  value       = aws_db_instance.backroom_db.username
  sensitive   = true
}

# ===== S3 Outputs =====
output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.backroom_storage.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.backroom_storage.arn
}

# ===== EC2 Outputs =====
output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.backroom_server.id
}

output "ec2_public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.backroom_server.public_ip
}

output "ec2_public_dns" {
  description = "EC2 public DNS"
  value       = aws_instance.backroom_server.public_dns
}

# ===== Application URLs =====
output "frontend_url" {
  description = "Frontend application URL"
  value       = "http://${aws_instance.backroom_server.public_ip}"
}

output "backend_url" {
  description = "Backend API URL"
  value       = "http://${aws_instance.backroom_server.public_ip}:8080"
}

# ===== SSH Connection =====
output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/${var.existing_key_name}.pem ec2-user@${aws_instance.backroom_server.public_ip}"
}

# ===== Environment File =====
output "env_file_content" {
  description = "Environment variables for .env file"
  value = <<-EOT
# Database Configuration
DB_HOST=${aws_db_instance.backroom_db.endpoint}
DB_PORT=3306
DB_NAME=${aws_db_instance.backroom_db.db_name}
DB_USER=${aws_db_instance.backroom_db.username}
DB_PASSWORD=${var.database_password}

# AWS Configuration
AWS_REGION=${var.aws_region}
AWS_S3_BUCKET=${aws_s3_bucket.backroom_storage.bucket}

# Application Configuration
NODE_ENV=production
JWT_SECRET=${var.jwt_secret}
API_PORT=8080
CORS_ORIGIN=http://${aws_instance.backroom_server.public_ip}

# Frontend Configuration
FRONTEND_URL=http://${aws_instance.backroom_server.public_ip}
API_BASE_URL=http://backend:8080
EOT
  sensitive = true
}
