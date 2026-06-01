# ──────────────────────────────────────────
# External Secrets Operator (ESO) + AWS Secrets Manager
# K8s Secret을 git에 두지 않고 Secrets Manager에서 주입 (IRSA 기반)
# ──────────────────────────────────────────

data "aws_caller_identity" "current" {}

# ──────────────────────────────────────────
# ESO IRSA 역할 (external-secrets 컨트롤러 SA가 빌림)
# ──────────────────────────────────────────
data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.project_name}-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json

  tags = {
    Name        = "${var.project_name}-external-secrets-role"
    Environment = var.environment
  }
}

# 최소권한: dgu-cap/* 프리픽스 시크릿만 읽기
data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*",
    ]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name        = "${var.project_name}-external-secrets-policy"
  description = "External Secrets Operator가 ${var.project_name}/* 시크릿을 읽기 위한 정책"
  policy      = data.aws_iam_policy_document.external_secrets.json

  tags = {
    Name        = "${var.project_name}-external-secrets-policy"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

# ──────────────────────────────────────────
# External Secrets Operator (Helm)
# ──────────────────────────────────────────
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.10.7" # 차트 버전 고정 (재현성)
  namespace        = "external-secrets"
  create_namespace = true

  wait = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  # 컨트롤러 SA에 IRSA 역할 ARN 주입 (SecretStore가 이 SA로 인증)
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_secrets.arn
  }

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.external_secrets,
    aws_iam_openid_connect_provider.eks,
  ]
}

output "external_secrets_role_arn" {
  description = "External Secrets Operator IRSA 역할 ARN"
  value       = aws_iam_role.external_secrets.arn
}
