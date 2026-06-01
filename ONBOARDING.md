# DGU-CAP 인프라 인수인계 (Onboarding)

DGU-CAP 팀 **infra** 레포. AWS 위에 EKS 기반 플랫폼을 Terraform(인프라) + ArgoCD GitOps(앱)로 운영한다.

- 클라우드: AWS `ap-northeast-2`(서울) / 계정 `428185450315`
- 레포: infra(이 레포) / backend / ai-module / frontend

---

## 1. 레포 구조
```
terraform/   # AWS 인프라 (VPC/EKS/ECR/IAM/ESO/스냅샷 등) — 로컬에서 직접 apply
k8s/         # ArgoCD GitOps 매니페스트 (App of Apps + Kustomize base/overlay)
  apps/                 # ArgoCD Application (root.yaml이 나머지 자동 등록)
  manifests/base        # 환경 공통
  manifests/overlays/eks, /kind   # 환경별 분기
kind/        # 로컬 개발용 kind 클러스터 + 모니터링 values
lambda/      # CI 실패 알림 Lambda (Bedrock→Slack)
bootstrap/   # S3+DynamoDB state 백엔드 (어드민 1회 생성, 완료)
```
상세: [k8s/README.md](./k8s/README.md), [EKS_ONOFF.md](./EKS_ONOFF.md)

## 2. 사전 준비
```bash
export AWS_PROFILE=dgu-cap      # AWS 자격증명 (정적 키 안 씀)
# 도구: terraform >=1.5, kubectl, helm, kustomize, gh, aws-cli
```

## 3. 인프라 올리기/내리기
EKS는 **비용 절감으로 평소엔 꺼둔다**. 켜고 끄는 절차는 [EKS_ONOFF.md](./EKS_ONOFF.md).
```bash
cd terraform
terraform plan            # 변경 확인
terraform apply           # 적용 (VPC/EKS/노드/애드온/ESO/스냅샷 등)
# kubeconfig
aws eks update-kubeconfig --name dgu-cap-eks --region ap-northeast-2
```

## 4. 시크릿 (중요) — AWS Secrets Manager + External Secrets
비밀값은 git에 없다. **Secrets Manager에 등록**하면 External Secrets Operator(ESO)가 IRSA로 읽어 K8s Secret을 만든다.
```bash
aws secretsmanager create-secret --region ap-northeast-2 --name dgu-cap/backend \
  --secret-string '{"SPRING_DATASOURCE_PASSWORD":"<DB비번>"}'
aws secretsmanager create-secret --region ap-northeast-2 --name dgu-cap/ai \
  --secret-string '{"OPENAI_API_KEY":"sk-..."}'
```
JSON 키 = Pod 환경변수명. 값 변경은 `put-secret-value` → 1시간 내 자동 반영. 상세: k8s/README "시크릿 관리".

## 5. 배포 (GitOps + 이미지 태그)
- ArgoCD가 `k8s/apps/`(App of Apps)를 감시 → main push 시 자동 sync.
- **ECR은 IMMUTABLE**. 이미지 태그는 **커밋 SHA** 사용(`:latest` 금지, EKS).
- 앱 레포 CI 계약:
  1. `docker push <ecr>/dgu-cap-<app>:<git-sha>`
  2. infra overlay에서 `kustomize edit set image <ecr>/dgu-cap-<app>=...:<git-sha>` → commit/push
  3. ArgoCD 자동 동기화 (롤백 = 이전 커밋)
- 로컬(kind)은 로컬 빌드 `:latest` + imagePullPolicy Never.

## 6. 로컬 개발 (kind)
[k8s/LOCAL_DEV.md](./k8s/LOCAL_DEV.md) 참고. kind 클러스터 + ArgoCD + 수동 `kubectl create secret`(SM 미사용).

## 7. 백업
ai 모델 볼륨은 StatefulSet + `gp3-retain`(PVC 삭제돼도 EBS 보존) + **EBS VolumeSnapshot 일 1회·7개 보존**(snapscheduler).
```bash
kubectl get volumesnapshot -n default
```

## 8. 협업 워크플로
**이슈 없는 PR 금지.** 이슈 → 브랜치(`<type>/#<이슈>-<설명>`) → PR → 리뷰 → main 머지.
커밋: `<type>: <내용>` (feat/fix/chore/docs). 슬래시 커맨드: `/new-issue`, `/new-pr`, `/review-pr`.

## 9. 최근 적용된 변경 (코드리뷰 반영)
| PR | 내용 |
|---|---|
| #56 | 시크릿 → External Secrets + Secrets Manager |
| #58 | postgres StatefulSet+PVC(데이터 손실 해결), LOKI_URL 버그, resources |
| #60 | ai StatefulSet + gp3-retain + EBS 스냅샷 백업 |
| #62 | 전 워크로드 securityContext 하드닝 (postgres는 drop ALL 제외) |
| #64 | ECR IMMUTABLE |
| #65 | 이미지 태그 SHA 전환(kustomize images) + 본 문서 |

## 10. 남은 작업 / 주의
- **CI에서 SHA 태그 push + overlay 자동 bump** 배선 (앱 레포 측) — IMMUTABLE이 의미 가지려면 필수.
- EKS API 엔드포인트 `0.0.0.0/0` → 팀 IP CIDR 제한 권장.
- ArgoCD `project: default` → 전용 AppProject로 제한 권장.
- 팀원 EKS 권한 전원 ClusterAdmin → 역할 분리(Edit/View) 권장.
- `runAsNonRoot`/`readOnlyRootFilesystem`은 이미지 non-root 지원 확인 후 추가.
- 기존 SealedSecrets 설치는 ESO 전환으로 (구) 상태 → 후속 정리.

## 11. 참고 문서
- [k8s/README.md](./k8s/README.md) — GitOps/시크릿/백업/이미지 태그
- [k8s/ARGOCD.md](./k8s/ARGOCD.md) · [k8s/LOCAL_DEV.md](./k8s/LOCAL_DEV.md)
- [EKS_ONOFF.md](./EKS_ONOFF.md) — 비용 절감 켜고 끄기
- [CLAUDE.md](./CLAUDE.md) — 프로젝트 규칙
