#!/usr/bin/env bash
# 단계별 검증 스크립트가 공통으로 쓰는 함수 모음입니다.
#
# 사용법 (각 단계의 verify.sh 안에서):
#
#   #!/usr/bin/env bash
#   set -uo pipefail
#   source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/verify.sh"
#
#   section "노드 상태"
#   check    "노드가 3개 있다"        "[ \$(kubectl get nodes -o json | jq '.items | length') -eq 3 ]"
#   check_eq "컨텍스트가 kind-learn"  "kind-learn" "kubectl config current-context"
#   hint     "클러스터가 없다면 ./scripts/cluster-up.sh 를 실행하십시오."
#   summary
#
# 의존성은 bash, kubectl, jq 로 제한합니다.

set -uo pipefail

# ---------------------------------------------------------------------------
# 출력 서식
# ---------------------------------------------------------------------------

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  _C_RESET=$'\033[0m'
  _C_PASS=$'\033[32m'
  _C_FAIL=$'\033[31m'
  _C_DIM=$'\033[2m'
  _C_BOLD=$'\033[1m'
else
  _C_RESET='' _C_PASS='' _C_FAIL='' _C_DIM='' _C_BOLD=''
fi

_PASS_COUNT=0
_FAIL_COUNT=0
_LAST_FAILED=0
_FAILED_LIST=()

# ---------------------------------------------------------------------------
# 사전 점검
# ---------------------------------------------------------------------------

require_tools() {
  local missing=()
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    printf '%s검증을 실행할 수 없습니다.%s 다음 도구가 없습니다: %s\n' \
      "$_C_FAIL" "$_C_RESET" "${missing[*]}"
    printf '  ./scripts/setup-tools.sh 를 실행해 설치하십시오.\n'
    exit 127
  fi
}

# 클러스터에 실제로 연결되는지 확인합니다. 연결이 안 되면 이후 검사가 모두 실패하면서
# 원인을 가리므로, 여기서 먼저 끊습니다.
require_cluster() {
  if ! kubectl cluster-info >/dev/null 2>&1; then
    printf '%s클러스터에 연결할 수 없습니다.%s\n' "$_C_FAIL" "$_C_RESET"
    printf '  1. WSL 셸에서 실행하고 있는지 확인하십시오.\n'
    printf '     (Windows 쪽 kubectl 은 다른 kubeconfig 를 읽습니다)\n'
    printf '  2. 클러스터가 없다면 ./scripts/cluster-up.sh 를 실행하십시오.\n'
    printf '  3. 현재 컨텍스트: %s\n' "$(kubectl config current-context 2>&1 || echo '없음')"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# 검사 함수
# ---------------------------------------------------------------------------

_record_pass() {
  _PASS_COUNT=$((_PASS_COUNT + 1))
  _LAST_FAILED=0
  printf '  %s✓%s %s\n' "$_C_PASS" "$_C_RESET" "$1"
}

_record_fail() {
  local desc="$1" detail="${2:-}"
  _FAIL_COUNT=$((_FAIL_COUNT + 1))
  _LAST_FAILED=1
  _FAILED_LIST+=("$desc")
  printf '  %s✗%s %s\n' "$_C_FAIL" "$_C_RESET" "$desc"
  if [ -n "$detail" ]; then
    printf '%s' "$detail" | head -5 | sed "s/^/      ${_C_DIM}/;s/\$/${_C_RESET}/"
  fi
}

section() {
  printf '\n%s%s%s\n' "$_C_BOLD" "$1" "$_C_RESET"
}

# check <설명> <명령>
#   명령의 종료 코드가 0이면 통과입니다.
check() {
  local desc="$1" cmd="$2" out
  if out=$(eval "$cmd" 2>&1); then
    _record_pass "$desc"
  else
    _record_fail "$desc" "$out"
  fi
}

# check_eq <설명> <기대값> <명령>
#   명령 출력의 앞뒤 공백을 제거한 값이 기대값과 같으면 통과입니다.
check_eq() {
  local desc="$1" expected="$2" cmd="$3" out
  out=$(eval "$cmd" 2>&1)
  out="${out#"${out%%[![:space:]]*}"}"
  out="${out%"${out##*[![:space:]]}"}"
  if [ "$out" = "$expected" ]; then
    _record_pass "$desc"
  else
    _record_fail "$desc" "기대: '$expected' / 실제: '$out'"
  fi
}

# check_contains <설명> <기대 문자열> <명령>
#   명령 출력에 기대 문자열이 들어 있으면 통과입니다.
check_contains() {
  local desc="$1" needle="$2" cmd="$3" out
  out=$(eval "$cmd" 2>&1)
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    _record_pass "$desc"
  else
    _record_fail "$desc" "'$needle' 을 찾지 못했습니다. 실제 출력:
$out"
  fi
}

# check_not_contains <설명> <없어야 할 문자열> <명령>
check_not_contains() {
  local desc="$1" needle="$2" cmd="$3" out
  out=$(eval "$cmd" 2>&1)
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    _record_fail "$desc" "'$needle' 이 남아 있습니다. 실제 출력:
$out"
  else
    _record_pass "$desc"
  fi
}

# hint <문장>
#   바로 앞 검사가 실패했을 때만 출력됩니다. 다음에 무엇을 확인해야 하는지 안내합니다.
hint() {
  if [ "$_LAST_FAILED" -eq 1 ]; then
    printf '    %s→ %s%s\n' "$_C_DIM" "$1" "$_C_RESET"
  fi
}

# note <문장>
#   검사 결과와 무관하게 항상 출력되는 안내입니다.
note() {
  printf '  %s%s%s\n' "$_C_DIM" "$1" "$_C_RESET"
}

# ---------------------------------------------------------------------------
# 집계
# ---------------------------------------------------------------------------

summary() {
  local total=$((_PASS_COUNT + _FAIL_COUNT))
  printf '\n'
  if [ "$_FAIL_COUNT" -eq 0 ]; then
    printf '%s통과 %d/%d — 이 단계를 마쳤습니다.%s\n' \
      "$_C_PASS" "$_PASS_COUNT" "$total" "$_C_RESET"
    printf 'PROGRESS.md 에 완료 표시와 막혔던 지점을 기록하십시오.\n'
    return 0
  fi

  printf '%s통과 %d/%d, 실패 %d%s\n' \
    "$_C_FAIL" "$_PASS_COUNT" "$total" "$_FAIL_COUNT" "$_C_RESET"
  printf '실패한 항목:\n'
  local item
  for item in "${_FAILED_LIST[@]}"; do
    printf '  - %s\n' "$item"
  done
  return 1
}
