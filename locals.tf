locals {
  project = "NexoAndes"
  phase   = "Fase1"

  name_prefix = "nexoandes-fase1-s${var.student_number}"

  public_subnet_cidr = cidrsubnet(var.vpc_cidr, 8, var.student_number)

  # Parámetros fijos del Portal Operacional V1.
  environment         = "fase1"
  portal_version      = "v1"
  portal_project_name = "NexoAndes Portal Operacional"

  common_tags = {
    StudentNumber = tostring(var.student_number)
    Project       = local.project
    Phase         = local.phase
  }
}