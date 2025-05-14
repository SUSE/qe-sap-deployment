terraform {
  required_version = ">= 1.1.7"
  required_providers {
    # Configure the Azure Provider
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.4"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}
