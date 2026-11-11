module "network" {
  source = "./modules/network"

  name_prefix = local.name_prefix
  vpc_cidr    = local.vpc_cidr
  subnets     = local.subnets
}

# Composición: las subredes y la VPC salen del módulo de red.
module "portal" {
  source = "./modules/portal_aws"

  name_prefix   = local.name_prefix
  vpc_id        = module.network.vpc_id
  subnet_ids    = module.network.subnet_ids
  ami_id        = var.ami_id
  instance_type = var.instance_type
  base_capacity = var.base_capacity
  user_data     = local.portal_bootstrap
  app_version   = var.app_version
  build_ref     = var.build_ref
  tags          = local.common_tags
}
