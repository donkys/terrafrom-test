# ===== Input Variables =====

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "backroom"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ===== Network Variables =====
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to EC2"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Change this to your IP for security
}

# ===== Database Variables =====
variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "backroom_db"
}

variable "database_username" {
  description = "Database username"
  type        = string
  default     = "backroom_user"
}

variable "database_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "RDS maximum allocated storage in GB"
  type        = number
  default     = 100
}

# ===== EC2 Variables =====
variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "public_key_content" {
  description = "Public key content for EC2 access"
  type        = string
}

# ===== Application Variables =====
variable "jwt_secret" {
  description = "JWT secret for application"
  type        = string
  sensitive   = true
}

variable "backend_docker_image" {
  description = "Backend Docker image name"
  type        = string
  default     = "backroom-backend:latest"
}

variable "frontend_docker_image" {
  description = "Frontend Docker image name"
  type        = string
  default     = "backroom-frontend:latest"
}
