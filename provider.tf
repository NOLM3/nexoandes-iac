provider "aws" {
  region = var.aws_region

  # Etiquetas de la convención U2 en todos los recursos que las admiten.
  default_tags {
    tags = local.common_tags
  }
}
