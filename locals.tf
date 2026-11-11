locals {
  student     = format("a%03d", var.x)
  name_prefix = "na-u2-${var.course}-${local.student}"

  # Convención U2: VPC 10.X.0.0/16, subred A 10.X.10.0/24 y subred B 10.X.20.0/24.
  vpc_cidr = "10.${var.x}.0.0/16"
  subnets = {
    a = { cidr = "10.${var.x}.10.0/24", az = var.availability_zones[0] }
    b = { cidr = "10.${var.x}.20.0/24", az = var.availability_zones[1] }
  }

  common_tags = {
    proyecto  = "NexoAndes"
    fase      = "U2"
    alumno    = local.student
    curso     = var.course
    proveedor = "aws"
  }

  # Artefacto docente integrado sin modificar su lógica; Terraform entrega sus seis parámetros.
  portal_bootstrap = templatefile("${path.module}/templates/user_data_u2.sh.tpl", {
    provider       = "aws"
    x              = var.x
    student        = local.student
    course         = var.course
    build_ref      = var.build_ref
    portal_version = var.app_version
  })
}
