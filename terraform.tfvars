# ===== Development Environment =====
aws_region    = "ap-southeast-1"  # Singapore region
project_name  = "backroom"
site_name     = "earthsite"
environment   = "dev"

# Network Security - Change to your IP for better security
allowed_ssh_cidrs = ["0.0.0.0/0"]  # WARNING: Change this to your IP

# Database Configuration
database_name     = "backroom_dev"
database_username = "backroom_user"
database_password = "BackroomDev2025!"  # Change this to a strong password

# EC2 Configuration
ec2_instance_type = "t3.small"  # Suitable for development
ec2_root_volume_size = 8
ec2_root_volume_type = "gp3"
ec2_root_volume_encrypted = true

# RDS Configuration
rds_instance_class      = "db.t3.micro"  # Free tier eligible
rds_allocated_storage   = 20
rds_max_allocated_storage = 100

# Application Configuration
jwt_secret = "BackroomSecretJWT2025!TestingOnly#SuperLongSecretKey"  # Random for testing

# Docker Images (updated with site name support)
backend_docker_image  = "porapipatkae/backroom-backend:v1.1.0"
frontend_docker_image = "porapipatkae/backroom-frontend:v1.1.0"

# SSH Key - Using existing key pair
existing_key_name = "BackRoom-keypair-terraform"

# Note: public_key_content not needed when using existing key pair
public_key_content = ""
