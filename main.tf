# 1. VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = { Name = "Project3-VPC" }
}

# 2. Public Subnets
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "Project3-Public-A" }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.public_subnet_az2_cidr
  availability_zone = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = { Name = "Project3-Public-B" }
}

# 3. Private Subnet 1 (AZ-A)
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_az1_cidr
  availability_zone = "${var.aws_region}a"
  tags = { Name = "Project3-Private-A" }
}

# 4. Private Subnet 2 (AZ-B)
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_az2_cidr
  availability_zone = "${var.aws_region}b"
  tags = { Name = "Project3-Private-B" }
}

# 5. Internet Gateway & Routing
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 6. Security Group
resource "aws_security_group" "web_sg" {
  name   = "web-server-sg"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Μόνο ο ALB περνάει!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. Launch Template
resource "aws_launch_template" "web_lt" {
  name_prefix   = "project3-lt-"
  image_id      = "ami-0453f2bc6c82c9bb6" # Amazon Linux 2023
  instance_type = var.instance_type
  
  # Σύνδεση με το Security Group του Web Server
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Το User Data πρέπει να είναι Base64 encoded στο Launch Template!
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Architecture Managed by Terraform - High Availability Mode</h1>" > /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "Project3-ASG-Instance" }
  }
}

# 8. Database Security Group (Επιτρέπει πρόσβαση ΜΟΝΟ από τον Web Server)
resource "aws_security_group" "db_sg" {
  name   = "database-sg"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port       = 3306 # MySQL Port
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Μόνο ο Web Server "μιλάει" στη βάση
  }
}

# 9. DB Subnet Group (Τώρα με 2 ΠΡΑΓΜΑΤΙΚΑ Private Subnets)
resource "aws_db_subnet_group" "db_subnets" {
  name       = "main-db-subnets"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

# 10. RDS Instance
resource "aws_db_instance" "project3_db" {
  allocated_storage      = 20
  db_name                = "project3db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = var.db_password # Χρήση μεταβλητής
  skip_final_snapshot    = true
  multi_az = true # Πλέον έχουμε HA με Primary και Standby DB Instances
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
}

# 11. Security Group για τον ALB (Επιτρέπει HTTP από παντού)
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main_vpc.id

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
}

# 12. Ο Application Load Balancer
resource "aws_lb" "main_alb" {
  name               = "project3-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet.id, aws_subnet.public_subnet_2.id]
}

# 13. Target Group (Ο "στόχος" της κίνησης)
resource "aws_lb_target_group" "web_tg" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

# 14. Listener (Συνδέουμε το ALB με το Target Group)
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# 15. Auto Scaling Group 
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity    = 2 # Θέλουμε πάντα 2 servers
  max_size            = 3 # Μπορεί να φτάσει μέχρι 3 αν χρειαστεί
  min_size            = 1 # Τουλάχιστον 1 πάντα
  
  # Πού θα γεννιούνται οι servers; (Και στα δύο Public Subnets!)
  vpc_zone_identifier = [aws_subnet.public_subnet.id, aws_subnet.public_subnet_2.id]
  
  # Σύνδεση με τον Load Balancer
  target_group_arns   = [aws_lb_target_group.web_tg.arn]

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300
}
