variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = length(var.region) > 0
    error_message = "region must be a non-empty string."
  }
}

variable "name_prefix" {
  description = "Prefix used for naming/tagging resources."
  type        = string
  default     = "yo-this-is-ngnix"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.name_prefix))
    error_message = "name_prefix must be 3-32 chars: lowercase letters, digits, and hyphens only."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs (for ALB across AZs)."
  type        = list(string)
  default     = ["10.10.0.0/24", "10.10.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "public_subnet_cidrs must have exactly 2 CIDR blocks."
  }
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR (for the app EC2)."
  type        = string
  default     = "10.10.10.0/24"
}

variable "app_instance_type" {
  description = "EC2 instance type for the application instance."
  type        = string
  default     = "t3.micro"
}

variable "nat_instance_type" {
  description = "EC2 instance type for the NAT instance."
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Port on the EC2 host where the NGINX container will listen."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port >= 1024 && var.app_port <= 65535
    error_message = "app_port must be between 1024 and 65535."
  }
}

variable "app_image_uri" {
  description = "Full container image URI used by the app instance. If empty, Terraform will build and push the Docker image to ECR during `terraform apply` (one-click install). If set, Terraform will use the provided image URI and skip local build/push (CI/production-style flow)."
  type        = string
  default     = ""

  validation {
    condition     = var.app_image_uri == "" || can(regex(".+/.+:.+", var.app_image_uri))
    error_message = "app_image_uri must be empty (to enable one-click build/push) or a full image reference including tag (for example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/yo-this-is-ngnix-app:abc123)."
  }
}
