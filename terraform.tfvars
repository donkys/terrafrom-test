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
jwt_secret = "BackroomSecretJWT2025!TestingOnly#SuperLongSecretKey"  # Random for testing

# Docker Images (successfully built and pushed to Docker Hub)
backend_docker_image  = "porapipatkae/backroom-backend:v1.0.0"
frontend_docker_image = "porapipatkae/backroom-frontend:v1.0.0"

# SSH Key - Testing Key (REPLACE WITH REAL KEY FOR PRODUCTION)
public_key_content = <<-EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDVkzNBGLrjNXXjJ5M3FsE8FnhJe9zP4K2M1V7Q8R6YwX9B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2W3X4Y5Z6A7B8C9D0E1F2G3H4I5J6K7L8M9N0O1P2Q3R4S5T6U7V8W9X0Y1Z2A3B4C5D6E7F8G9H0I1J2K3L4M5N6O7P8Q9R0S1T2U3V4W5X6Y7Z8A9B0C1D2E3F4G5H6I7J8K9L0M1N2O3P4Q5R6S7T8U9V0W1X2Y3Z4A5B6C7D8E9F0G1H2I3J4K5L6M7N8O9P0Q1R2S3T4U5V6W7X8Y9Z0A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2W3X4Y5Z6A7B8C9D0E1F2G3H4I5J6K7L8M9N0O1P2Q3R4S5T6U7V8W9X0Y1Z2A3B4C5D6E7F8G9H0I1J2K3L4M5N6O7P8Q9R0S1T2U3V4W5X6Y7Z8A9B0C1D2E3F4G5H6I7J8K9L0M1N2O3P4Q5R6S7T8U9V0W1X2Y3Z4A5B6C7D8E9F0G1H2I3J4K5L6M7N8O9P0Q1R2S3T4U5V6W7X8Y9Z0A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2W3X4Y5Z6A7B8C9D0E1F2G3H4I5J6K7L8M9N0O1P2Q3R4S5T6U7V8W9X0Y1Z2A3B4C5D6E7F8G9H0I1J2K3L4M5 testing-key@backroom-terraform
EOF
