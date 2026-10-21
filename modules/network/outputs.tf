output "vpc_id" {
  description = "ID de la VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "ID de la subred publica."
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "Rango de direcciones de la subred publica."
  value       = aws_subnet.public.cidr_block
}

output "web_security_group_id" {
  description = "ID del grupo de seguridad del portal."
  value       = aws_security_group.web.id
}