# 팀원 EKS 접근 권한 관리
# team_members 변수에 IAM ARN을 추가하고 terraform apply 하면 자동 적용됩니다.
#
# 팀원 ARN 확인 방법 (팀원이 직접 실행):
#   aws sts get-caller-identity --query Arn --output text
#
# terraform.tfvars의 team_members 목록에 ARN 추가 후:
#   terraform apply

resource "aws_eks_access_entry" "team" {
  for_each = toset(var.team_members)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value

  tags = {
    Environment = var.environment
  }
}

resource "aws_eks_access_policy_association" "team_admin" {
  for_each = toset(var.team_members)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.team]
}
