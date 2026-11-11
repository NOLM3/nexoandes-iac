# Entrada pública solo al ALB; las instancias solo aceptan tráfico desde el SG del ALB.
resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "HTTP publico hacia el ALB del Portal."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  #checkov:skip=CKV_AWS_260:El Portal se publica por HTTP/80 a través del ALB; HTTPS requiere dominio y certificado, fuera del alcance de U2.
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde Internet."
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  description                  = "HTTP hacia las instancias del Portal."
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_security_group" "web" {
  name_prefix = "${var.name_prefix}-web-"
  description = "HTTP hacia las instancias, solo desde el ALB."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-web-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  #checkov:skip=CKV_AWS_260:Falso positivo: el origen es el SG del ALB, no 0.0.0.0/0.
  security_group_id            = aws_security_group.web.id
  description                  = "HTTP solo desde el ALB."
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

# Salida para el bootstrap: si la imagen no trae Python 3, la plantilla lo instala desde los repositorios.
resource "aws_vpc_security_group_egress_rule" "web_all" {
  security_group_id = aws_security_group.web.id
  description       = "Salida hacia Internet para el bootstrap."
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
