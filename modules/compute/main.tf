resource "aws_instance" "portal" {
  #checkov:skip=CKV_AWS_126:Monitoreo detallado corresponde a monitoreo avanzado, fuera de alcance en Fase 1.
  #checkov:skip=CKV_AWS_135:El tipo t2.micro no admite EBS optimizado.
  #checkov:skip=CKV2_AWS_41:El portal no consume APIs de AWS; sin rol IAM se aplica mínimo privilegio.
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

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.name_prefix}-portal"
  }
}