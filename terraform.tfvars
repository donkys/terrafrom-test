# ===== Development Environment =====
aws_region    = "ap-southeast-1"  # Singapore region
project_name  = "backroom"
environment   = "dev"

# Network Security - Change to your IP for better security
allowed_ssh_cidrs = ["0.0.0.0/0"]  # WARNING: Change this to your IP

# Database Configuration
database_name     = "backroom_dev"
database_username = "backroom_user"
database_password = "BackroomDev2025!"  # Change this to a strong password

# EC2 Configuration
ec2_instance_type = "t3.small"  # Suitable for development

# RDS Configuration
rds_instance_class      = "db.t3.micro"  # Free tier eligible
rds_allocated_storage   = 20
rds_max_allocated_storage = 100

# Application Configuration
jwt_secret = "your-super-secret-jwt-key-for-development-change-this"  # Change this

# Docker Images (successfully built and pushed to Docker Hub)
backend_docker_image  = "porapipatkae/backroom-backend:v1.0.0"
frontend_docker_image = "porapipatkae/backroom-frontend:v1.0.0"

# SSH Key - Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/backroom-key
# Then paste the content of ~/.ssh/backroom-key.pub here
public_key_content = <<-EOF
# REPLACE THIS WITH YOUR ACTUAL PUBLIC KEY CONTENT
# Example: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... your-email@example.com
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDxxxYOUR_PUBLIC_KEY_HERExxx your-email@example.com
EOF
