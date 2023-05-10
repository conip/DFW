terraform {
  cloud {
    organization = "CONIX"

   workspaces {
      name = "DFW"
    }
  }
  required_providers {

    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = "~>3.0.5"
    }
    aws = {
      source = "hashicorp/aws"
      version = "~>4.33.0"
    }
  }
}

