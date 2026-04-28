#!/bin/bash
set -e

TAG=${1:-latest}
REGION="ap-northeast-2"
ACCOUNT_ID="428185450315"
ECR_BASE="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
CLUSTER="dgu-cap"
export AWS_PROFILE="dgu-cap"

echo "==> ECR 로그인 중..."
aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $ECR_BASE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for app in backend ai; do
  IMAGE="$ECR_BASE/dgu-cap-$app:$TAG"

  echo ""
  echo "==> $app 이미지 pull: $IMAGE"
  docker pull $IMAGE || { echo "[경고] $app 이미지 pull 실패. ECR에 이미지가 없을 수 있습니다."; continue; }

  echo "==> $app 이미지 kind 클러스터에 로드..."
  kind load docker-image $IMAGE --name $CLUSTER
done

echo ""
echo "==> 매니페스트 적용..."
kubectl apply -f "$SCRIPT_DIR/manifests/"

echo ""
echo "==> 완료. Pod 상태 확인:"
kubectl get pods
