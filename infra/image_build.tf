data "aws_caller_identity" "current" {}

locals {
  ecr_repository = "${var.name_prefix}-app"

  dockerfile_sha = filesha256("${path.module}/../docker/Dockerfile")
  nginx_conf_sha = filesha256("${path.module}/../docker/nginx.conf")

  # Deterministic tag based on the container source.
  image_tag = substr(sha256("${local.dockerfile_sha}${local.nginx_conf_sha}"), 0, 12)

  ecr_registry        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  built_image_uri     = "${local.ecr_registry}/${local.ecr_repository}:${local.image_tag}"
  app_image_effective = var.app_image_uri != "" ? var.app_image_uri : local.built_image_uri
}

# "One click" path: if app_image_uri is empty, build and push the image as part of terraform apply.
# CI/production-style path: set app_image_uri and this resource is skipped.
resource "null_resource" "build_and_push_image" {
  count = var.app_image_uri != "" ? 0 : 1

  triggers = {
    dockerfile_sha = local.dockerfile_sha
    nginx_conf_sha = local.nginx_conf_sha
    image_tag      = local.image_tag
    repository     = local.ecr_repository
    region         = var.region
    account_id     = data.aws_caller_identity.current.account_id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    working_dir = "${path.module}/.."
    command     = <<-EOT
      set -euo pipefail

      command -v aws >/dev/null 2>&1 || { echo "aws CLI is required." >&2; exit 1; }
      command -v docker >/dev/null 2>&1 || { echo "docker is required." >&2; exit 1; }
      docker buildx version >/dev/null 2>&1 || { echo "docker buildx is required." >&2; exit 1; }

      if aws ecr describe-repositories --region "${var.region}" --repository-names "${local.ecr_repository}" >/dev/null 2>&1; then
        echo "ECR repository exists: ${local.ecr_repository}"
      else
        echo "Creating ECR repository: ${local.ecr_repository}"
        aws ecr create-repository \
          --region "${var.region}" \
          --repository-name "${local.ecr_repository}" \
          --image-scanning-configuration scanOnPush=true \
          --image-tag-mutability IMMUTABLE >/dev/null
      fi

      # If the deterministic tag already exists (for example after a destroy/re-apply), do not try to re-push to an IMMUTABLE repo.
      if aws ecr describe-images --region "${var.region}" --repository-name "${local.ecr_repository}" --image-ids imageTag="${local.image_tag}" >/dev/null 2>&1; then
        echo "ECR image already exists: ${local.built_image_uri} (skipping build/push)"
        exit 0
      fi

      aws ecr get-login-password --region "${var.region}" | \
        docker login --username AWS --password-stdin "${local.ecr_registry}"

      docker buildx build --platform linux/amd64 -f docker/Dockerfile -t "${local.built_image_uri}" --push .
    EOT
  }
}

