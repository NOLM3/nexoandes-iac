output "instance_id" {
  description = "ID de la instancia del portal."
  value       = aws_instance.portal.id
}

output "public_ip" {
  description = "IPv4 pública de la instancia."
  value       = aws_instance.portal.public_ip
}

output "private_ip" {
  description = "IPv4 privada de la instancia."
  value       = aws_instance.portal.private_ip
}

output "availability_zone" {
  description = "Zona de disponibilidad de la instancia."
  value       = aws_instance.portal.availability_zone
}