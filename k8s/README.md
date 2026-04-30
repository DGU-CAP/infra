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
