variable "aws_region" {
  description = "Region de AWS donde se despliega el portal."
  type        = string
  default     = "us-east-1"
}

variable "student_number" {
  description = "Numero de lista del estudiante. Define la subred 172.16.X.0/24 y el tag StudentNumber."
  type        = number
  default     = 99
}

variable "vpc_cidr" {
  description = "Rango de direcciones de la VPC."
  type        = string
  default     = "172.16.0.0/16"
}

variable "availability_zone" {
  description = "Zona de disponibilidad de la subred publica."
  type        = string
  default     = "us-east-1a"
}