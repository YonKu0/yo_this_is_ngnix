output "alb_dns_name" {
  description = "DNS name of the public Application Load Balancer."
  value       = aws_lb.this.dns_name
}

output "app_url" {
  description = "Public URL for the application."
  value       = "http://${aws_lb.this.dns_name}/"
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "app_instance_id" {
  description = "Private EC2 instance ID."
  value       = aws_instance.app.id
}

output "app_image_uri" {
  description = "Container image URI used by app user_data."
  value       = var.app_image_uri
}

