locals {
  common_tags = {
    Project   = var.name_prefix
    ManagedBy = "Terraform"
  }

  # AWS name limits (ALB/TG names must be <= 32 chars). Also sanitize to allowed charset.
  alb_name = trim(substr(join("-", regexall("[a-zA-Z0-9]+", "${var.name_prefix}-alb")), 0, 32), "-")
  tg_name  = trim(substr(join("-", regexall("[a-zA-Z0-9]+", "${var.name_prefix}-tg")), 0, 32), "-")
}

