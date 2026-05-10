# 로컬 개발 환경 전체 가이드

kind 클러스터에서 전체 앱 스택을 구동하는 순서입니다.

---

## 사전 조건

- [GETTING_STARTED.md](../GETTING_STARTED.md) 완료 (AWS 프로필 `dgu-cap`, Docker Desktop 실행 중)
- kind / kubectl / helm 설치 완료 ([kind/README.md](../kind/README.md) 사전 준비 참고)

---

## 1단계: kind 클러스터 생성

```powershell
kind create cluster --config kind/cluster.yaml
```

확인:

```powershell
kubectl get nodes
# NAME                    STATUS   ROLES           AGE
# dgu-cap-control-plane   Ready    control-plane   ...
# dgu-cap-worker          Ready    <none>          ...
# dgu-cap-worker2         Ready    <none>          ...
```

---

## 2단계: 모니터링 스택 설치

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --values kind/helm-values/kube-prometheus-stack.yaml

helm install loki grafana/loki `
  --namespace monitoring `
  --values kind/helm-values/loki.yaml

helm install promtail grafana/promtail `
  --namespace monitoring `
  --values kind/helm-values/promtail.yaml
```

모두 Running 될 때까지 대기:

```powershell
kubectl get pods -n monitoring -w
```

---

## 3단계: ArgoCD 설치

```powershell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 모두 Running 될 때까지 대기 (2~3분)
kubectl get pods -n argocd -w
```

---

## 4단계: Secret 등록 ⚠️

**Secret 파일은 gitignore 처리되어 있어 레포에 없습니다. 직접 만들어야 합니다.**

Secret 값은 팀 리더에게 문의하세요.

### backend-secret

```powershell
kubectl create secret generic backend-secret `
  --from-literal=SPRING_DATASOURCE_PASSWORD=<DB 비밀번호> `
  --from-literal=JWT_SECRET=<JWT 시크릿 키>
```

또는 파일로 만들어 적용 (커밋하지 말 것):

```yaml
# backend-secret.yaml (절대 커밋 금지)
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
type: Opaque
stringData:
  SPRING_DATASOURCE_PASSWORD: <DB 비밀번호>
  JWT_SECRET: <JWT 시크릿 키>
```

```powershell
kubectl apply -f backend-secret.yaml
```

### ai-secret

```powershell
kubectl create secret generic ai-secret `
  --from-literal=<키>=<값>
```

또는:

```yaml
# ai-secret.yaml (절대 커밋 금지)
apiVersion: v1
kind: Secret
metadata:
  name: ai-secret
type: Opaque
stringData:
  <키>: <값>
```

```powershell
kubectl apply -f ai-secret.yaml
```

> Secret 키 목록과 값은 팀 리더에게 문의하세요.

### 등록 확인

```powershell
kubectl get secrets
# NAME             TYPE     DATA
# backend-secret   Opaque   2
# ai-secret        Opaque   ...
```

---

## 5단계: ArgoCD 루트 앱 등록

```powershell
kubectl apply -f k8s/apps/root.yaml
```

30초~1분 후 확인:

```powershell
kubectl get applications -n argocd
# NAME       SYNC STATUS   HEALTH STATUS
# ai         Synced        Healthy
# backend    Synced        Healthy
# frontend   Synced        Healthy
# postgres   Synced        Healthy
# redis      Synced        Healthy
# root       Synced        Healthy
```

---

## 6단계: ECR 이미지 로드

kind는 외부 이미지를 직접 pull할 수 없어 로컬에서 이미지를 로드해야 합니다.

```powershell
# backend + ai 둘 다
.\kind\pull-and-load.ps1

# 개별 앱
.\kind\pull-and-load.ps1 -App backend
.\kind\pull-and-load.ps1 -App ai
```

> frontend 이미지 로드는 별도 진행 (아직 pull-and-load 스크립트 미지원).

---

## 7단계: 상태 확인 및 포트포워딩

```powershell
# Pod 상태
kubectl get pods

# 로그 확인
kubectl logs deployment/backend
kubectl logs deployment/ai
kubectl logs deployment/frontend

# 포트포워딩
kubectl port-forward svc/backend 8080:8080    # http://localhost:8080
kubectl port-forward svc/ai 8000:8000          # http://localhost:8000
kubectl port-forward svc/frontend 3000:3000    # http://localhost:3000

# DB 직접 접속 (필요할 때)
kubectl port-forward svc/postgres 5432:5432
kubectl port-forward svc/redis 6379:6379
```

---

## ArgoCD UI 접속 (선택)

```powershell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

브라우저: `https://localhost:8080` (보안 경고 → 고급 → 계속 진행)

초기 비밀번호:

```powershell
kubectl get secret argocd-initial-admin-secret -n argocd `
  -o jsonpath="{.data.password}" | `
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

---

## Pod가 `Pending` 또는 `CrashLoopBackOff`인 경우

```powershell
# 상태 상세 확인
kubectl describe pod <pod-name>

# 주요 원인
# - Secret 미등록: 4단계 다시 확인
# - 이미지 없음: 6단계 pull-and-load 실행
# - 이미지 태그 없음: ECR에 이미지가 push되지 않은 것 → 백엔드/AI팀에 문의
```

---

## 클러스터 삭제

```powershell
kind delete cluster --name dgu-cap
```
