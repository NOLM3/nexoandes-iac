variable "name_prefix" {
  description = "Prefijo para los nombres de los recursos."
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC. Lo entrega el módulo de red."
  type        = string
}

variable "subnet_ids" {
  description = "Subredes del ALB y del ASG, en dos zonas. Las entrega el módulo de red."
  type        = list(string)
}

variable "ami_id" {
  description = "AMI fija del Launch Template."
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia."
  type        = string
}

variable "base_capacity" {
  description = "Capacidad base fija. El máximo es base + 1 para la instancia temporal del reemplazo."
  type        = number
}

variable "user_data" {
  description = "Bootstrap del Portal ya renderizado, sin codificar."
  type        = string
}

variable "app_version" {
  description = "Versión del Portal, para etiquetar las instancias."
  type        = string
}

variable "build_ref" {
  description = "Referencia del artefacto, para etiquetar las instancias."
  type        = string
}

variable "tags" {
  description = "Etiquetas de la convención U2 para las instancias y volúmenes que crea el ASG."
  type        = map(string)
}
