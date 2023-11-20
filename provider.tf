terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
    region = "enter_region"
    access_key = "us-east-1"
    secret_key = "enter_secret_key"
}