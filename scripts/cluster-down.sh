#!/usr/bin/env bash
#
# 학습용 kind 클러스터를 삭제합니다. 노드 컨테이너가 사라지므로 클러스터 안의 모든 것이
# 함께 없어집니다. 다시 만드는 데 1~2분이면 되므로, 망가뜨렸을 때는 원인을 찾기보다
# 지우고 다시 만드는 편이 빠릅니다.
#
#   ./scripts/cluster-down.sh
#
set -euo pipefail

CLUSTER_NAME=learn

command -v kind >/dev/null 2>&1 || { echo "kind 가 없습니다."; exit 1; }

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "클러스터 '$CLUSTER_NAME' 이 없습니다. 지울 것이 없습니다."
  exit 0
fi

kind delete cluster --name "$CLUSTER_NAME"
echo "삭제했습니다. 다시 만들려면: ./scripts/cluster-up.sh"
