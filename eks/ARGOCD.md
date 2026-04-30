# ArgoCD GitOps 연습 가이드

kind 클러스터에서 ArgoCD를 설치하고 GitOps 흐름을 체험하는 가이드입니다.

---

## 사전 조건

- kind 클러스터(`dgu-cap`)가 실행 중일 것
- kubectl 컨텍스트가 `kind-dgu-cap`으로 설정되어 있을 것

```powershell
# 클러스터 확인
kubectl get nodes

# 컨텍스트 확인 및 전환
kubectl config get-contexts
kubectl config use-context kind-dgu-cap
```

---

## 1. ArgoCD 설치

```powershell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

모든 Pod가 Running 될 때까지 대기 (2~3분):

```powershell
kubectl get pods -n argocd -w
```

아래처럼 모두 `1/1 Running` 이 되면 완료:

```
NAME                                                READY   STATUS    RESTARTS
argocd-application-controller-0                     1/1     Running   0
argocd-applicationset-controller-xxx                1/1     Running   0
argocd-dex-server-xxx                               1/1     Running   0
argocd-notifications-controller-xxx                 1/1     Running   0
argocd-redis-xxx                                    1/1     Running   0
argocd-repo-server-xxx                              1/1     Running   0
argocd-server-xxx                                   1/1     Running   0
```

---

## 2. ArgoCD UI 접속

```powershell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

브라우저에서 `https://localhost:8080` 접속 (보안 경고 → 고급 → 계속 진행)

### 초기 비밀번호 확인

**PowerShell:**
```powershell
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**Git Bash:**
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

- ID: `admin`
- PW: 위 명령어 출력 결과

---

## 3. GitOps 시작 — 루트 앱 등록

레포 루트에서 아래 명령어 한 줄로 GitOps가 시작됩니다.

```powershell
kubectl apply -f eks/apps/root.yaml
```

### 이 명령어가 하는 일

```
root 앱 등록
  └─ eks/apps/ 디렉토리 감시 시작
       ├─ backend.yaml 감지 → backend 앱 자동 등록
       ├─ ai.yaml 감지     → ai 앱 자동 등록
       ├─ postgres.yaml 감지 → postgres 앱 자동 등록
       └─ redis.yaml 감지  → redis 앱 자동 등록
```

등록 확인:

```powershell
kubectl get applications -n argocd
```

```
NAME       SYNC STATUS   HEALTH STATUS
ai         Synced        Healthy
backend    Synced        Healthy
postgres   Synced        Healthy
redis      Synced        Healthy
root       Synced        Healthy
```

---

## 4. GitOps 흐름 체험

**Git push 한 번으로 클러스터가 자동으로 바뀌는 걸 직접 체험해보세요.**

### 예시: backend replicas 변경

1. `eks/manifests/base/backend/deployment.yaml` 열기
2. `replicas: 1` → `replicas: 2` 로 변경
3. 커밋 & push:

```powershell
git add eks/manifests/base/backend/deployment.yaml
git commit -m "test: backend replicas 2로 변경"
git push
```

4. ArgoCD UI에서 `backend` 앱이 `OutOfSync` → `Synced` 로 자동 변경되는 것 확인
5. Pod 확인:

```powershell
kubectl get pods -l app=backend
# backend Pod가 2개로 늘어난 것 확인
```

> ArgoCD는 기본적으로 **3분마다** Git을 폴링합니다. 즉시 반영하려면 UI에서 `Sync` 버튼 클릭.

---

## 5. EKS 전환 방법

kind에서 EKS로 전환할 때는 `eks/apps/` 아래 각 Application의 `path`만 바꾸면 됩니다.

```yaml
# 변경 전 (kind — imagePullPolicy: Never)
path: eks/manifests/overlays/kind/backend

# 변경 후 (EKS — imagePullPolicy: Always)
path: eks/manifests/overlays/eks/backend
```

변경 후 `main`에 push → ArgoCD 자동 반영.

---

## 구조 한눈에 보기

```
eks/
├── apps/                        # ArgoCD Application 정의
│   ├── root.yaml                # 루트 앱 (하위 앱 자동 등록)
│   ├── backend.yaml
│   ├── ai.yaml
│   ├── postgres.yaml
│   └── redis.yaml
└── manifests/
    ├── base/                    # 공통 매니페스트 (이미지, 환경변수 등)
    └── overlays/
        ├── kind/                # kind 전용 (imagePullPolicy: Never)
        └── eks/                 # EKS 전용 (imagePullPolicy: Always)
```

---

## 자주 쓰는 명령어

```powershell
# ArgoCD 앱 상태 확인
kubectl get applications -n argocd

# 특정 앱 상세 확인
kubectl describe application backend -n argocd

# 수동 sync (3분 기다리기 싫을 때)
kubectl -n argocd patch application backend -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' --type merge

# ArgoCD UI 포트포워딩
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
