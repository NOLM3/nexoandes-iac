# Pruebas de plan con proveedor simulado: no requieren credenciales ni crean recursos.
mock_provider "aws" {}

run "subred_segun_numero_de_lista" {
  command = plan

  variables {
    student_number = 6
  }

  assert {
    condition     = output.public_subnet_cidr == "172.16.6.0/24"
    error_message = "La subred publica debe ser 172.16.6.0/24 para el estudiante 6."
  }
}

run "modulo_reutilizable_con_otro_estudiante" {
  command = plan

  variables {
    student_number = 12
  }

  assert {
    condition     = output.public_subnet_cidr == "172.16.12.0/24"
    error_message = "La subred publica debe recalcularse segun student_number."
  }
}

run "rechaza_numero_fuera_de_rango" {
  command = plan

  variables {
    student_number = 300
  }

  expect_failures = [var.student_number]
}