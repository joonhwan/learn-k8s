#!/usr/bin/env bash
# 01단계 검증 — 선언형 모델과 컨트롤 플레인
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/verify.sh"

require_tools kubectl jq
require_cluster

section "실습 결과물"
check "learn 이름공간을 만들었다" \
      "kubectl get namespace learn"
hint "kubectl apply -f manifests/01-namespace.yaml 를 실행하십시오."

check_eq "learn 이름공간에 purpose=learning 레이블이 있다" "learning" \
         "kubectl get namespace learn -o jsonpath='{.metadata.labels.purpose}'"

section "API 를 직접 다뤄 보았는가"
check "API 서버가 REST 로 응답한다 (kubectl get --raw)" \
      "kubectl get --raw /api/v1/nodes | jq -e '.items | length >= 3' >/dev/null"

check "api-resources 로 리소스 종류를 조회할 수 있다" \
      "[ \$(kubectl api-resources --no-headers 2>/dev/null | wc -l) -gt 30 ]"

check "explain 이 실제 API 구조를 보여 준다" \
      "kubectl explain pod.spec.containers.livenessProbe | grep -q 'httpGet'"

section "오브젝트의 구조를 확인했는가"
check "노드의 status 에 conditions 가 있다 (시스템이 쓴 현실)" \
      "kubectl get node learn-worker -o jsonpath='{.status.conditions[*].type}' | grep -q Ready"

check "노드의 spec 에 podCIDR 이 있다 (사람·컨트롤러가 정한 바람)" \
      "kubectl get node learn-worker -o jsonpath='{.spec.podCIDR}' | grep -q '10.244'"

section "컨트롤 플레인이 남긴 기록"
check "컨트롤러 매니저가 돌고 있다 (조정 루프를 실제로 수행하는 부품)" \
      "kubectl get pods -n kube-system -l component=kube-controller-manager -o json | jq -e '[.items[] | select(.status.phase==\"Running\")] | length >= 1' >/dev/null"
note "events 는 기본적으로 한 시간쯤 지나면 사라집니다. 지금 비어 있어도 정상입니다."

summary
