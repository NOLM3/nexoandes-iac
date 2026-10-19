variable "name_prefix" {
  description = "Prefijo para los nombres de los recursos de red."
  type        = string
}

variable "vpc_cidr" {
  description = "Rango de direcciones de la VPC."
  type        = string
}

variable "public_subnet_cidr" {
  description = "Rango de direcciones de la subred publica."
  type        = string
}

variable "availability_zone" {
  description = "Zona de disponibilidad de la subred publica."
  type        = string
}