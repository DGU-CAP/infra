# ──────────────────────────────────────────
# ECR 레포지토리 (백엔드 / 프론트엔드 / AI)
# ──────────────────────────────────────────

locals {
  ecr_repos = ["backend", "frontend", "ai"]
}

resource "aws_ecr_repository" "apps" {
  for_each = toset(local.ecr_repos)

  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${each.key}"
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "apps" {
  for_each   = aws_ecr_repository.apps
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "최근 이미지 20개만 유지"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "ecr_repository_urls" {
  description = "ECR 레포지토리 URL 목록"
  value       = { for k, v in aws_ecr_repository.apps : k => v.repository_url }
}
