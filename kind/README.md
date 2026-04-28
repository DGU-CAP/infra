# 로컬 개발 환경 (kind)

백엔드 개발용 로컬 Kubernetes 클러스터 세팅 가이드입니다.

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

### 3. Prometheus 접속 (필요할 때)

```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

브라우저: `http://localhost:9090`

### 4. Grafana 접속 (필요할 때)

```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

브라우저: `http://localhost:3000` / ID: `admin` / PW: `admin`

---

## ECR 이미지 받아서 실행

팀원이 ECR에 올린 이미지를 kind 클러스터에서 실행합니다.

### 사전 조건

- kind 클러스터가 실행 중일 것 (`kubectl get nodes`)
- AWS CLI 프로필 `dgu-cap` 설정 완료 ([GETTING_STARTED.md](../GETTING_STARTED.md) 참고)

### 실행

```powershell
# PowerShell
.\kind\pull-and-load.ps1

# 특정 태그 지정 시
.\kind\pull-and-load.ps1 -Tag v1.0.0
```

```bash
# Git Bash
bash kind/pull-and-load.sh

# 특정 태그 지정 시
bash kind/pull-and-load.sh v1.0.0
```

스크립트가 하는 일:
1. ECR 로그인 (AWS 권한으로 임시 토큰 발급, 12시간 유효)
2. backend / ai 이미지 pull
3. kind 클러스터에 이미지 로드
4. Kubernetes 매니페스트 적용 (`kind/manifests/`)

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
├── manifests/
│   ├── backend.yaml                    # 백엔드 Deployment + Service
│   └── ai.yaml                         # AI Deployment + Service
└── helm-values/
    └── kube-prometheus-stack.yaml      # Prometheus + Grafana 설정 (로컬 경량화)
```
