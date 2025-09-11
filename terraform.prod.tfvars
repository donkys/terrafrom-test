# ===== Production Environment =====
aws_region    = "us-east-1"
project_name  = "backroom"
site_name     = "prod-site"
environment   = "prod"

# Network Security - Restrict to your office/home IP
allowed_ssh_cidrs = ["YOUR_IP_ADDRESS/32"]  # Replace with your actual IP

# Database Configuration
database_name     = "backroom_prod"
database_username = "backroom_admin"
database_password = "CHANGE_THIS_TO_STRONG_PASSWORD"  # Use AWS Secrets Manager in real prod

# EC2 Configuration
ec2_instance_type = "t3.medium"  # More resources for production
ec2_root_volume_size = 50
ec2_root_volume_type = "gp3"
ec2_root_volume_encrypted = true

# RDS Configuration
rds_instance_class        = "db.t3.small"    # Better performance for production
rds_allocated_storage     = 50
rds_max_allocated_storage = 500

# Application Configuration
jwt_secret = "CHANGE_THIS_TO_VERY_STRONG_SECRET_FOR_PRODUCTION"  # Use AWS Secrets Manager

# Docker Images (should be pushed to ECR or Docker Hub)
backend_docker_image  = "your-registry/backroom-backend:v1.0.0"
frontend_docker_image = "your-registry/backroom-frontend:v1.0.0"

# SSH Key - Production key (different from dev)
public_key_content = <<-EOF
# REPLACE WITH PRODUCTION PUBLIC KEY
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDxxxPRODUCTION_KEY_HERExxx admin@company.com
EOF
