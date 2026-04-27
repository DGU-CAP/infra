# EKS 켜기 / 끄기 가이드

비용 절감을 위해 사용하지 않을 때 EKS를 끄고, 필요할 때 다시 켜는 방법입니다.

## 비용 구조

| 리소스 | 시간당 | 하루 | 비고 |
|---|---|---|---|
| EKS 컨트롤 플레인 | $0.10 | ~$2.4 | 클러스터 존재만으로 과금 |
| t3.medium 노드 × 2 | $0.083 | ~$2.0 | EC2 실행 시간 과금 |
| NAT Gateway × 2 | - | ~$2.1 | **항상 켜있음 (네트워크 필수)** |

> EKS를 완전히 끄면 하루 **약 $4.4 절약** (NAT Gateway는 계속 과금)

---

## 사전 준비 (공통)

```powershell
# PowerShell
$env:AWS_PROFILE = "dgu-cap"
cd C:\Users\U\Desktop\dgu-cap\terraform
```

```bash
# Git Bash
export AWS_PROFILE=dgu-cap
cd ~/Desktop/dgu-cap/terraform
```

---

## EKS 끄기

EKS 클러스터, 노드, ALB Controller를 삭제합니다.
IAM 역할/정책과 네트워크(VPC, 서브넷 등)는 유지됩니다.

```bash
terraform destroy \
  -target=helm_release.alb_controller \
  -target=aws_eks_addon.coredns \
  -target=aws_eks_addon.kube_proxy \
  -target=aws_eks_addon.vpc_cni \
  -target=aws_eks_node_group.main \
  -target=aws_eks_cluster.main \
  -target=aws_iam_openid_connect_provider.eks \
  -target=aws_cloudwatch_log_group.eks_cluster
```

> 완료까지 약 **10~15분** 소요

---

## EKS 켜기

```bash
terraform apply
```

> 완료까지 약 **15~20분** 소요
> 클러스터 생성 → 노드 생성 → ALB Controller 설치 순서로 자동 진행

### 켜기 후 kubectl 연결

```bash
aws eks update-kubeconfig --name dgu-cap-eks --region ap-northeast-2
kubectl get nodes  # 노드 2대 Ready 확인
```

---

## 상태 확인

```bash
# EKS 클러스터 존재 여부
aws eks list-clusters --region ap-northeast-2

# 노드 상태
kubectl get nodes

# 현재 Terraform 상태
terraform state list | grep eks
```

---

## 주의사항

- **끄기 전**: 배포된 앱과 Ingress(ALB)가 있다면 먼저 `kubectl delete` 로 삭제하거나, ALB가 자동 삭제되지 않을 경우 AWS 콘솔에서 수동 삭제 필요
- **State 공유**: S3에 state가 저장되므로 한 명이 끄면 팀원 모두에게 반영됨. 끄기/켜기 전에 팀원에게 공유할 것
- **NAT Gateway**: 끄지 않음. 끄면 네트워크 재구성이 필요해 비용 대비 복잡도가 높음
