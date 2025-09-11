# ===== BackRoom Infrastructure with Terraform =====
# Creates: RDS MySQL + S3 Bucket + EC2 with Docker containers

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ===== VPC and Networking =====
resource "aws_vpc" "backroom_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-${var.site_name}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "backroom_igw" {
  vpc_id = aws_vpc.backroom_vpc.id

  tags = {
    Name        = "${var.project_name}-${var.site_name}-igw"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public_subnets" {
  count = 2
  
  vpc_id                  = aws_vpc.backroom_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.site_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Private Subnets (for RDS)
resource "aws_subnet" "private_subnets" {
  count = 2
  
  vpc_id            = aws_vpc.backroom_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project_name}-${var.site_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.backroom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.backroom_igw.id
  }

  tags = {
    Name        = "${var.project_name}-${var.site_name}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public_rta" {
  count = length(aws_subnet.public_subnets)
  
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# ===== Security Groups =====
resource "aws_security_group" "ec2_sg" {
  name_prefix = "${var.project_name}-${var.site_name}-ec2-"
  vpc_id      = aws_vpc.backroom_vpc.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend API
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.site_name}-ec2-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "${var.project_name}-${var.site_name}-rds-"
  vpc_id      = aws_vpc.backroom_vpc.id

  # MySQL
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  tags = {
    Name        = "${var.project_name}-${var.site_name}-rds-sg"
    Environment = var.environment
  }
}

# ===== S3 Bucket =====
resource "aws_s3_bucket" "backroom_storage" {
  bucket = "${var.project_name}-${var.site_name}-storage-${var.environment}-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-${var.site_name}-storage"
    Environment = var.environment
  }
}

# Upload V1__init.sql to S3 for database initialization
resource "aws_s3_object" "db_init_sql" {
  bucket = aws_s3_bucket.backroom_storage.bucket
  key    = "database/V1__init.sql"
  source = "${path.module}/V1__init.sql"
  etag   = filemd5("${path.module}/V1__init.sql")

  tags = {
    Name        = "Database Init SQL"
    Environment = var.environment
    Project     = "BackRoom"
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "backroom_storage_versioning" {
  bucket = aws_s3_bucket.backroom_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backroom_storage_encryption" {
  bucket = aws_s3_bucket.backroom_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backroom_storage_pab" {
  bucket = aws_s3_bucket.backroom_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ===== RDS Subnet Group =====
resource "aws_db_subnet_group" "backroom_db_subnet_group" {
  name       = "${var.project_name}-${var.site_name}-db-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id

  tags = {
    Name        = "${var.project_name}-${var.site_name}-db-subnet-group"
    Environment = var.environment
  }
}

# ===== RDS Instance =====
resource "aws_db_instance" "backroom_db" {
  identifier = "${var.project_name}-${var.site_name}-db-${var.environment}"

  # Engine
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.rds_instance_class

  # Storage
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true

  # Database
  db_name  = var.database_name
  username = var.database_username
  password = var.database_password

  # Network
  db_subnet_group_name   = aws_db_subnet_group.backroom_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false

  # Backup
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  # Other
  skip_final_snapshot = var.environment == "dev" ? true : false
  deletion_protection = var.environment == "prod" ? true : false

  tags = {
    Name        = "${var.project_name}-${var.site_name}-db"
    Environment = var.environment
  }
}

# ===== IAM Role for EC2 =====
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.site_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.site_name}-ec2-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "s3_policy" {
  name = "${var.project_name}-${var.site_name}-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.backroom_storage.arn,
          "${aws_s3_bucket.backroom_storage.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.site_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ===== Key Pair =====
# Use existing key pair instead of creating new one
data "aws_key_pair" "existing_key" {
  key_name = var.existing_key_name
}

# ===== EC2 Instance =====
resource "aws_instance" "backroom_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.ec2_instance_type
  key_name               = data.aws_key_pair.existing_key.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.public_subnets[0].id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_type = var.ec2_root_volume_type
    volume_size = var.ec2_root_volume_size
    encrypted   = var.ec2_root_volume_encrypted
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    db_host           = split(":", aws_db_instance.backroom_db.endpoint)[0]
    db_name           = var.database_name
    db_user           = var.database_username
    db_password       = var.database_password
    s3_bucket         = aws_s3_bucket.backroom_storage.bucket
    aws_region        = var.aws_region
    jwt_secret        = var.jwt_secret
    backend_image     = var.backend_docker_image
    frontend_image    = var.frontend_docker_image
    site_name         = var.site_name
  }))

  tags = {
    Name        = "${var.project_name}-${var.site_name}-server"
    Environment = var.environment
  }

  depends_on = [aws_db_instance.backroom_db]
}
