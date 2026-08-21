#!/usr/bin/env bash
#
# 학습용 kind 클러스터를 만듭니다. 컨트롤 플레인 1개와 워커 2개로 구성됩니다.
#
#   ./scripts/cluster-up.sh              # 없으면 만들고, 있으면 그대로 둡니다
#   RECREATE=1 ./scripts/cluster-up.sh   # 기존 클러스터를 지우고 다시 만듭니다
#
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG="$REPO_ROOT/cluster/kind-config.yaml"
CLUSTER_NAME=learn
CONTEXT="kind-${CLUSTER_NAME}"
RECREATE=${RECREATE:-0}

if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'
  C_ERR=$'\033[31m'; C_BOLD=$'\033[1m'
else
  C_RESET='' C_OK='' C_WARN='' C_ERR='' C_BOLD=''
fi
log()  { printf '%s==>%s %s\n' "$C_BOLD" "$C_RESET" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$C_OK" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_WARN" "$C_RESET" "$*"; }
die()  { printf '%s오류:%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------

for tool in kind kubectl docker; do
  command -v "$tool" >/dev/null 2>&1 \
    || die "$tool 이 없습니다. ./scripts/setup-tools.sh 를 먼저 실행하십시오."
done

docker info >/dev/null 2>&1 || die "Docker 에 접근할 수 없습니다. sudo systemctl status docker 로 확인하십시오."

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  if [ "$RECREATE" = "1" ]; then
    log "기존 클러스터를 삭제합니다"
    kind delete cluster --name "$CLUSTER_NAME"
  else
    ok "클러스터 '$CLUSTER_NAME' 이 이미 있습니다."
    kubectl config use-context "$CONTEXT" >/dev/null
    kubectl get nodes
    printf '\n다시 만들려면: RECREATE=1 %s\n' "$0"
    exit 0
  fi
fi

# 클러스터 생성 전에 호스트 포트 충돌을 미리 확인합니다. 충돌하면 kind 가 생성 도중
# 실패하므로, 먼저 알려 주는 편이 낫습니다.
if command -v ss >/dev/null 2>&1; then
  for port in 80 443; do
    if ss -ltnH "sport = :$port" 2>/dev/null | grep -q .; then
      warn "WSL 안에서 ${port} 포트가 이미 사용 중입니다."
      warn "생성이 실패하면 cluster/kind-config.yaml 의 hostPort 를 8080·8443 으로 바꾸십시오."
    fi
  done
fi

# 노드 이미지가 아직 없으면 먼저 내려받습니다. 1.3GB 남짓이라 몇 분 걸립니다.
if ! docker images kindest/node --format '{{.ID}}' | grep -q .; then
  warn "노드 이미지가 아직 없습니다. 처음 생성은 이미지를 내려받느라 몇 분 걸립니다."
fi

# 첫 생성이 실패하면 한 번 더 시도합니다. 근거가 있는 재시도입니다.
#
# 노드 이미지를 갓 내려받은 직후에는 세 개의 노드 컨테이너를 동시에 펼치면서 디스크
# 입출력이 몰립니다. 그러면 etcd 와 API 서버의 기동이 늦어지고, kubeadm 이 API 서버를
# 기다리는 시간을 넘겨서 "failed to init node with kubeadm" 으로 끝납니다.
# 이미지가 캐시된 두 번째 시도에서는 같은 설정으로 정상 생성됩니다(실측 확인).
attempt=1
max_attempts=2
while :; do
  log "클러스터를 만듭니다 (${attempt}번째 시도, 1~3분 걸립니다)"
  if kind create cluster --config "$CONFIG" --wait 180s; then
    break
  fi

  if [ "$attempt" -ge "$max_attempts" ]; then
    die "클러스터 생성이 ${max_attempts}번 실패했습니다.
  다음을 확인하십시오.
  - 남은 컨테이너: docker ps -a | grep learn-
  - 디스크 여유:   df -h /var/lib/docker
  - 80·443 포트:   ss -ltn | grep -E ':(80|443) '
    포트가 쓰이고 있으면 cluster/kind-config.yaml 의 hostPort 를 8080·8443 으로 바꾸십시오."
  fi

  warn "첫 시도가 실패했습니다. 노드 이미지를 갓 내려받은 직후에는 입출력이 몰려"
  warn "API 서버 기동이 늦어질 수 있습니다. 이미지는 이제 캐시되었으므로 다시 시도합니다."
  kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
  attempt=$((attempt + 1))
done

kubectl config use-context "$CONTEXT" >/dev/null

log "모든 노드가 Ready 가 될 때까지 기다립니다"
# kind 의 --wait 은 컨트롤 플레인만 기다립니다. 워커는 CNI(여기서는 kindnet)가 준비된
# 뒤에야 Ready 가 되므로, 생성 직후에 노드를 보면 워커가 NotReady 로 보입니다.
kubectl wait --for=condition=Ready nodes --all --timeout=180s \
  || warn "일부 노드가 아직 Ready 가 아닙니다. kubectl get nodes 로 다시 확인하십시오."

log "노드 상태"
kubectl get nodes -o wide

log "버전"
printf '  kind:       %s\n' "$(kind version | awk '{print $2}')"
printf '  kubectl:    %s\n' "$(kubectl version --client -o json 2>/dev/null | jq -r .clientVersion.gitVersion 2>/dev/null || echo '확인 실패')"
printf '  kubernetes: %s\n' "$(kubectl version -o json 2>/dev/null | jq -r .serverVersion.gitVersion 2>/dev/null || echo '확인 실패')"
printf '  컨텍스트:   %s\n' "$(kubectl config current-context)"

cat <<GUIDE

==> 클러스터가 준비되었습니다.

노드 하나하나가 Docker 컨테이너입니다. 직접 확인해 보십시오.

    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

위에 나온 버전을 PROGRESS.md 의 '환경 기록'에 적어 두면, 나중에 문서의 설명과 동작이
다를 때 버전 차이를 먼저 의심할 수 있습니다.

GUIDE
