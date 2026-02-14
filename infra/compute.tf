resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.app_instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.app.name
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/templates/user_data_app.sh.tftpl", {
    app_port      = var.app_port
    app_image_uri = local.app_image_effective
    aws_region    = var.region
  })

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-app"
    Role = "app"
  })

  depends_on = [
    aws_route.private_default,
    null_resource.build_and_push_image
  ]
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = var.app_port
}

