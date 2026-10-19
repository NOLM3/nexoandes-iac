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

  # Plantilla provisoria hasta integrar user_data_v1.sh.tpl del docente.
  user_data = templatefile("${path.module}/user_data/portal_test.sh.tpl", {
    student_number = var.student_number
  })
}