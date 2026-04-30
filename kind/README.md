# 로컬 개발 환경 (kind)

쿠버네티스 모니터링 서비스 개발용 로컬 클러스터 세팅 가이드입니다.

**구성:** Prometheus (메트릭 수집) + Loki (로그 수집) + Promtail (로그 전달) + 앱 Pod

> Grafana는 우리 서비스가 직접 시각화하므로 설치하지 않습니다.

---

## 사전 준비 (최초 1회)

아래 도구를 설치합니다.

```powershell
winget install Kubernetes.kind
winget install Helm.Helm
winget install Kubernetes.kubectl
```

> **helm이 인식 안 될 경우** — PowerShell을 새로 열어도 안 되면 아래 실행 후 새 창 열기
> ```powershell
> $helmExe = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\Helm.Helm_Microsoft.Winget.Source_8wekyb3d8bbwe\windows-amd64\helm.exe'
> $binDir = Join-Path $env:USERPROFILE 'bin'
> New-Item -ItemType Directory -Path $binDir -Force | Out-Null
> [System.IO.File]::WriteAllText("$binDir\helm.bat", "@echo off`r`n`"$helmExe`" %*")
> [Environment]::SetEnvironmentVariable('PATH', [Environment]::GetEnvironmentVariable('PATH','User') + ";$binDir", 'User')
> ```

---

## 클러스터 실행

### 1. 클러스터 생성

```powershell
kind create cluster --config kind/cluster.yaml
```

생성 확인:

```powershell
kubectl get nodes
```

```
NAME                    STATUS   ROLES           AGE   VERSION
dgu-cap-control-plane   Ready    control-plane   ...
dgu-cap-worker          Ready    <none>          ...
dgu-cap-worker2         Ready    <none>          ...
```

### 2. Prometheus 설치

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --values kind/helm-values/kube-prometheus-stack.yaml
```

설치 확인 (모두 Running 될 때까지 대기):

```powershell
kubectl get pods -n monitoring
```

### 3. Loki + Promtail 설치

```powershell
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki `
  --namespace monitoring `
  --values kind/helm-values/loki.yaml

helm install promtail grafana/promtail `
  --namespace monitoring `
  --values kind/helm-values/promtail.yaml
```

설치 확인:

```powershell
kubectl get pods -n monitoring
```

### 4. Prometheus 접속 (필요할 때)

```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

브라우저: `http://localhost:9090`

### 5. Loki 접속 (필요할 때)

```powershell
kubectl port-forward -n monitoring svc/loki 3100:3100
```

API: `http://localhost:3100`

---

## ECR 이미지 받아서 실행

팀원이 ECR에 올린 이미지를 kind 클러스터에서 실행합니다.

### 사전 조건

- kind 클러스터가 실행 중일 것 (`kubectl get nodes`)
- AWS CLI 프로필 `dgu-cap` 설정 완료 ([GETTING_STARTED.md](../GETTING_STARTED.md) 참고)

### 실행

```powershell
# PowerShell — 둘 다
.\kind\pull-and-load.ps1

# 백엔드만
.\kind\pull-and-load.ps1 -App backend

# AI만
.\kind\pull-and-load.ps1 -App ai

# 특정 태그 지정
.\kind\pull-and-load.ps1 -App backend -Tag v1.0.0
```

```bash
# Git Bash — 둘 다
bash kind/pull-and-load.sh

# 백엔드만
bash kind/pull-and-load.sh backend

# AI만
bash kind/pull-and-load.sh ai

# 특정 태그 지정
bash kind/pull-and-load.sh backend v1.0.0
```

스크립트가 하는 일:
1. ECR 로그인 (AWS 권한으로 임시 토큰 발급, 12시간 유효)
2. backend / ai 이미지 pull
3. kind 클러스터에 이미지 로드

> 매니페스트 배포는 ArgoCD가 자동으로 처리합니다. (`k8s/` 디렉토리 참고)

### DB 접속 정보 (백엔드 application.yaml)

```yaml
spring:
  datasource:
    url: jdbc:postgresql://postgres:5432/dgu_cap
    username: dgu_cap
    password: dgu_cap_local
```

> Pod 안에서는 `postgres` 서비스명으로 접근. 로컬 PC에서 직접 접속하려면 아래 포트포워딩 사용.

```powershell
kubectl port-forward svc/postgres 5432:5432
# 이후 jdbc:postgresql://localhost:5432/dgu_cap 으로 접속 가능
```

**Redis 접속 정보 (백엔드 application.yaml):**

```yaml
spring:
  data:
    redis:
      host: redis
      port: 6379
```

```powershell
# 로컬 PC에서 직접 접속 시
kubectl port-forward svc/redis 6379:6379
```

### Pod 접속 (포트포워딩)

```powershell
# 백엔드 (http://localhost:8080)
kubectl port-forward svc/backend 8080:8080

# AI (http://localhost:8000)
kubectl port-forward svc/ai 8000:8000
```

### 상태 확인

```powershell
kubectl get pods
kubectl logs deployment/backend
kubectl logs deployment/ai
```

---

## 클러스터 삭제

```powershell
kind delete cluster --name dgu-cap
```

---

## 디렉토리 구조

```
kind/
├── cluster.yaml                        # kind 클러스터 정의 (control-plane 1 + worker 2)
├── pull-and-load.ps1                   # ECR 이미지 pull → kind 로드 (PowerShell)
├── pull-and-load.sh                    # ECR 이미지 pull → kind 로드 (Git Bash)
└── helm-values/
    ├── kube-prometheus-stack.yaml      # Prometheus 설정 (Grafana 비활성화)
    ├── loki.yaml                       # 로그 수집 (단일 바이너리 모드)
    └── promtail.yaml                   # 로그 → Loki 전달

> K8s 매니페스트는 `k8s/` 디렉토리에서 ArgoCD가 관리합니다.
```
