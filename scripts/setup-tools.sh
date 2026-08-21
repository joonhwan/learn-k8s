#!/usr/bin/env bash
#
# 쿠버네티스 학습에 필요한 도구를 WSL 안에 설치합니다.
#
#   ./scripts/setup-tools.sh
#
# 이미 설치된 도구는 건너뜁니다. 다시 설치하려면 FORCE=1 을 붙이십시오.
#
#   FORCE=1 ./scripts/setup-tools.sh
#
# 버전은 하드코딩하지 않고 공식 배포 채널에서 최신 안정 버전을 조회합니다. 특정 버전으로
# 재현해야 할 때만 환경 변수로 고정하십시오.
#
#   KUBECTL_VERSION=v1.34.0 KIND_VERSION=v0.30.0 ./scripts/setup-tools.sh
#
set -euo pipefail

BIN_DIR=${BIN_DIR:-/usr/local/bin}
FORCE=${FORCE:-0}
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

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
# 사전 확인
# ---------------------------------------------------------------------------

log "환경을 확인합니다"

[ "$(uname -s)" = "Linux" ] || die "이 스크립트는 WSL(Linux) 안에서 실행해야 합니다. 현재: $(uname -s)"

case "$(uname -m)" in
  x86_64)  ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  *)       die "지원하지 않는 아키텍처입니다: $(uname -m)" ;;
esac
ok "아키텍처: $ARCH"

if ! grep -qi microsoft /proc/version 2>/dev/null; then
  warn "WSL 커널이 아닌 것 같습니다. 계속 진행하지만 문서의 설명과 다를 수 있습니다."
else
  ok "WSL 커널: $(uname -r)"
fi

command -v curl >/dev/null 2>&1 || die "curl 이 필요합니다. sudo apt-get install -y curl"

if ! docker info >/dev/null 2>&1; then
  die "Docker 에 접근할 수 없습니다.
  - 데몬이 떠 있는지: sudo systemctl status docker
  - 현재 사용자가 docker 그룹인지: id -nG
    아니라면 sudo usermod -aG docker \$USER 후 WSL 을 다시 시작하십시오(wsl --shutdown)."
fi
ok "Docker: $(docker version --format '{{.Server.Version}}')"

# sudo 권한을 미리 확보해, 설치 중간에 비밀번호를 묻느라 멈추지 않게 합니다.
if [ "$(id -u)" -ne 0 ]; then
  log "설치에 sudo 권한이 필요합니다"
  sudo -v || die "sudo 권한을 얻지 못했습니다."
  SUDO=sudo
else
  SUDO=""
fi

# ---------------------------------------------------------------------------
# 공통 함수
# ---------------------------------------------------------------------------

installed() {
  [ "$FORCE" != "1" ] && command -v "$1" >/dev/null 2>&1
}

# GitHub 의 releases/latest 는 최신 태그로 리다이렉트됩니다. API 를 쓰지 않으므로
# 호출 횟수 제한에 걸리지 않습니다.
github_latest_tag() {
  local repo="$1" location
  location=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/${repo}/releases/latest") || return 1
  printf '%s' "${location##*/}"
}

install_bin() {
  local src="$1" name="$2"
  chmod +x "$src"
  $SUDO install -m 0755 "$src" "${BIN_DIR}/${name}"
}

# ---------------------------------------------------------------------------
# jq — 검증 스크립트가 사용합니다
# ---------------------------------------------------------------------------

log "jq"
if installed jq; then
  ok "이미 설치됨: $(jq --version)"
else
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq jq
  ok "설치 완료: $(jq --version)"
fi

# ---------------------------------------------------------------------------
# kubectl — 클러스터와 대화하는 기본 도구
# ---------------------------------------------------------------------------

log "kubectl"
if installed kubectl; then
  ok "이미 설치됨: $(kubectl version --client -o json 2>/dev/null | jq -r .clientVersion.gitVersion)"
else
  KUBECTL_VERSION=${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}
  [ -n "$KUBECTL_VERSION" ] || die "kubectl 최신 버전을 조회하지 못했습니다."

  base="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}"
  curl -fsSL -o "$TMP_DIR/kubectl" "${base}/kubectl"
  curl -fsSL -o "$TMP_DIR/kubectl.sha256" "${base}/kubectl.sha256"

  # 공식 문서가 안내하는 방식대로 체크섬을 검증합니다.
  ( cd "$TMP_DIR" && echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --quiet ) \
    || die "kubectl 체크섬 검증에 실패했습니다."

  install_bin "$TMP_DIR/kubectl" kubectl
  ok "설치 완료: $KUBECTL_VERSION"
