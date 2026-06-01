# k8s/ — GitOps 매니페스트 (ArgoCD)

ArgoCD App of Apps 패턴으로 관리되는 Kubernetes 매니페스트 디렉토리입니다.
kind(로컬)와 EKS(실전) 환경을 Kustomize overlays로 분기합니다.

---

## 디렉토리 구조

```
k8s/
├── apps/                              # ArgoCD Application CRD (App of Apps)
│   ├── root.yaml                      # 루트 앱 — k8s/apps/ 를 감시하며 하위 앱 자동 등록
│   ├── backend.yaml
│   ├── ai.yaml
│   ├── postgres.yaml
│   └── redis.yaml
└── manifests/
    ├── base/                          # 환경 공통 매니페스트
    │   ├── backend/                   # deployment, service, rbac
    │   ├── ai/                        # deployment, service
    │   ├── postgres/                  # deployment, service
    │   └── redis/                     # deployment, service
    └── overlays/
        ├── kind/                      # 로컬 kind 전용
        │   ├── backend/               # imagePullPolicy: Never 패치
        │   ├── ai/                    # imagePullPolicy: Never 패치
        │   ├── postgres/              # 패치 없음 (base 그대로)
        │   └── redis/                 # 패치 없음 (base 그대로)
        └── k8s/                       # AWS EKS 전용
            ├── backend/               # imagePullPolicy: Always 패치
            ├── ai/                    # imagePullPolicy: Always 패치
            ├── postgres/
            └── redis/
```

---

## ArgoCD 설치 및 연결 (kind 기준)

### 1. 클러스터 생성

```powershell
kind create cluster --config kind/cluster.yaml
```

### 2. ArgoCD 설치

```powershell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 모든 Pod가 Running 될 때까지 대기
kubectl get pods -n argocd -w
```

### 3. ArgoCD UI 접속

```powershell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

브라우저: `https://localhost:8080`

초기 비밀번호 확인:
```powershell
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

ID: `admin` / PW: 위 명령 결과

### 4. 루트 앱 등록 (App of Apps 시작)

```powershell
kubectl apply -f k8s/apps/root.yaml
```

이 한 줄로 ArgoCD가 `k8s/apps/` 디렉토리를 감시하기 시작하고,
`backend`, `ai`, `postgres`, `redis` Application이 자동으로 등록됩니다.

---

## GitOps 흐름

```
Git push → ArgoCD 감지 (기본 3분 폴링) → 자동 sync → 클러스터 반영
```

매니페스트를 수정하고 `main` 브랜치에 push하면 ArgoCD가 자동으로 클러스터에 적용합니다.

---

## EKS 전환 방법

`k8s/apps/` 아래 각 Application의 `path`를 변경하기만 하면 됩니다.

```yaml
# 변경 전 (kind)
path: k8s/manifests/overlays/kind/backend

# 변경 후 (EKS)
path: k8s/manifests/overlays/k8s/backend
```

변경 후 `main`에 push → ArgoCD 자동 반영.

---

## ai 모델 볼륨 백업 (EKS): EBS VolumeSnapshot

ai는 **StatefulSet + `gp3-retain`(reclaimPolicy=Retain)** 으로 배포되어 PVC가 삭제돼도 EBS 볼륨이 보존된다. 추가로 **snapscheduler**가 모델 볼륨을 주기적으로 EBS 스냅샷한다.

```
StatefulSet(ai) ── volumeClaimTemplates(model-storage, gp3-retain)
        │ 라벨 app=ai
        ▼
SnapshotSchedule(ai-model-daily) ── 매일 02:00(KST), 최근 7개 보존
        ▼
VolumeSnapshot ── VolumeSnapshotClass(ebs-snapclass, driver ebs.csi.aws.com)
        ▼
