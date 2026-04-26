# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

DGU-CAP 팀의 인프라 레포지토리입니다. AWS 위에 EKS 기반 플랫폼을 구축하는 것이 최종 목표이며, 현재는 네트워크 기초 구성 단계입니다.

- **인프라 도구:** Terraform (AWS 리소스 정의), EKS (컨테이너 오케스트레이션)
- **클라우드:** AWS (ap-northeast-2, 서울 리전)
- **현재 단계:** 네트워크 기초 구성 (VPC, Subnet, NAT Gateway)

## 디렉토리 구조

```
terraform/   # Terraform 코드 (현재: 네트워크 기초)
eks/         # 추후 EKS 관련 매니페스트/헬름 차트 추가 예정
```

## 네트워크 아키텍처

| 리소스 | 구성 |
|---|---|
| VPC | `10.0.0.0/16` |
| Public Subnet | `10.0.1.0/24` (ap-northeast-2a), `10.0.2.0/24` (ap-northeast-2c) |
| Private Subnet | `10.0.101.0/24` (ap-northeast-2a), `10.0.102.0/24` (ap-northeast-2c) |
| NAT Gateway | Public Subnet 각각 1개씩 배치 (고가용성) |

Private Subnet은 각 AZ의 NAT Gateway를 통해 외부 인터넷에 접근합니다. EKS 워커 노드는 추후 Private Subnet에 배치될 예정이며, subnet 태그(`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`)는 미리 설정되어 있습니다.

## 팀원 최초 세팅 순서

처음 레포를 클론한 경우 아래 순서로 진행합니다.

> **Bootstrap은 어드민이 최초 1회만 실행합니다. 이미 완료된 경우 1번 건너뜀.**

```bash
# 1. [어드민 1회] S3 버킷 + DynamoDB 테이블 생성
cd bootstrap
terraform init
terraform apply

# 2. [팀원 전체] 공유 backend로 초기화
cd terraform
terraform init    # S3 backend 연결됨
```

**공유 State 구성**

| 리소스 | 이름 |
|---|---|
| S3 버킷 | `dgu-cap-terraform-state` |
| DynamoDB 테이블 | `dgu-cap-terraform-locks` |

- 동시에 `terraform apply` 실행 시 DynamoDB가 Lock을 걸어 충돌 방지
- S3 버킷은 버전 관리 + 암호화 + 퍼블릭 차단 설정

## Terraform 주요 명령어

```bash
cd terraform

# 초기화 (처음 또는 provider 변경 시)
terraform init

# 변경사항 미리 확인
terraform plan

# 실제 적용
terraform apply

# 특정 리소스만 적용
terraform apply -target=aws_vpc.main

# 리소스 삭제
terraform destroy
```

## 변수 관리

- 기본값은 `variables.tf`에 정의
- 환경별 오버라이드는 `terraform.tfvars`에서 관리
- `*.auto.tfvars`는 `.gitignore`에 포함되어 있으므로 민감한 값(계정 ID 등)은 해당 파일 형식 활용

## 코드 작성 규칙

- 모든 리소스에 `Name`, `Environment` 태그 필수 부착
- 리소스 이름은 `${var.project_name}-<역할>` 형식 사용 (예: `dgu-cap-vpc`)
- 고가용성을 위해 리소스는 2개 AZ에 분산 (`count = 2` 패턴 사용)
- EKS 연동을 고려한 subnet 태그는 네트워크 생성 시점부터 포함

## Git 협업 워크플로

모든 작업은 아래 순서를 반드시 따릅니다. **이슈 없는 PR은 올리지 않습니다.**

```
이슈 생성 → 브랜치 생성 → 작업 → PR 생성 → 코드리뷰 → main 머지
```

### 브랜치 네이밍
`<type>/#<이슈번호>-<간단한-설명>`
예) `feat/#12-add-eks-cluster`, `fix/#7-subnet-cidr`

### 커밋 메시지
`<type>: <내용>` 형식 사용
예) `feat: EKS 노드 그룹 Terraform 모듈 추가`

| type | 용도 |
|---|---|
| feat | 새 기능 추가 |
| fix | 버그 수정 |
| chore | 설정, 의존성, 유지보수 |
| docs | 문서 수정 |

### 팀 공용 슬래시 커맨드 (Claude Code)

| 커맨드 | 설명 |
|---|---|
| `/new-issue` | GitHub 이슈 생성 |
| `/new-pr` | 현재 브랜치로 PR 생성 (이슈 연결 필수) |
| `/review-pr <번호>` | PR 코드리뷰 (AI 리뷰 후 GitHub에 제출) |

## CI/CD

| 워크플로 | 트리거 | 역할 |
|---|---|---|
| `terraform-ci.yml` | PR → main | fmt / validate / plan 자동 실행 후 PR에 결과 코멘트 |
| `terraform-cd.yml` | 수동 (`workflow_dispatch`) | `apply` 입력 확인 + production 환경 승인 후 적용 |

**CD 실행 방법:** Actions 탭 → Terraform Apply (CD) → Run workflow → `apply` 입력

**GitHub Secrets 필수 설정 (레포 Settings → Secrets):**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**GitHub Environment 설정 (CD 승인자 지정):**
레포 Settings → Environments → `production` → Required reviewers 추가

## 향후 작업 계획

1. **EKS 클러스터 구성** — `terraform/` 에 EKS 모듈 추가
2. **EKS 워커 노드 그룹** — Private Subnet에 Node Group 배치
3. **eks/ 디렉토리** — Kubernetes 매니페스트 또는 Helm 차트 추가
