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

## 클러스터 삭제

```powershell
kind delete cluster --name dgu-cap
```

---

## 디렉토리 구조

```
kind/
├── cluster.yaml                        # kind 클러스터 정의 (control-plane 1 + worker 2)
└── helm-values/
    └── kube-prometheus-stack.yaml      # Prometheus + Grafana 설정 (로컬 경량화)
```
