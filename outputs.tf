output "db_endpoint" {
  value = aws_db_instance.project3_db.endpoint
}

output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "alb_dns_name" {
  value = aws_lb.main_alb.dns_name
}