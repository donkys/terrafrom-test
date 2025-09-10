# ===== BackRoom Terraform Deployment Guide =====

## 📋 Prerequisites

1. **AWS CLI installed and configured**
   ```bash
   aws configure
   ```

2. **Terraform installed** (version >= 1.0)
   ```bash
   # Download from: https://www.terraform.io/downloads.html
   terraform --version
   ```

3. **SSH Key pair generated**
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/backroom-key
   ```

4. **Docker images built and pushed to registry**
   ```bash
   # Build images
   cd BackRoom-back
   docker build -f Dockerfile.simple -t backroom-backend:latest .
   
   cd ../BackRoom-front  
   docker build -f Dockerfile.production -t backroom-frontend:latest .
   
   # Tag and push to registry (ECR/Docker Hub)
   # docker tag backroom-backend:latest your-registry/backroom-backend:latest
   # docker push your-registry/backroom-backend:latest
   ```

## 🚀 Deployment Steps

### 1. Configure Variables
Edit `terraform.tfvars` or `terraform.prod.tfvars`:

```hcl
# Required changes:
database_password = "YourStrongPassword123!"
jwt_secret = "your-super-secret-jwt-key"
public_key_content = "ssh-rsa AAAAB3... your-key-content"
allowed_ssh_cidrs = ["YOUR_IP/32"]  # Your public IP
```

### 2. Initialize Terraform
```bash
cd terraform
terraform init
```

### 3. Plan Deployment
```bash
# Development
terraform plan -var-file="terraform.tfvars"

# Production  
terraform plan -var-file="terraform.prod.tfvars"
```

### 4. Deploy Infrastructure
```bash
# Development
terraform apply -var-file="terraform.tfvars"

# Production
terraform apply -var-file="terraform.prod.tfvars"
```

### 5. Get Output Information
```bash
terraform output
```

## 📊 What Gets Created

### Infrastructure:
- **VPC** with public/private subnets
- **RDS MySQL** database (private subnet)
- **S3 Bucket** for file storage
- **EC2 Instance** with Docker and Docker Compose
- **Security Groups** for web and database access
- **IAM Role** for S3 access from EC2

### Applications:
- **Backend** (Express.js API) on port 8080
- **Frontend** (React + nginx) on port 80
- **Database** pre-configured with initial schema
- **Environment** variables auto-generated

## 🔍 Accessing Your Application

After deployment:

```bash
# Get application URLs
terraform output frontend_url
terraform output backend_url

# SSH to server
terraform output ssh_connection
```

## 📝 Post-Deployment Tasks

### 1. Upload Database Migrations
```bash
# SSH to server
ssh -i ~/.ssh/backroom-key ec2-user@YOUR_EC2_IP

# Upload your SQL files
# scp -i ~/.ssh/backroom-key BackRoom-back/flyway/sql/*.sql ec2-user@YOUR_EC2_IP:/home/ec2-user/
```

### 2. Start Application (if not auto-started)
```bash
# On EC2 server
cd /home/ec2-user/backroom
docker-compose up -d
```

### 3. Check Status
```bash
# On EC2 server
./check-status.sh
docker-compose logs
```

## 🔧 Environment Variables

The following variables are automatically configured:

```bash
# Database
DB_HOST=your-rds-endpoint
DB_NAME=backroom_db  
DB_USER=backroom_user
DB_PASSWORD=your-password

# AWS
AWS_REGION=us-east-1
AWS_S3_BUCKET=your-s3-bucket

# Application
NODE_ENV=production
JWT_SECRET=your-jwt-secret
CORS_ORIGIN=http://your-ec2-ip
```

## 🔐 Security Notes

1. **Change default passwords** in terraform.tfvars
2. **Restrict SSH access** to your IP only
3. **Use AWS Secrets Manager** for production secrets
4. **Enable CloudTrail** for audit logging
5. **Set up CloudWatch** for monitoring

## 🗑️ Cleanup

To destroy all resources:

```bash
terraform destroy -var-file="terraform.tfvars"
```

## 📞 Troubleshooting

### Common Issues:

1. **Database connection failed**
   - Check security groups
   - Verify RDS is in running state

2. **Docker images not found**
   - Push images to registry first
   - Update image names in terraform.tfvars

3. **SSH connection refused**
   - Check security group allows SSH from your IP
   - Verify key pair is correct

4. **Application not responding**
   - SSH to server and check: `docker-compose logs`
   - Check user-data.log: `sudo tail -f /var/log/user-data.log`

### Log Locations:
- User data script: `/var/log/user-data.log`
- Application logs: `/home/ec2-user/backroom/logs/`
- Docker logs: `docker-compose logs`
