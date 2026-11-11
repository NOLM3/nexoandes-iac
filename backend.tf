# State remoto en S3, compartido entre la terminal local y el pipeline.
# La U2 usa su propia clave: no comparte state con la Fase 1.
terraform {
  backend "s3" {
    bucket       = "nexoandes-tfstate-s6-943830680153"
    key          = "u2/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
