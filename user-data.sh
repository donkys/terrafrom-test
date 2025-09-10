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
DB_HOST=${db_host}
DB_PORT=3306
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}

# AWS Configuration  
AWS_REGION=${aws_region}
AWS_S3_BUCKET=${s3_bucket}

# Application Configuration
NODE_ENV=production
JWT_SECRET=${jwt_secret}
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

# Copy the SQL initialization file to the instance
cat > /tmp/V1__init.sql << 'EOSQL'
-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               8.0.39 - MySQL Community Server - GPL
-- Server OS:                    Win64
-- HeidiSQL Version:             12.11.0.7065
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- Dumping structure for table appdb.audit_logs
CREATE TABLE IF NOT EXISTS `audit_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `actor_id` bigint DEFAULT NULL,
  `action` varchar(64) COLLATE utf8mb4_general_ci NOT NULL,
  `target_type` varchar(64) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `target_id` bigint DEFAULT NULL,
  `ip_address` varchar(64) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payload_json` json DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_action_time` (`action`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=158 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping structure for table appdb.feature_flags
CREATE TABLE IF NOT EXISTS `feature_flags` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `flag_key` varchar(100) COLLATE utf8mb4_general_ci NOT NULL,
  `is_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `description` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `flag_key` (`flag_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping structure for table appdb.files
CREATE TABLE IF NOT EXISTS `files` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `owner_id` bigint NOT NULL,
  `s3_key` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `cover_key` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `mime_type` varchar(128) COLLATE utf8mb4_general_ci NOT NULL,
  `size_bytes` bigint NOT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `name` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_owner` (`owner_id`,`is_deleted`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping structure for table appdb.locales
CREATE TABLE IF NOT EXISTS `locales` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(10) COLLATE utf8mb4_general_ci NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_general_ci NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table appdb.locales: ~2 rows (approximately)
INSERT INTO `locales` (`id`, `code`, `name`, `is_active`, `created_at`, `updated_at`) VALUES
	(11, 'th', 'ไทย', 1, '2025-09-08 19:14:39', '2025-09-08 19:14:39'),
	(12, 'en', 'English', 1, '2025-09-08 19:14:39', '2025-09-08 19:14:39');

-- Dumping structure for table appdb.password_resets
CREATE TABLE IF NOT EXISTS `password_resets` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `token_hash` char(64) COLLATE utf8mb4_general_ci NOT NULL,
  `expires_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_token` (`user_id`,`token_hash`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping structure for table appdb.refresh_tokens
CREATE TABLE IF NOT EXISTS `refresh_tokens` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `token_hash` char(64) COLLATE utf8mb4_general_ci NOT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `ip_address` varchar(64) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_exp` (`user_id`,`expires_at`),
  KEY `idx_user_rev` (`user_id`,`revoked_at`)
) ENGINE=InnoDB AUTO_INCREMENT=174 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping structure for table appdb.translations
CREATE TABLE IF NOT EXISTS `translations` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `namespace` varchar(64) COLLATE utf8mb4_general_ci NOT NULL,
  `t_key` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `locale_code` varchar(10) COLLATE utf8mb4_general_ci NOT NULL,
  `t_value` text COLLATE utf8mb4_general_ci NOT NULL,
  `updated_by` bigint DEFAULT NULL,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_trans` (`namespace`,`t_key`,`locale_code`),
  KEY `idx_ns_key` (`namespace`,`t_key`)
) ENGINE=InnoDB AUTO_INCREMENT=610 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping structure for table appdb.users
CREATE TABLE IF NOT EXISTS `users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `email` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `password_hash` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `username` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `display_name` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `avatar_key` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `banner_key` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `locale_pref` varchar(10) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `role` enum('user','admin') COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'user',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
EOSQL

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
