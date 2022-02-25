terraform {
  required_version = "~> 1.1.2"

  required_providers {
    aws = {
      version = "~> 4.1.0"
      source  = "hashicorp/aws"
    }
  }
}

# Download AWS provider
provider "aws" {
  region = "us-east-2"
  assume_role {
    role_arn     = "arn:aws:iam::947197796922:role/PulseSTS-Deity-AssumedRole"
    session_name = "default"
  }
}

data "aws_caller_identity" "current" {}

# Print out IAM role being used
output "whoami" {
  value = data.aws_caller_identity.current.arn
}

