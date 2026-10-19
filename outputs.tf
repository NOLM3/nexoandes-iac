output "vpc_id" {
  description = "ID de la VPC."
  value       = module.network.vpc_id
}

output "instance_id" {
  description = "ID de la instancia del portal."
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "IPv4 pública del portal."
  value       = module.compute.public_ip
}

output "private_ip" {
  description = "IPv4 privada del portal."
  value       = module.compute.private_ip
}

output "availability_zone" {
  description = "Zona de disponibilidad de la instancia."
  value       = module.compute.availability_zone
}

output "portal_url" {
  description = "URL HTTP del Portal Operacional."
  value       = "http://${module.compute.public_ip}/"
}