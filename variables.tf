variable "aws_region" { default = "eu-north-1" }
variable "instance_type" { default = "t3.micro" }
variable "vpc_cidr" { default = "10.0.0.0/16" }

# Subnets
variable "public_subnet_cidr" { default = "10.0.1.0/24" }
variable "private_subnet_az1_cidr" { default = "10.0.2.0/24" }
variable "private_subnet_az2_cidr" { default = "10.0.3.0/24" }
variable "public_subnet_az2_cidr" { default = "10.0.4.0/24" }

# Database (GitHub Ready)
variable "db_password" {
  description = "RDS root password"
  type        = string
  sensitive   = true
}