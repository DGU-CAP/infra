# ──────────────────────────────────────────
# gp3 StorageClass (default)
# ──────────────────────────────────────────
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

# ──────────────────────────────────────────
# gp3-retain StorageClass (영속 데이터용 — PVC 삭제돼도 EBS 볼륨 보존)
# ──────────────────────────────────────────
resource "kubernetes_storage_class" "gp3_retain" {
  metadata {
    name = "gp3-retain"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain" # PVC 삭제 시 EBS 볼륨 유지 (수동 회수)
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

# ──────────────────────────────────────────
# 기존 gp2 SC에서 default 표시 제거 (drift 해소)
# ──────────────────────────────────────────
resource "kubernetes_annotations" "gp2_not_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  depends_on = [kubernetes_storage_class.gp3]
}
