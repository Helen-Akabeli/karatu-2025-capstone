terraform {
  backend "s3" {
    bucket  = "project-bedrock-tf-state-soe-025-4174"
    key     = "eks/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}