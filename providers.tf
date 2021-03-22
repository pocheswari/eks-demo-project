terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

provider "http" {}

terraform {
  backend "consul" {
    address  = "localhost:8500"
    scheme   = "http"
    path     = "tf/state"
    lock     = true
    gzip     = false
  }
}
