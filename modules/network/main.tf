# Red de la U2: VPC 10.X.0.0/16 con dos subredes públicas en zonas distintas, requisito del ALB.
resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:Flow logs corresponden a monitoreo avanzado, fuera del alcance de U2.
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# Security group por defecto sin reglas: bloquea todo lo que no use los SG del Portal.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-default-sg"
  }
}

resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130:Sin NAT Gateway, las instancias necesitan IPv4 pública para su salida; el SG solo admite tráfico desde el ALB.
  for_each = var.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-subnet-${each.key}"
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
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
