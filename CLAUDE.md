# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

DGU-CAP 팀의 인프라 레포지토리입니다. AWS 위에 EKS 기반 플랫폼을 구축합니다.

- **인프라 도구:** Terraform (AWS 리소스), Helm (Kubernetes 패키지)
- **클라우드:** AWS ap-northeast-2 (서울)
- **레포 구성:** infra(이 레포) / backend / ai-module / frontend(미정)

## 디렉토리 구조

```
terraform/   # AWS 인프라 (VPC, EKS, ECR, IAM 등)
kind/        # 로컬 개발용 Kubernetes 클러스터 (kind + Prometheus/Grafana)
k8s/         # Kubernetes 매니페스트 (ArgoCD GitOps 관리, kind/EKS 공용)
bootstrap/   # S3 + DynamoDB 백엔드 초기 생성 (어드민 1회 완료)
```

## 현재 인프라 상태

| 리소스 | 상태 |
|---|---|
| VPC / Subnet / NAT Gateway(1개) | 운영 중 |
| EKS 클러스터 + 노드 그룹 | 비용 절감으로 평소엔 끔 ([EKS_ONOFF.md](./EKS_ONOFF.md)) |
| ECR (backend / frontend / ai) | 운영 중 |
| ALB Controller | EKS 올릴 때 함께 적용 |
| Terraform State | S3 `dgu-cap-terraform-state` + DynamoDB Lock |

## 네트워크 아키텍처

| 리소스 | 구성 |
|---|---|
| VPC | `10.0.0.0/16` |
| Public Subnet | `10.0.1.0/24` (2a), `10.0.2.0/24` (2c) |
| Private Subnet | `10.0.101.0/24` (2a), `10.0.102.0/24` (2c) |
| NAT Gateway | Public Subnet에 1개 (dev 비용 절감) |

EKS 워커 노드는 Private Subnet에 배치. subnet 태그(`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`) 설정 완료.

## Terraform 운영 방식

CI/CD 없이 **로컬에서 직접 실행**. 팀 리더가 주로 실행.

```bash
cd terraform
export AWS_PROFILE=dgu-cap

terraform plan      # 변경사항 확인
terraform apply     # 적용
terraform destroy -target=<리소스>  # 특정 리소스만 삭제
```

- 기본값: `variables.tf` / 환경 오버라이드: `terraform.tfvars`
- 민감한 값은 `*.auto.tfvars` 사용 (gitignore 처리됨)

## 코드 작성 규칙

- 모든 리소스에 `Name`, `Environment` 태그 필수
- 리소스 이름: `${var.project_name}-<역할>` (예: `dgu-cap-vpc`)
- 가용성 분산: 2개 AZ 사용

## Git 협업 워크플로

**이슈 없는 PR은 올리지 않습니다.**

```
이슈 생성 → 브랜치 생성 → 작업 → PR → 코드리뷰 → main 머지
```

브랜치: `<type>/#<이슈번호>-<설명>` (예: `feat/#12-add-argocd`)

커밋: `<type>: <내용>` — type: `feat` / `fix` / `chore` / `docs`

### Claude Code 슬래시 커맨드

| 커맨드 | 설명 |
|---|---|
| `/new-issue` | GitHub 이슈 생성 |
| `/new-pr` | PR 생성 (이슈 연결 필수) |
| `/review-pr <번호>` | PR 코드리뷰 |

## 다음 작업

1. **GitHub Actions** — backend/ai-module 레포에 ECR push 워크플로 추가 (각 팀이 코드 준비 후)
2. **ArgoCD** — EKS 위에 설치, GitOps CD 구성
3. **k8s/ 디렉토리** — Kubernetes 매니페스트 작성 (Deployment, Service, Ingress)
