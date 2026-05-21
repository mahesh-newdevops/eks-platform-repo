terraform {
  backend "s3" {
    bucket         = "eks-terraform-state-prod"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}