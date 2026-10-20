# State remoto en S3, compartido entre la terminal local y el pipeline.
# use_lockfile impide que dos ejecuciones modifiquen el state al mismo tiempo.
terraform {
  backend "s3" {
    bucket       = "nexoandes-tfstate-s6-943830680153"
    key          = "fase1/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}