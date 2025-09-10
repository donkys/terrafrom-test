#!/bin/bash

# ===== BackRoom EC2 User Data Script =====
# This script runs on EC2 instance startup to install Docker, 
# pull images, setup environment, and start the application

set -e

# Variables from Terraform
DB_HOST="${db_host}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
JWT_SECRET="${jwt_secret}"
BACKEND_IMAGE="${backend_image}"
FRONTEND_IMAGE="${frontend_image}"

# Logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting BackRoom deployment at $(date)"

# Update system
echo "Updating system packages..."
yum update -y

# Install Docker
echo "Installing Docker..."
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install MySQL client for database operations
echo "Installing MySQL client..."
yum install -y mysql

# Install AWS CLI v2
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
yum install -y unzip
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/

# Create application directory
echo "Creating application directories..."
mkdir -p /home/ec2-user/backroom
mkdir -p /home/ec2-user/backroom/logs
cd /home/ec2-user/backroom

# Create environment file
echo "Creating environment configuration..."
cat > .env << EOF
# Database Configuration
DB_HOST=${db_host}
DB_PORT=3306
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASS=${db_password}

# AWS Configuration  
AWS_REGION=${aws_region}
AWS_S3_BUCKET=${s3_bucket}

# S3 Configuration
S3_MODE=aws
S3_REGION=${aws_region}
S3_BUCKET=${s3_bucket}

# Application Configuration
NODE_ENV=production
BACKEND_PORT=8080
JWT_ACCESS_SECRET=${jwt_secret}
JWT_REFRESH_SECRET=${jwt_secret}
FRONTEND_ORIGIN=http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Email Configuration (placeholder)
EMAIL_FROM=noreply@backroom.dev
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587

# Frontend Configuration
FRONTEND_URL=http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
API_BASE_URL=http://backend:8080
EOF

# Create docker-compose file for production
echo "Creating Docker Compose configuration..."
cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  backend:
    image: ${backend_image}
    ports:
      - "8080:8080"
    volumes:
      - ./logs:/app/logs
    env_file:
      - .env
    networks:
      - backroom-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    image: ${frontend_image}
    ports:
      - "80:80"
    env_file:
      - .env
    networks:
      - backroom-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    depends_on:
      backend:
        condition: service_healthy

networks:
  backroom-network:
    driver: bridge
EOF

# Wait for database to be ready
echo "Waiting for database to be ready..."
until mysql -h${db_host} -u${db_user} -p${db_password} -e "SELECT 1" >/dev/null 2>&1; do
  echo "Waiting for database connection..."
  sleep 10
done

# Create database if it doesn't exist
echo "Creating database if not exists..."
mysql -h${db_host} -u${db_user} -p${db_password} -e "CREATE DATABASE IF NOT EXISTS ${db_name};"

# Download and run database migrations
echo "Setting up database schema..."

# Download SQL initialization file from S3
echo "Downloading database initialization file from S3..."
aws s3 cp s3://${s3_bucket}/database/V1__init.sql /tmp/V1__init.sql

# Execute the SQL file
echo "Executing database initialization script..."
mysql -h${db_host} -u${db_user} -p${db_password} ${db_name} < /tmp/V1__init.sql

echo "Database setup completed."

# Set proper permissions
chown -R ec2-user:ec2-user /home/ec2-user/backroom

# Start the application
echo "Starting BackRoom application..."
cd /home/ec2-user/backroom

# Pull Docker images
echo "Pulling Docker images..."
docker pull ${backend_image}
docker pull ${frontend_image}

# Start services
echo "Starting Docker services..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 30

# Check if services are running
docker-compose ps

echo "Deployment completed at $(date)"
echo "Application should be available at:"
echo "Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Backend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"

# Create status check script
cat > /home/ec2-user/check-status.sh << 'EOF'
#!/bin/bash
echo "=== BackRoom Application Status ==="
echo "Date: $(date)"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "Docker containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Application URLs:"
echo "Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Backend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
EOF

chmod +x /home/ec2-user/check-status.sh
chown ec2-user:ec2-user /home/ec2-user/check-status.sh

echo "Setup completed successfully!"
echo "Use 'sudo /home/ec2-user/check-status.sh' to check application status"
