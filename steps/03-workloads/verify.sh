#!/usr/bin/env bash
# 03단계 검증 — 워크로드 컨트롤러
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/verify.sh"

require_tools kubectl jq docker kind
require_cluster

NS=learn

section "이미지 준비"
check "learn-k8s/demo:v1 이미지를 빌드했다" \
      "docker images learn-k8s/demo:v1 --format '{{.ID}}' | grep -q ."
hint "cd app && docker build -t learn-k8s/demo:v1 --build-arg VERSION=v1 ."

check "learn-k8s/demo:v2 이미지도 빌드했다 (롤링 업데이트 실습에 필요)" \
      "docker images learn-k8s/demo:v2 --format '{{.ID}}' | grep -q ."
hint "cd app && docker build -t learn-k8s/demo:v2 --build-arg VERSION=v2 ."

check "이미지를 노드에 실어 넣었다 (kind load)" \
      "docker exec learn-worker crictl images 2>/dev/null | grep -q 'learn-k8s/demo'"
hint "kind load docker-image learn-k8s/demo:v1 --name learn"

section "Deployment 계층"
check "demo Deployment 가 있다" \
      "kubectl get deployment demo -n $NS"
hint "kubectl apply -f manifests/01-deployment.yaml"

check_eq "준비된 복제본이 3개다" "3" \
         "kubectl get deployment demo -n $NS -o jsonpath='{.status.readyReplicas}'"
hint "kubectl get pods -n $NS -l app=demo 로 상태를 확인하십시오. 5로 늘렸다면 매니페스트를 다시 적용해 3으로 되돌리십시오."

check "ReplicaSet 이 Deployment 에 소유되어 있다" \
      "kubectl get rs -n $NS -l app=demo -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}' | grep -q Deployment"

check "Pod 이 ReplicaSet 에 소유되어 있다" \
      "kubectl get pods -n $NS -l app=demo -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}' | grep -q ReplicaSet"

section "롤링 업데이트를 수행했는가"
check "ReplicaSet 이 2개 이상 있다 (버전을 한 번 이상 바꾼 흔적)" \
      "[ \$(kubectl get rs -n $NS -l app=demo --no-headers | wc -l) -ge 2 ]"
hint "kubectl set image deployment/demo -n $NS demo=learn-k8s/demo:v2 를 실행해 보십시오."

check "rollout 이력이 2개 이상이다" \
      "[ \$(kubectl rollout history deployment/demo -n $NS | grep -cE '^[0-9]+') -ge 2 ]"

check "Deployment 가 완료 상태다 (진행 중이거나 멈춘 상태가 아니다)" \
      "kubectl rollout status deployment/demo -n $NS --timeout=60s"
hint "실패한 이미지로 갱신한 상태라면 kubectl rollout undo deployment/demo -n $NS 로 되돌리십시오."

section "앱이 실제로 응답하는가"
check "Pod 안에서 앱이 JSON 을 돌려준다" \
      "kubectl exec -n $NS \$(kubectl get pod -n $NS -l app=demo -o jsonpath='{.items[0].metadata.name}') -- wget -qO- -T 5 localhost:8080 | jq -e .version >/dev/null"

check "응답의 hostname 이 Pod 이름과 같다" \
      "P=\$(kubectl get pod -n $NS -l app=demo -o jsonpath='{.items[0].metadata.name}'); [ \"\$(kubectl exec -n $NS \$P -- wget -qO- -T 5 localhost:8080 | jq -r .hostname)\" = \"\$P\" ]"

check "MESSAGE 환경 변수가 주입되어 응답에 실려 온다" \
      "kubectl exec -n $NS \$(kubectl get pod -n $NS -l app=demo -o jsonpath='{.items[0].metadata.name}') -- wget -qO- -T 5 localhost:8080 | jq -e '.message | length > 0' >/dev/null"

section "두 워커에 나뉘어 배치되었는가"
check "Pod 이 두 개 이상의 노드에 퍼져 있다" \
      "[ \$(kubectl get pods -n $NS -l app=demo -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\\n' | sort -u | wc -l) -ge 2 ]"
note "스케줄러의 판단에 따라 한 노드에 모일 수도 있습니다. 실패하면 replicas 를 늘려 다시 보십시오."

summary
