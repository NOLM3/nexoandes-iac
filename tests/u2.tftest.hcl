# Pruebas de plan con proveedor simulado: no requieren credenciales ni crean recursos.
mock_provider "aws" {}

variables {
  build_ref = "abc1234def56"
  ami_id    = "ami-0123456789abcdef0"
}

run "red_y_nombres_segun_convencion_u2" {
  command = plan

  assert {
    condition     = output.vpc_cidr == "10.6.0.0/16"
    error_message = "La VPC debe ser 10.6.0.0/16 para X = 6."
  }

  assert {
    condition     = output.subnet_cidrs == ["10.6.10.0/24", "10.6.20.0/24"]
    error_message = "Las subredes deben ser 10.6.10.0/24 y 10.6.20.0/24."
  }

  assert {
    condition     = output.name_prefix == "na-u2-c50-a006"
    error_message = "El prefijo debe ser na-u2-c50-a006."
  }
}

run "bootstrap_cabe_en_user_data" {
  command = plan

  assert {
    condition     = output.bootstrap_bytes < 16384
    error_message = "El script renderizado supera el límite de 16 KiB de user data."
  }
}

run "red_se_recalcula_con_otro_x" {
  command = plan

  variables {
    x = 12
  }

  assert {
    condition     = output.subnet_cidrs == ["10.12.10.0/24", "10.12.20.0/24"]
    error_message = "Las subredes deben recalcularse según x."
  }
}

run "rechaza_version_no_soportada" {
  command = plan

  variables {
    app_version = "v3"
  }

  expect_failures = [var.app_version]
}

run "rechaza_x_fuera_de_rango" {
  command = plan

  variables {
    x = 300
  }

  expect_failures = [var.x]
}
