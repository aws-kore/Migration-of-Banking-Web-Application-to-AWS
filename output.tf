# Output for public IPs of web instances
output "web_instance_ips" {
  value = [for instance in aws_instance.web : instance.public_ip]
}

# Example web EC2 instance (assuming count is used)
resource "aws_instance" "web" {
  count         = 3
  ami           = "ami-087f352c165340ea1" # Replace with your region's appropriate AMI
  instance_type = "t3.micro"

  tags = {
    Name = "WebInstance-${count.index}"
  }

  # Optional: Associate a public IP (ensure subnet allows it)
  associate_public_ip_address = true

  # Add VPC/subnet/security group etc. as needed
}

# S3 Bucket resource
resource "aws_s3_bucket" "banking_files" {
  bucket = "bucket-korede-bucket" # Dashes are safer than underscores in bucket names (per AWS rules)

  tags = {
    Name        = "Banking Files Bucket"
    Environment = "Dev"
  }

  # Optional: Set bucket ACL, versioning, etc.
}
