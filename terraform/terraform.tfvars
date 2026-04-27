aws_region   = "ap-northeast-2"
project_name = "dgu-cap"
environment  = "dev"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]

public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

k8s_version = "1.32"
domain_name = "" # HTTPS 사용 시 도메인 입력 (예: "monitoring.example.com")

# 팀원 IAM ARN 목록 — aws sts get-caller-identity --query Arn --output text 로 확인
team_members = [
  # "arn:aws:iam::123456789012:user/팀원이름",
]
