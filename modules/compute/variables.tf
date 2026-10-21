variable "name_prefix" {
  description = "Prefijo para el nombre de la instancia."
  type        = string
}

variable "subnet_id" {
  description = "ID de la subred donde se crea la instancia. Lo entrega el modulo de red."
  type        = string
}

variable "security_group_id" {
  description = "ID del grupo de seguridad de la instancia. Lo entrega el modulo de red."
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2."
  type        = string
}

variable "user_data" {
  description = "Script que la instancia ejecuta en su primer arranque."
  type        = string
}