# Plantilla de cómputo versionada: cada cambio de bootstrap, AMI o tipo crea una versión nueva.
resource "aws_launch_template" "this" {
  name                   = "${var.name_prefix}-lt"
  description            = "Portal ${var.app_version} build ${var.build_ref}"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  update_default_version = true

  # La plantilla del docente va codificada en base64, como exige aws_launch_template.
  user_data = base64encode(var.user_data)

  # IMDSv2 obligatorio: el Portal consulta la metadata con token de sesión.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted             = true
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name    = "${var.name_prefix}-portal"
      version = var.app_version
      build   = var.build_ref
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-portal-disk"
    })
  }

  tags = {
    Name = "${var.name_prefix}-lt"
  }
}

# Controlador único del cambio: el ASG reemplaza instancias mediante Instance Refresh.
resource "aws_autoscaling_group" "this" {
  name                      = "${var.name_prefix}-asg"
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = [aws_lb_target_group.this.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  # Capacidad base fija; el máximo deja espacio para una instancia temporal durante el reemplazo.
  min_size         = var.base_capacity
  desired_capacity = var.base_capacity
  max_size         = var.base_capacity + 1

  # Solo al crear: Terraform espera a que la capacidad base esté sana en el ALB.
  min_elb_capacity = var.base_capacity

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  # Al cambiar la versión del Launch Template, Terraform inicia un Instance Refresh.
  # Primero lanza la instancia nueva (máximo 150 %) y nunca baja de la capacidad base (mínimo 100 %).
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 150
      instance_warmup        = 90
      skip_matching          = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-asg"
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  depends_on = [aws_lb_listener.http]
}
