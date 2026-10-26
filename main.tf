module "network" {
  source = "./modules/network"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = local.public_subnet_cidr
  availability_zone  = var.availability_zone
}

# Composición: la subred y el security group salen del módulo de red.
module "compute" {
  source = "./modules/compute"

  name_prefix       = local.name_prefix
  subnet_id         = module.network.public_subnet_id
  security_group_id = module.network.web_security_group_id
  instance_type     = var.instance_type

  # Artefacto docente integrado sin modificar su lógica; Terraform entrega sus cinco parámetros.
  user_data = templatefile("${path.module}/templates/user_data_v1.sh.tpl", {
    student_name   = var.student_name
    student_number = tostring(var.student_number)
    environment    = local.environment
    portal_version = local.portal_version
    project_name   = local.portal_project_name
  })
}