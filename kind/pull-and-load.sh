#!/bin/bash
set -e

APP=${1:-all}   # backend | ai | all
TAG=${2:-latest}
REGION="ap-northeast-2"
ACCOUNT_ID="428185450315"
ECR_BASE="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
CLUSTER="dgu-cap"
export AWS_PROFILE="dgu-cap"

echo "==> ECR 로그인 중..."
aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $ECR_BASE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$APP" = "all" ]; then
  APPS="backend ai"
else
  APPS="$APP"
fi

LOADED=""

for app in $APPS; do
  IMAGE="$ECR_BASE/dgu-cap-$app:$TAG"

  echo ""
  echo "==> $app 이미지 pull: $IMAGE"
  if ! docker pull $IMAGE; then
    echo "[경고] $app 이미지 pull 실패. ECR에 이미지가 없을 수 있습니다. 스킵."
    continue
  fi

  echo "==> $app 이미지 kind 클러스터에 로드..."
  kind load docker-image $IMAGE --name $CLUSTER
  LOADED="$LOADED $app"
done

echo ""
echo "==> RBAC 적용..."
kubectl apply -f "$SCRIPT_DIR/manifests/backend-rbac.yaml"

echo ""
echo "==> 매니페스트 적용..."
for app in $LOADED; do
  kubectl apply -f "$SCRIPT_DIR/manifests/$app.yaml"
done

echo ""
echo "==> 완료. Pod 상태 확인:"
kubectl get pods
