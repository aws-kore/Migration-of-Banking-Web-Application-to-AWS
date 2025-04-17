# VPC
resource "aws_vpc" "banking_vpc" {
  cidr_block = var.vpc_cidr
}

# Internet Gateway
resource "aws_internet_gateway" "banking_igw" {
  vpc_id = aws_vpc.banking_vpc.id

  tags = {
    Name = "banking-igw"
  }
}

# Route Table
resource "aws_route_table" "banking_public_rt" {
  vpc_id = aws_vpc.banking_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.banking_igw.id
  }

  tags = {
    Name = "banking-public-rt"
  }
}

# Public Subnet
resource "aws_subnet" "banking_public_subnet" {
  vpc_id                  = aws_vpc.banking_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
}

# Route Table Association
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.banking_public_subnet.id
  route_table_id = aws_route_table.banking_public_rt.id
}

# Security Group for Web/App Tier
resource "aws_security_group" "banking_web_sg" {
  name   = "bankweb-sg"
  vpc_id = aws_vpc.banking_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "banking-web-sg"
  }
}

# EC2 Instances (3) + User Data + Optional Elastic IP for first instance
resource "aws_instance" "banking_App" {
  count                  = 3
  ami                    = "ami-087f352c165340ea1"
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.banking_public_subnet.id
  vpc_security_group_ids = [aws_security_group.banking_web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              EOF

  tags = {
    Name = "banking-app-${count.index + 1}"
  }
}

# Optionally associate Elastic IP with one EC2 instance (to use your given IP)
resource "aws_eip" "banking_eip" {
  instance = aws_instance.banking_App[0].id
  # Remove the public_ip line unless you already own the IP in your AWS account.
  # public_ip = "35.92.160.168" # IP Address is Dynamic 

}

#aws_cloudwatch_metric_alarm 
# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "banking-alb1"
  load_balancer_type = "application"
  subnets            = [aws_subnet.banking_public_subnet.id]
  security_groups    = [aws_security_group.banking_web_sg.id]
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow DB access"
  vpc_id      = aws_vpc.banking_vpc.id

  ingress {
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# RDS Oracle Instance
resource "aws_db_instance" "banking_oracle" {
  identifier             = "banking-db"
  engine                 = "oracle-se2"
  engine_version         = "19.0.0.0.ru-2023-04.rur-2023-04.r1"
  instance_class         = "db.m5.large"
  allocated_storage      = 20
  username               = var.db_username
  password               = var.db_password
  multi_az               = true
  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Name = "banking-db"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "banking_files_App" {
  bucket = "banking-transfer-bucket"
}

# AWS Transfer Server
resource "aws_transfer_server" "sftp" {
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type          = "PUBLIC"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "web_logs" {
 name = "/banking/web"
 
}

# SNS Topic
resource "aws_sns_topic" "alerts" {
  name = "banking-alerts"
}

# CloudWatch Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-web"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = "your-asg-name"
  }
}
