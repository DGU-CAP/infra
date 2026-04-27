# DGU-CAP 인프라

DGU-CAP 팀의 인프라 레포지토리입니다.
AWS 위에 EKS 기반 플랫폼을 Terraform으로 관리합니다.

## 기술 스택

| 분류 | 기술 |
|---|---|
| 인프라 정의 | Terraform |
| 컨테이너 오케스트레이션 | AWS EKS (Kubernetes 1.32) |
| 클라우드 | AWS (ap-northeast-2, 서울) |
| CI/CD | GitHub Actions + ArgoCD (예정) |

## 아키텍처

```
인터넷
  │  HTTPS
  ▼
ALB (AWS Load Balancer Controller)
  │
  ▼
EKS 클러스터
├── 노드 그룹 (t3.medium × 2, Private Subnet)
├── 모니터링 서비스 파드
└── ...

네트워크
├── VPC (10.0.0.0/16)
├── Public Subnet × 2 (ap-northeast-2a, 2c)
├── Private Subnet × 2 (ap-northeast-2a, 2c)
└── NAT Gateway × 2
```

## 디렉토리 구조

```
.
├── terraform/       # AWS 인프라 정의 (VPC, EKS, IAM 등)
├── eks/             # Kubernetes 매니페스트 / Helm 차트 (예정)
├── GETTING_STARTED.md
└── EKS_ONOFF.md    # EKS 켜기/끄기 가이드 (비용 관리)
```

## 빠른 시작

처음 세팅하는 경우 [GETTING_STARTED.md](./GETTING_STARTED.md)를 참고하세요.

EKS를 켜거나 끄는 방법은 [EKS_ONOFF.md](./EKS_ONOFF.md)를 참고하세요.

## 향후 계획

- [ ] ArgoCD 설치 및 GitOps 파이프라인 구성
- [ ] GitHub Actions CI (이미지 빌드 → ECR push)
- [ ] ArgoCD CD (ECR 이미지 → EKS 자동 배포)
- [ ] 모니터링 서비스 Kubernetes 매니페스트 추가
