terraform {
  required_version = ">= 1.1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.42.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
  cloud {
    organization="SOLCOMPUTING"
    workspaces {
      name=%WORKSPACEINFRA%#replace.WORKSPACEINFRA
    }
  }
}

provider "vault" {
  address = var.VAULT_ADDR
  token   = var.CICD_VAULT_TOKEN
}

data "vault_generic_secret" "aws_auth" {
  namespace=local.namespace
  path = lower(join("/", ["secret/aws", join("_", [var.ACCOUNT, "administrators"])]))
}

provider "aws" {
    access_key=data.vault_generic_secret.aws_auth.data[join("_", ["AWS_ACCESS_KEY", var.ACCOUNT, var.PROFILE, local.namespace])]
    secret_key=data.vault_generic_secret.aws_auth.data[join("_", ["AWS_SECRET_KEY", var.ACCOUNT, var.PROFILE, local.namespace])]
    region="eu-west-3"
}