AWS EBS 스냅샷
```

- **terraform**: `gp3-retain` StorageClass, `snapshot-controller` EKS 애드온(VolumeSnapshot CRD), `snapscheduler` Helm(`snapshots.tf`).
- **k8s(eks)**: `overlays/eks/ai-backup/`(VolumeSnapshotClass + SnapshotSchedule), ArgoCD app `ai-backup`.
- **복원**: 스냅샷에서 새 PVC 생성 → `dataSource`로 `VolumeSnapshot` 지정.
- 로컬(kind)은 스냅샷/Retain 미적용(기본 SC 유지).

```bash
kubectl get volumesnapshot -n default        # 생성된 스냅샷 확인
kubectl get snapshotschedule -n default      # 스케줄 상태
```

---

## 시크릿 관리 (EKS): External Secrets + AWS Secrets Manager

EKS 환경의 시크릿은 **External Secrets Operator(ESO)** 가 **AWS Secrets Manager**에서 읽어와 K8s Secret으로 만든다. 비밀값은 git에 일절 남지 않고 Secrets Manager에만 보관되며, ESO는 IRSA로 읽기 권한만 갖는다.

```
Secrets Manager (dgu-cap/backend, dgu-cap/ai)
        │ ESO가 IRSA로 읽음
        ▼
ExternalSecret (overlays/eks/<app>) ── ClusterSecretStore(aws-secretsmanager)
        ▼
K8s Secret (backend-secret / ai-secret) 자동 생성 → Pod가 secretRef로 사용
```

### 1. ESO + IRSA 배포 (1회, terraform)

```bash
cd terraform
export AWS_PROFILE=dgu-cap
terraform apply   # external-secrets.tf (IRSA 역할 + helm_release.external_secrets)
```

### 2. Secrets Manager에 시크릿 등록 (운영자)

`dgu-cap/<app>` 이름으로 **JSON** 시크릿을 만든다. 키 이름이 그대로 Pod 환경변수가 된다.

```bash
# backend: deployment의 envFrom(backend-secret)이 쓰는 키들
aws secretsmanager create-secret --name dgu-cap/backend \
  --secret-string '{"SPRING_DATASOURCE_PASSWORD":"...","JWT_SECRET":"..."}'

# ai
aws secretsmanager create-secret --name dgu-cap/ai \
  --secret-string '{"OPENAI_API_KEY":"sk-..."}'
```

값 변경(회전)은 `aws secretsmanager put-secret-value`로 갱신하면 ESO가 `refreshInterval`(1h)마다 자동 반영한다.

### 3. 동기화

`k8s/apps/`의 `secretstore`(ClusterSecretStore) → backend/ai `ExternalSecret` 순으로 ArgoCD가 동기화하면 Secret이 자동 생성된다. 별도 수동 작업 불필요.

> 로컬(kind)은 Secrets Manager에 접근할 수 없으므로 [LOCAL_DEV.md](./LOCAL_DEV.md)의 수동 `kubectl create secret` 방식을 유지한다(ExternalSecret은 eks overlay에만 존재).

---

## (구) SealedSecrets 운영 가이드

> EKS는 위 External Secrets 방식으로 전환됨. SealedSecrets는 후속 정리 예정(컨트롤러만 설치된 상태).

평문 secret(`*/secret.yaml`)은 git에 못 올리지만, SealedSecrets로 봉인하면 안전하게 커밋할 수 있다.

### 1. controller 배포 (1회)

```bash
cd terraform
export AWS_PROFILE=dgu-cap
terraform apply -target=helm_release.sealed_secrets
```

### 2. kubeseal CLI 설치 (1회)

```bash
brew install kubeseal      # macOS / Linuxbrew
# 또는 scoop install kubeseal (Windows)
```

### 3. 시크릿 봉인

```bash
# 예: backend-secret
kubectl -n default create secret generic backend-secret \
  --from-env-file=./backend.env --dry-run=client -o yaml \
  | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets --format yaml \
  > k8s/manifests/base/backend/sealedsecret.yaml
```

평문 임시 파일(`backend.env`)은 즉시 삭제.

### 4. kustomization.yaml에 추가

각 base의 `kustomization.yaml`에 `sealedsecret.yaml`을 resources로 추가.

### 5. 봉인 키 백업

```bash
kubectl -n sealed-secrets get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml
```

이 파일은 절대 git에 커밋하지 말고 안전한 곳에 보관. 분실 시 모든 SealedSecret을 다시 봉인해야 한다.
