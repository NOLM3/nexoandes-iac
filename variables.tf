variable "aws_region" {
  description = "Region de AWS donde se despliega el portal."
  type        = string
  default     = "us-east-1"
}

variable "student_number" {
  description = "Numero de lista del estudiante. Define la subred 172.16.X.0/24 y el tag StudentNumber."
  type        = number
  default     = 6

  validation {
    condition     = var.student_number >= 1 && var.student_number <= 254
    error_message = "student_number debe estar entre 1 y 254 para formar una subred 172.16.X.0/24 valida."
  }
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

variable "instance_type" {
  description = "Tipo de instancia EC2 del portal."
  type        = string
  default     = "t2.micro"
}