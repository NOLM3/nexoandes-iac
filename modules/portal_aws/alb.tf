resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:Access logs corresponden a monitoreo avanzado; la observación del cambio se hace con el protocolo curl de la evaluación.
  #checkov:skip=CKV_AWS_150:Sin protección de borrado: el ALB debe poder eliminarse con destroy al cerrar la evaluación.
  #checkov:skip=CKV2_AWS_28:WAF fuera del alcance de U2; el Portal es una carga didáctica sin datos de usuarios.
  #checkov:skip=CKV2_AWS_20:Sin HTTPS: no hay dominio ni certificado en el laboratorio.
  name                       = "${var.name_prefix}-alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.subnet_ids
  drop_invalid_header_fields = true

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}

# El health check usa /api/check: devuelve 200 solo si el Portal confirma su metadata.
# /health solo prueba que el proceso responde, no que el Portal funcione.
resource "aws_lb_target_group" "this" {
  #checkov:skip=CKV_AWS_378:Tráfico HTTP dentro de la VPC entre el ALB y las instancias.
  name                 = "${var.name_prefix}-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    path                = "/api/check"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.name_prefix}-tg"
  }
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:Listener HTTP: no hay dominio ni certificado en el laboratorio.
  #checkov:skip=CKV_AWS_103:Sin TLS en el listener por la misma razón.
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
