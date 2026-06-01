# ──────────────────────────────────────────
# EBS VolumeSnapshot 백업 인프라
# snapshot-controller(EKS 애드온) + snapscheduler(주기 스냅샷)
# ──────────────────────────────────────────

# CSI Snapshot Controller — VolumeSnapshot/Class/Content CRD 및 컨트롤러 (AWS 관리형 애드온)
resource "aws_eks_addon" "snapshot_controller" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "snapshot-controller"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # 노드 위에 스케줄링되므로 노드 그룹 이후
  depends_on = [aws_eks_node_group.main]

  tags = {
    Name        = "${local.eks_cluster_name}-snapshot-controller"
    Environment = var.environment
  }
}

# ──────────────────────────────────────────
# snapscheduler — SnapshotSchedule CRD로 주기 스냅샷 + 보존 관리
# ──────────────────────────────────────────
resource "helm_release" "snapscheduler" {
  name             = "snapscheduler"
  repository       = "https://backube.github.io/helm-charts/"
  chart            = "snapscheduler"
  version          = "3.5.0" # 차트 버전 고정
  namespace        = "backube-snapscheduler"
  create_namespace = true

  wait = true

  set {
    name  = "resources.requests.cpu"
    value = "10m"
  }
  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }
  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }

  # VolumeSnapshot CRD(snapshot-controller 애드온)가 먼저 있어야 함
  depends_on = [
    aws_eks_node_group.main,
    aws_eks_addon.snapshot_controller,
  ]
}