fi

# ---------------------------------------------------------------------------
# kind — Docker 컨테이너를 노드로 쓰는 클러스터
# ---------------------------------------------------------------------------

log "kind"
if installed kind; then
  ok "이미 설치됨: $(kind version)"
else
  KIND_VERSION=${KIND_VERSION:-$(github_latest_tag kubernetes-sigs/kind)}
  [ -n "$KIND_VERSION" ] || die "kind 최신 버전을 조회하지 못했습니다."

  curl -fsSL -o "$TMP_DIR/kind" \
    "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${ARCH}"
  install_bin "$TMP_DIR/kind" kind
  ok "설치 완료: $(kind version)"
fi

# ---------------------------------------------------------------------------
# helm — 11단계에서 사용합니다
# ---------------------------------------------------------------------------

log "helm"
if installed helm; then
  ok "이미 설치됨: $(helm version --short)"
else
  curl -fsSL -o "$TMP_DIR/get-helm-3" \
    https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod +x "$TMP_DIR/get-helm-3"
  if [ -n "${HELM_VERSION:-}" ]; then
    $SUDO env HELM_INSTALL_DIR="$BIN_DIR" "$TMP_DIR/get-helm-3" --version "$HELM_VERSION" --no-sudo
  else
    $SUDO env HELM_INSTALL_DIR="$BIN_DIR" "$TMP_DIR/get-helm-3" --no-sudo
  fi
  ok "설치 완료: $(helm version --short)"
fi

# ---------------------------------------------------------------------------
# k9s — 클러스터 상태를 한눈에 보는 터미널 대시보드 (필수는 아님)
# ---------------------------------------------------------------------------

log "k9s"
if installed k9s; then
  ok "이미 설치됨: $(k9s version --short 2>/dev/null | head -1)"
else
  K9S_VERSION=${K9S_VERSION:-$(github_latest_tag derailed/k9s)}
  if [ -z "$K9S_VERSION" ]; then
    warn "k9s 최신 버전을 조회하지 못했습니다. 필수 도구가 아니므로 건너뜁니다."
  else
    if curl -fsSL -o "$TMP_DIR/k9s.tar.gz" \
      "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz"
    then
      tar -xzf "$TMP_DIR/k9s.tar.gz" -C "$TMP_DIR" k9s
      install_bin "$TMP_DIR/k9s" k9s
      ok "설치 완료: $K9S_VERSION"
    else
      warn "k9s 내려받기에 실패했습니다. 필수 도구가 아니므로 건너뜁니다."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 마무리 안내
# ---------------------------------------------------------------------------

cat <<'GUIDE'

==> 설치가 끝났습니다.

실습을 훨씬 편하게 해 주는 셸 설정이 있습니다. 아래를 ~/.bashrc 에 추가하십시오.
(직접 붙여 넣는 편을 권합니다. 설치 스크립트가 셸 설정을 임의로 고치지 않습니다.)

    # kubectl 자동완성과 짧은 별칭
    source <(kubectl completion bash)
    alias k=kubectl
    complete -o default -F __start_kubectl k

    # 매니페스트 초안을 명령으로 뽑아내는 별칭 (실습에서 자주 씁니다)
    export do="--dry-run=client -o yaml"

추가한 뒤에는 **새 터미널을 여십시오.** `source ~/.bashrc` 로 적용하지 마십시오.

  starship·zoxide·mise 처럼 프롬프트를 관리하는 도구나 터미널 셸 통합을 쓰고 있으면,
  이미 초기화된 셸에서 .bashrc 를 다시 실행할 때 뒤에 오는 init 이 PROMPT_COMMAND 를
  자기 값으로 덮어씁니다. 그러면 터미널이 프롬프트 경계를 알리는 훅을 잃고, 셸은 살아
  있는데 화면이 갱신되지 않는 상태가 됩니다. Ctrl-C 도 듣지 않는 것처럼 보입니다.
  그 상태에 빠졌다면 터미널 창을 닫고 새로 열거나, `exec bash -l` 을 입력하십시오.

다음 단계:

    ./scripts/cluster-up.sh      # 클러스터 생성
    cd steps/00-environment      # 첫 단계 문서 읽기

GUIDE
