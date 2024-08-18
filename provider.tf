terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider (tokyo radio station)
provider "aws" {
  region = "ap-northeast-1"
}


