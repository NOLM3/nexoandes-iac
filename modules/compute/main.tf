resource "aws_instance" "portal" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  # El user data solo se ejecuta en el primer arranque: un cambio en el
  # script fuerza el reemplazo de la instancia para que se aplique.
  user_data                   = var.user_data
  user_data_replace_on_change = true

  # IMDSv2 obligatorio: el portal consulta la metadata con token de sesión.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "${var.name_prefix}-portal"
  }
}