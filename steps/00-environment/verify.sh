#!/usr/bin/env bash
# 00단계 검증 — 환경 구성
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/verify.sh"

require_tools kubectl kind jq docker

section "도구"
check "잡히는 kubectl 이 Windows 쪽 실행 파일이 아니다" \
      "! command -v kubectl | grep -qi '^/mnt/'"
hint "Windows 쪽 kubectl 이 먼저 잡히고 있습니다. 이 실행 파일은 다른 kubeconfig 를 읽으므로 클러스터가 보이지 않습니다. WSL 안에 설치된 것이 앞에 오도록 PATH 를 확인하십시오."
check "kind 가 설치되어 있다" "kind version"
check "helm 이 설치되어 있다" "helm version --short"
hint "11단계에서 필요합니다. ./scripts/setup-tools.sh 를 다시 실행하십시오."

require_cluster

section "컨텍스트"
check_eq "현재 컨텍스트가 kind-learn 이다" "kind-learn" \
         "kubectl config current-context"
hint "kubectl config use-context kind-learn 으로 바꾸십시오."
check "API 서버 주소가 127.0.0.1 로 시작한다 (kind 는 호스트 포트로 전달합니다)" \
      "kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | grep -q '127.0.0.1'"

section "노드"
check_eq "노드가 3개다" "3" \
         "kubectl get nodes -o json | jq '.items | length'"
hint "cluster/kind-config.yaml 은 컨트롤 플레인 1개와 워커 2개를 정의합니다. RECREATE=1 ./scripts/cluster-up.sh 로 다시 만드십시오."

check_eq "모든 노드가 Ready 다" "3" \
         "kubectl get nodes -o json | jq '[.items[] | select(.status.conditions[] | select(.type==\"Ready\" and .status==\"True\"))] | length'"
hint "워커는 CNI 가 준비된 뒤에 Ready 가 됩니다. 1분쯤 기다린 뒤 kubectl get nodes 로 다시 보십시오."

check_eq "컨트롤 플레인이 1개다" "1" \
         "kubectl get nodes -l node-role.kubernetes.io/control-plane -o json | jq '.items | length'"

check_eq "컨트롤 플레인에 ingress-ready 레이블이 있다" "1" \
         "kubectl get nodes -l ingress-ready=true -o json | jq '.items | length'"
hint "05단계 Ingress 실습에 필요합니다. kind-config.yaml 의 kubeadmConfigPatches 가 적용되었는지 확인하십시오."

section "노드의 실체"
check "노드가 Docker 컨테이너로 존재한다" \
      "docker ps --filter name=learn-control-plane --format '{{.Names}}' | grep -q learn-control-plane"
check "워커 컨테이너도 두 개 떠 있다" \
      "[ \$(docker ps --filter 'name=learn-worker' --format '{{.Names}}' | wc -l) -eq 2 ]"

section "포트 전달 (05단계 준비)"
check_contains "컨트롤 플레인의 80 포트가 호스트로 전달된다" "80/tcp" \
               "docker port learn-control-plane"
check_contains "443 포트도 전달된다" "443/tcp" \
               "docker port learn-control-plane"

section "컨트롤 플레인 부품"
check_eq "kube-system 에 정적 Pod 4종(etcd·apiserver·scheduler·controller-manager)이 있다" "4" \
         "kubectl get pods -n kube-system -o json | jq '[.items[].metadata.name | select(startswith(\"etcd-\") or startswith(\"kube-apiserver-\") or startswith(\"kube-scheduler-\") or startswith(\"kube-controller-manager-\"))] | length'"
hint "kubectl get pods -n kube-system 으로 무엇이 떠 있는지 직접 확인해 보십시오."

check "CoreDNS 가 돌고 있다 (04단계의 서비스 디스커버리에 필요합니다)" \
      "[ \$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o json | jq '[.items[] | select(.status.phase==\"Running\")] | length') -ge 1 ]"

summary
