#!/usr/bin/env bash
#
# 단계별 검증 스크립트를 실행합니다.
#
#   ./scripts/verify.sh 00     # 00단계만
#   ./scripts/verify.sh 00 02  # 여러 단계
#
# 단계 번호는 반드시 지정해야 합니다. 검증은 "그 단계의 실습 결과물이 클러스터에 남아
# 있는가"를 보기 때문에, 다음 단계로 넘어가며 결과물을 정리하면 앞 단계 검증은 자연히
# 실패합니다. 그래서 전부를 한꺼번에 검증하는 것은 의미가 없습니다.
#
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_BOLD=$'\033[1m'
else
  C_RESET='' C_OK='' C_ERR='' C_BOLD=''
fi

# 단계 번호로 폴더를 찾습니다. 폴더 이름은 'NN-주제' 형식입니다.
resolve_step() {
  local n="$1" dir
  for dir in "$REPO_ROOT"/steps/"$n"-*; do
    [ -d "$dir" ] && { printf '%s' "$dir"; return 0; }
  done
  return 1
}

usage() {
  cat <<'USAGE'
사용법: ./scripts/verify.sh <단계번호> [단계번호 ...]

  예: ./scripts/verify.sh 00
      ./scripts/verify.sh 02 03

검증은 그 단계의 실습 결과물이 클러스터에 남아 있는지를 봅니다. 다음 단계로 넘어가며
결과물을 정리하면 앞 단계 검증은 실패하므로, 방금 마친 단계만 지정하십시오.

USAGE
  printf '검증 스크립트가 준비된 단계:\n'
  local dir name
  for dir in "$REPO_ROOT"/steps/*/; do
    name=$(basename "$dir")
    if [ -f "${dir}verify.sh" ]; then
      printf '  %s\n' "$name"
    else
      printf '  %s  (문서 작성 전)\n' "$name"
    fi
  done
}

collect_targets() {
  if [ $# -gt 0 ]; then
    local raw n dir
    for raw in "$@"; do
      # 한 자리로 입력해도 찾을 수 있게 두 자리로 맞춥니다.
      # 10# 을 붙이는 이유는 '08' 같은 입력이 8진수로 해석되는 것을 막기 위함입니다.
      n=$(printf '%02d' "$((10#$raw))" 2>/dev/null)
      [ -n "$n" ] || n="$raw"
      if dir=$(resolve_step "$n"); then
        printf '%s\n' "$dir"
      else
        printf '%s단계 %s 를 찾을 수 없습니다.%s\n' "$C_ERR" "$n" "$C_RESET" >&2
      fi
    done
  fi
}

if [ $# -eq 0 ]; then
  usage
  exit 0
fi

mapfile -t TARGETS < <(collect_targets "$@")

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "검증할 단계를 찾지 못했습니다." >&2
  exit 1
fi

TOTAL=0
FAILED=0

for dir in "${TARGETS[@]}"; do
  name=$(basename "$dir")
  if [ ! -f "$dir/verify.sh" ]; then
    printf '\n%s[%s]%s 검증 스크립트가 아직 없습니다 (문서 작성 전 단계).\n' \
      "$C_BOLD" "$name" "$C_RESET"
    continue
  fi

  printf '\n%s========== %s ==========%s\n' "$C_BOLD" "$name" "$C_RESET"
  TOTAL=$((TOTAL + 1))
  if ( cd "$dir" && bash ./verify.sh ); then
    :
  else
    FAILED=$((FAILED + 1))
  fi
done

printf '\n%s====================%s\n' "$C_BOLD" "$C_RESET"
if [ "$FAILED" -eq 0 ]; then
  printf '%s단계 %d개 모두 통과했습니다.%s\n' "$C_OK" "$TOTAL" "$C_RESET"
  exit 0
fi
printf '%s단계 %d개 중 %d개가 실패했습니다.%s\n' "$C_ERR" "$TOTAL" "$FAILED" "$C_RESET"
exit 1
