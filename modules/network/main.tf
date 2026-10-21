# Red de la Fase 1. El CIDR llega desde el root module (172.16.0.0/16 según el diagrama).
resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:Flow logs corresponden a monitoreo avanzado, fuera de alcance en Fase 1.
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# Security group por defecto de la VPC sin reglas: bloquea todo el tráfico que no use el SG del portal.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-default-sg"
  }
}

# Subred pública 172.16.X.0/24 (X = número de lista).
# map_public_ip_on_launch asigna IPv4 pública a la instancia del portal.
resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130:El diagrama de Fase 1 exige IPv4 pública automática para exponer el portal.
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-subnet"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# Ruta por defecto hacia el IGW. La ruta local de la VPC la crea AWS implícitamente.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Reglas definidas como recursos independientes (no inline) para gestionarlas por separado.
resource "aws_security_group" "web" {
  #checkov:skip=CKV2_AWS_5:El SG se asocia a la instancia en el módulo compute; Checkov no resuelve la relación entre módulos.
  name_prefix = "${var.name_prefix}-web-"
  description = "Permite HTTP hacia el Portal Operacional NexoAndes."
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-web-sg"
  }
}

# Único ingreso permitido: HTTP/80. SSH fuera de alcance en Fase 1.
resource "aws_vpc_security_group_ingress_rule" "http" {
  #checkov:skip=CKV_AWS_260:El portal debe responder HTTP público en el puerto 80 según el diagrama de Fase 1.
  security_group_id = aws_security_group.web.id
  description       = "HTTP hacia el portal."
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# Egreso requerido por el user data para instalar paquetes durante el bootstrap.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "Salida hacia Internet para el bootstrap."
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}