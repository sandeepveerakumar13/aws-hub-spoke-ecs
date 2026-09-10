terraform {
  backend "s3" {
    bucket       = "aws-hub-spoke-ecs-terraform-state-553336999743"
    key          = "aws-hub-spoke-ecs/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
  }
}