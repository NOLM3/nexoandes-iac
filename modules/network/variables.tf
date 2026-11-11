variable "name_prefix" {
  description = "Prefijo para los nombres de los recursos de red."
  type        = string
}

variable "vpc_cidr" {
  description = "Rango de direcciones de la VPC."
  type        = string
}

variable "subnets" {
  description = "Subredes públicas: clave = sufijo, con su rango y su zona."
  type = map(object({
    cidr = string
    az   = string
  }))
}
