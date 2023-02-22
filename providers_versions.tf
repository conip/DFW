terraform {
  cloud {
    organization = "CONIX"

    workspaces {
      name = "BLOG-10-UserVPNandMicrosegmentation"
    }
  }
  required_providers {

    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = "~>2.23.2"
    }
    aws = {
      source = "hashicorp/aws"
      version = "~>4.33.0"
    }
  }
}

