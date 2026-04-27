# ──────────────────────────────────────────
# CloudWatch Log Group (컨트롤 플레인 로그)
# ──────────────────────────────────────────
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${local.eks_cluster_name}/cluster"
  retention_in_days = 7

  tags = {
    Name        = "${local.eks_cluster_name}-logs"
    Environment = var.environment
  }
}

# ──────────────────────────────────────────
# EKS Cluster
# ──────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = local.eks_cluster_name
  version  = var.k8s_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    # 컨트롤 플레인은 퍼블릭 + 프라이빗 서브넷 모두 지정
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = ["0.0.0.0/0"] # 필요 시 팀 IP로 제한 가능
  }

  enabled_cluster_log_types = ["api", "audit"]

  tags = {
    Name        = local.eks_cluster_name
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks_cluster,
  ]
}

# ──────────────────────────────────────────
# EKS 표준 애드온
# ──────────────────────────────────────────
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"

  tags = {
    Name        = "${local.eks_cluster_name}-vpc-cni"
    Environment = var.environment
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"

  tags = {
    Name        = "${local.eks_cluster_name}-kube-proxy"
    Environment = var.environment
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"

  # coredns는 노드가 있어야 스케줄링되므로 노드 그룹 생성 후 적용
  depends_on = [aws_eks_node_group.main]

  tags = {
    Name        = "${local.eks_cluster_name}-coredns"
    Environment = var.environment
  }
}
