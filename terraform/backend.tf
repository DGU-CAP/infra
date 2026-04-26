terraform {
  backend "s3" {
    bucket         = "dgu-cap-terraform-state"
    key            = "terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "dgu-cap-terraform-locks"
    encrypt        = true
  }
}
