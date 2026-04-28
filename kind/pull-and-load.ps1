param(
  [ValidateSet("backend", "ai", "all")]
  [string]$App = "all",
  [string]$Tag = "latest"
)

$REGION = "ap-northeast-2"
$ACCOUNT_ID = "428185450315"
$ECR_BASE = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
$CLUSTER = "dgu-cap"
$PROFILE = "dgu-cap"

$env:AWS_PROFILE = $PROFILE

Write-Host "==> ECR 로그인 중..."
aws ecr get-login-password --region $REGION |
  docker login --username AWS --password-stdin $ECR_BASE

if ($LASTEXITCODE -ne 0) {
  Write-Error "ECR 로그인 실패. aws configure --profile dgu-cap 설정을 확인하세요."
  exit 1
}

$images = if ($App -eq "all") { @("backend", "ai") } else { @($App) }

$loaded = @()

foreach ($app in $images) {
  $image = "$ECR_BASE/dgu-cap-$app`:$Tag"

  Write-Host ""
  Write-Host "==> $app 이미지 pull: $image"
  docker pull $image

  if ($LASTEXITCODE -ne 0) {
    Write-Warning "$app 이미지 pull 실패. ECR에 이미지가 없을 수 있습니다. 스킵."
    continue
  }

  Write-Host "==> $app 이미지 kind 클러스터에 로드..."
  kind load docker-image $image --name $CLUSTER
  $loaded += $app
}

Write-Host ""
Write-Host "==> RBAC 적용..."
kubectl apply -f "$PSScriptRoot\manifests\backend-rbac.yaml"

Write-Host ""
Write-Host "==> PostgreSQL 적용..."
kubectl apply -f "$PSScriptRoot\manifests\postgres.yaml"

Write-Host ""
Write-Host "==> Redis 적용..."
kubectl apply -f "$PSScriptRoot\manifests\redis.yaml"

Write-Host ""
Write-Host "==> 매니페스트 적용..."
foreach ($app in $loaded) {
  kubectl apply -f "$PSScriptRoot\manifests\$app.yaml"
}

Write-Host ""
Write-Host "==> 완료. Pod 상태 확인:"
kubectl get pods
