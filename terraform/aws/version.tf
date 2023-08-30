terraform {
  required_version = ">= 1.1.7"
  required_providers {
    # Configure the Azure Provider
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.14.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.1"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}
