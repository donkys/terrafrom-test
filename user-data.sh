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

# Create application directory
echo "Creating application directories..."
mkdir -p /home/ec2-user/backroom
mkdir -p /home/ec2-user/backroom/logs
cd /home/ec2-user/backroom

# Create environment file
echo "Creating environment configuration..."
cat > .env << EOF
# Database Configuration
DB_HOST=${DB_HOST}
DB_PORT=3306
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

# AWS Configuration  
AWS_REGION=${AWS_REGION}
AWS_S3_BUCKET=${S3_BUCKET}

# Application Configuration
NODE_ENV=production
JWT_SECRET=${JWT_SECRET}
API_PORT=8080
CORS_ORIGIN=http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

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
    image: ${BACKEND_IMAGE}
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
    image: ${FRONTEND_IMAGE}
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
until mysql -h${DB_HOST} -u${DB_USER} -p${DB_PASSWORD} -e "SELECT 1" >/dev/null 2>&1; do
  echo "Waiting for database connection..."
  sleep 10
done

# Create database if it doesn't exist
echo "Creating database if not exists..."
mysql -h${DB_HOST} -u${DB_USER} -p${DB_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"

# Download and run database migrations
echo "Setting up database schema..."
# Note: You'll need to upload your SQL files to S3 or include them in the Docker image
# For now, we'll create a basic structure

mysql -h${DB_HOST} -u${DB_USER} -p${DB_PASSWORD} ${DB_NAME} << 'EOSQL'
-- Basic user table (modify according to your V1__init.sql)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Basic files table
CREATE TABLE IF NOT EXISTS files (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    filename VARCHAR(255) NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    file_size BIGINT,
    mime_type VARCHAR(255),
    s3_key VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_files_user_id ON files(user_id);
EOSQL

echo "Database setup completed."

# Build/Pull Docker images
echo "Pulling Docker images..."
# For now, we'll use a placeholder. In production, you'd pull from ECR or Docker Hub
# docker pull ${BACKEND_IMAGE}
# docker pull ${FRONTEND_IMAGE}

# For development, we'll build images locally
# You should upload your Docker images to a registry first
echo "Note: Docker images should be available in a registry (ECR/Docker Hub)"

# Set proper permissions
chown -R ec2-user:ec2-user /home/ec2-user/backroom

# Start the application
echo "Starting BackRoom application..."
cd /home/ec2-user/backroom

# Start services
# docker-compose up -d

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
