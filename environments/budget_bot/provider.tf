terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "budgetbot-tfstate-hackathon-w7"
    key          = "budget_bot/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "W7Capstone"
      Team        = "G9"
      Owner       = "G9"
      Environment = "hackathon"
    }
  }
}
