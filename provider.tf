terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Ορίζουμε την περιοχή που θα χτιστεί η υποδομή
provider "aws" {
  region = "eu-north-1" # Stockholm - μπορούμε να βάλουμε και us-east-1
}