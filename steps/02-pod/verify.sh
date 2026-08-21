#!/usr/bin/env bash
# 02단계 검증 — Pod
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/verify.sh"

require_tools kubectl jq
require_cluster

NS=learn

section "단일 컨테이너 Pod"
check_eq "web Pod 이 Running 이다" "Running" \
         "kubectl get pod web -n $NS -o jsonpath='{.status.phase}'"
hint "kubectl apply -f manifests/01-pod-simple.yaml 를 실행하십시오."

check "web Pod 에 IP 가 할당되었다" \
      "kubectl get pod web -n $NS -o jsonpath='{.status.podIP}' | grep -qE '^10\\.'"

check "web Pod 이 워커 노드에 배치되었다 (컨트롤 플레인에는 기본적으로 배치되지 않습니다)" \
      "kubectl get pod web -n $NS -o jsonpath='{.spec.nodeName}' | grep -q worker"
hint "컨트롤 플레인에는 taint 가 걸려 있어서 일반 Pod 이 가지 않습니다. 08단계에서 다룹니다."

section "컨테이너 여러 개인 Pod"
check_eq "sidecar-demo 의 컨테이너가 2개다" "2" \
         "kubectl get pod sidecar-demo -n $NS -o json | jq '.spec.containers | length'"
hint "kubectl apply -f manifests/02-pod-multi-container.yaml 를 실행하십시오."

check_eq "두 컨테이너가 모두 준비되었다" "true true" \
         "kubectl get pod sidecar-demo -n $NS -o jsonpath='{.status.containerStatuses[*].ready}'"

check "writer 가 공유 볼륨에 기록했다" \
      "kubectl exec -n $NS sidecar-demo -c reader -- test -s /shared/log.txt"
hint "reader 컨테이너에서 /shared/log.txt 가 보여야 합니다. 두 컨테이너가 같은 볼륨을 마운트했는지 확인하십시오."

check "reader 의 localhost 에서 writer 의 8081 포트가 응답한다 (네트워크 공유)" \
      "kubectl exec -n $NS sidecar-demo -c reader -- wget -qO- -T 5 localhost:8081 | grep -q writer"

check "두 컨테이너의 IP 가 같다" \
      "[ \"\$(kubectl exec -n $NS sidecar-demo -c writer -- hostname -i)\" = \"\$(kubectl exec -n $NS sidecar-demo -c reader -- hostname -i)\" ]"

section "초기화 컨테이너"
check_eq "init-demo 에 초기화 컨테이너가 있다" "1" \
         "kubectl get pod init-demo -n $NS -o json | jq '.spec.initContainers | length'"
hint "kubectl apply -f manifests/03-pod-init.yaml 를 실행하십시오."

check "초기화 컨테이너가 성공으로 끝났다" \
      "kubectl get pod init-demo -n $NS -o jsonpath='{.status.initContainerStatuses[0].state.terminated.reason}' | grep -q Completed"

check "초기화 컨테이너가 만든 파일을 주 컨테이너가 읽을 수 있다" \
      "kubectl exec -n $NS init-demo -- cat /work/prepared.txt | grep -q '초기화'"

section "정리 확인"
check "고장 낸 Pod(broken)을 정리하거나 고쳤다" \
      "! kubectl get pod broken -n $NS -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null | grep -q ImagePull"
hint "원인을 찾았다면 매니페스트를 고쳐 정상으로 만들거나 kubectl delete -f manifests/05-pod-broken.yaml 로 지우십시오."

summary
