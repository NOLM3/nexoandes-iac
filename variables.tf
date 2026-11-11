variable "x" {
  description = "Número asignado por el docente. Define la red 10.X.0.0/16, el alumno aNNN y los nombres."
  type        = number
  default     = 6

  validation {
    condition     = var.x >= 1 && var.x <= 254 && floor(var.x) == var.x
    error_message = "x debe ser un entero entre 1 y 254."
  }
}

variable "course" {
  description = "Código de curso con formato cNN."
  type        = string
  default     = "c50"

  validation {
    condition     = can(regex("^c[0-9]{2}$", var.course))
    error_message = "course debe tener el formato cNN, por ejemplo c50."
  }
}

variable "build_ref" {
  description = "Referencia real del artefacto desplegado: SHA del último commit que cambió la plantilla o la versión. La entrega el pipeline."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{4,80}$", var.build_ref))
    error_message = "build_ref debe tener entre 4 y 80 caracteres: letras, números, punto, guion o guion bajo."
  }
}

variable "app_version" {
  description = "Versión del Portal que instala la plantilla. Cambiarla genera una nueva versión del Launch Template y un Instance Refresh."
  type        = string
  default     = "v1"

  validation {
    condition     = contains(["v1", "v2"], var.app_version)
    error_message = "app_version debe ser v1 o v2."
  }
}

variable "aws_region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Dos zonas distintas para las subredes A y B."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2 && var.availability_zones[0] != var.availability_zones[1]
    error_message = "Se requieren exactamente dos zonas distintas."
  }
}

variable "ami_id" {
  description = "AMI fija de Amazon Linux 2023 (al2023-ami-kernel-6.1-x86_64, us-east-1, consultada el 2026-11-11). Se fija para que una AMI nueva no reemplace instancias sin un cambio en el código."
  type        = string
  default     = "ami-0b17a6d8467be8c20"

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id debe ser un ID de AMI válido (ami-...)."
  }
}

variable "instance_type" {
  description = "Tipo de instancia del Portal."
  type        = string
  default     = "t3.micro"
}

variable "base_capacity" {
  description = "Capacidad base fija del ASG. Durante el Instance Refresh se suma una instancia temporal."
  type        = number
  default     = 2
}
