# domain_name 변수를 설정하면 ACM 인증서가 자동 생성됩니다.
# terraform.tfvars 에서 domain_name = "monitoring.example.com" 형식으로 입력하세요.

resource "aws_acm_certificate" "main" {
  count = var.domain_name != "" ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-cert"
    Environment = var.environment
  }
}

output "acm_certificate_arn" {
  description = "ACM 인증서 ARN — Ingress 어노테이션 alb.ingress.kubernetes.io/certificate-arn 에 사용"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].arn : "도메인 미설정 (terraform.tfvars의 domain_name을 입력하세요)"
}

output "acm_dns_validation_records" {
  description = "ACM DNS 검증 레코드 — 도메인 DNS에 CNAME으로 추가 필요"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].domain_validation_options : null
}
