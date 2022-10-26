terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
  shared_config_files      = ["C:/Users/Bhola/.aws/config"]
  shared_credentials_files = ["C:/Users/Bhola/.aws/credentials"]
}