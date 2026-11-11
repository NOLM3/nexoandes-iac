output "vpc_id" {
  description = "ID de la VPC."
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "IDs de las subredes públicas, en orden A, B."
  value       = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].id]
}

output "subnet_cidrs" {
  description = "Rangos de las subredes públicas, en orden A, B."
  value       = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].cidr_block]
}
