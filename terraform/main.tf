terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-2"
}

#-------------------------------------------------
# VPC and Networking
#-------------------------------------------------

resource "aws_vpc" "custom_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "private-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-2a"
  tags = {
    Name = "private-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id
  tags = {
    Name = "internet-gateway"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "nat-gateway"
  }
  depends_on = [aws_internet_gateway.igw]
}

#-------------------------------------------------
# Route Tables
#-------------------------------------------------

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.custom_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

#-------------------------------------------------
# S3 Bucket for Private Data
#-------------------------------------------------

# Create a unique, private S3 bucket
resource "aws_s3_bucket" "data_source_bucket" {
  # Bucket names must be globally unique
  bucket = "flask-app-private-data-source-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "PrivateDataSourceBucket"
  }
}

# Enforce private access settings on the bucket
resource "aws_s3_bucket_public_access_block" "private_access" {
  bucket = aws_s3_bucket.data_source_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload a sample data file to our new bucket
resource "aws_s3_object" "data_file" {
  bucket = aws_s3_bucket.data_source_bucket.id
  key    = "data.txt"
  content = "This is secret data from the private S3 bucket."
  tags = {
    Name = "SecretDataFile"
  }
}

# Used to create a unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

#-------------------------------------------------
# IAM Role for EC2 to Access S3
#-------------------------------------------------

# IAM policy that allows reading from our specific S3 bucket
data "aws_iam_policy_document" "s3_read_policy_doc" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.data_source_bucket.arn,
      "${aws_s3_bucket.data_source_bucket.arn}/*",
    ]
  }
}

# The IAM role that the EC2 instance will assume
resource "aws_iam_role" "ec2_s3_access_role" {
  name = "ec2-s3-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# The IAM policy based on the document above
resource "aws_iam_policy" "s3_read_policy" {
  name   = "s3-read-access-policy"
  policy = data.aws_iam_policy_document.s3_read_policy_doc.json
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

# Create an instance profile to attach the role to the EC2 instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-access-profile"
  role = aws_iam_role.ec2_s3_access_role.name
}

#-------------------------------------------------
# Security Group for Public App
#-------------------------------------------------

resource "aws_security_group" "flask_sg" {
  name        = "flask_sg"
  description = "Allow SSH and App Port 8000"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: For demo only. Restrict to your IP in production.
  }

  ingress {
    description = "Flask App"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-------------------------------------------------
# Public EC2 Instance
#-------------------------------------------------

resource "aws_instance" "flask_app" {
  ami                      = "ami-07891c5a242abf4bc" # ap-south-2 Ubuntu 22.04
  instance_type            = "t3.micro"
  key_name                 = "project"
  vpc_security_group_ids   = [aws_security_group.flask_sg.id]
  subnet_id                = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  # Attach the IAM role via the instance profile
  iam_instance_profile     = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "FlaskAppServer"
  }

  # This script now fetches data from the S3 bucket
  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

              echo "--- Starting user_data script for Flask App ---"

              # Update and install dependencies (Docker and AWS CLI)
              apt-get update -y
              apt-get install -y docker.io unzip curl

              usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker

              # Install AWS CLI v2 using the official installer
              echo "--- Installing AWS CLI v2 ---"
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install
              rm -rf awscliv2.zip aws

              # --- Accessing the Private S3 Data Source ---
              echo "Attempting to fetch data from S3 bucket: ${aws_s3_bucket.data_source_bucket.id}"
              
              # Use the AWS CLI to copy the file from S3 to the instance
              # This works because the instance has the IAM role attached.
              aws s3 cp s3://${aws_s3_bucket.data_source_bucket.id}/data.txt /home/ubuntu/data.txt
              
              echo "--- Data file copied from S3. Content: ---"
              cat /home/ubuntu/data.txt
              echo "-------------------------------------------"

              echo "--- Pulling and running Docker container ---"
              docker pull sanders003/flask-auth-app:latest
              docker run -d -p 8000:8000 sanders003/flask-auth-app:latest

              echo "--- Flask App user_data script finished ---"
              EOF

  user_data_replace_on_change = true
}
