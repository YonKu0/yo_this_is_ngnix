tflint {
  required_version = ">= 0.55.0, < 0.56.0"
}

config {
  disabled_by_default = true
}

plugin "aws" {
  enabled = true
  version = "0.45.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Baseline, low-noise rules for deterministic CI quality gating.
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "aws_instance_invalid_type" {
  enabled = true
}
