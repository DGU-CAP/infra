/**
 * Bootstrap — 최초 1회만 실행
 * Terraform 공유 state 저장소(S3)와 잠금 테이블(DynamoDB)을 생성합니다.
 *
 * 실행 방법:
 *   cd bootstrap
 *   terraform init
 *   terraform apply
 *
 * 생성 완료 후 terraform/ 디렉토리에서 terraform init 을 실행하세요.
 */

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# ──────────────────────────────────────────
# S3 — Terraform State 저장소
# ──────────────────────────────────────────
resource "aws_s3_bucket" "terraform_state" {
  bucket = "dgu-cap-terraform-state"

  # 실수로 삭제 방지
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "dgu-cap-terraform-state"
    Environment = "shared"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ──────────────────────────────────────────
# DynamoDB — State Lock 테이블
# ──────────────────────────────────────────
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "dgu-cap-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "dgu-cap-terraform-locks"
    Environment = "shared"
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}
