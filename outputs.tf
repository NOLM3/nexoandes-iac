output "name_prefix" {
  description = "Prefijo de nombres de la convención U2."
  value       = local.name_prefix
}

output "vpc_id" {
  description = "ID de la VPC."
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "Rango de la VPC."
  value       = local.vpc_cidr
}

output "subnet_cidrs" {
  description = "Rangos de las subredes A y B."
  value       = module.network.subnet_cidrs
}

output "alb_dns_name" {
  description = "DNS del ALB: endpoint único del Portal en AWS."
  value       = module.portal.alb_dns_name
}

output "portal_url" {
  description = "URL HTTP del Portal a través del ALB."
  value       = "http://${module.portal.alb_dns_name}"
}

output "target_group_arn" {
  description = "ARN del target group, para consultar la salud de los destinos."
  value       = module.portal.target_group_arn
}

output "asg_name" {
  description = "Nombre del Auto Scaling Group, controlador del reemplazo."
  value       = module.portal.asg_name
}

output "launch_template_id" {
  description = "ID del Launch Template."
  value       = module.portal.launch_template_id
}

output "launch_template_version" {
  description = "Versión del Launch Template que usa el ASG."
  value       = module.portal.launch_template_version
}

output "app_version" {
  description = "Versión del Portal configurada en el código."
  value       = var.app_version
}

output "build_ref" {
  description = "Referencia del artefacto desplegado."
  value       = var.build_ref
}

output "ami_id" {
  description = "AMI usada por el Launch Template."
  value       = var.ami_id
}

output "bootstrap_bytes" {
  description = "Tamaño del script renderizado. Debe ser menor a 16384 bytes, el límite de user data de AWS."
  value       = length(local.portal_bootstrap)
}
