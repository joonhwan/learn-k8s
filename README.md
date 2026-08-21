# learn-k8s

WSL2에 직접 설치한 Docker Engine 위에서, 쿠버네티스의 개념과 실습을 같은 자리에서 익히는
학습 저장소입니다. 도구 설치부터 시작해 자기가 만든 애플리케이션을 배포하고 운영하며,
마지막에는 Helm으로 패키징하고 Argo CD로 GitOps 배포까지 진행합니다.

## 시작하기

모든 명령은 **WSL 셸 안에서** 실행합니다. Windows 터미널에서 `wsl` 을 입력해 들어간 뒤
저장소로 이동하십시오.

```bash
cd /mnt/d/workspace/prj/oss/mine/learn-k8s

# 1. 도구 설치 (최초 1회, kubectl·kind·helm·k9s·jq)
./scripts/setup-tools.sh

# 2. 첫 단계로 이동해 문서를 읽으며 실습
cd steps/00-environment
cat README.md
```

00단계 문서가 클러스터 생성까지 안내합니다. 그다음부터는 단계 번호 순서대로 진행하십시오.

## 학습 단계

| 단계 | 주제 | 도달 목표 |
|------|------|-----------|
| [00](steps/00-environment/) | 환경 구성 | 도구를 설치하고 멀티노드 클러스터를 띄운다. kubeconfig가 무엇을 가리키는지 설명한다. |
| [01](steps/01-declarative-model/) | 선언형 모델과 컨트롤 플레인 | `kubectl`이 API 서버에 보내는 요청을 관찰하고, 컨트롤러 루프가 상태를 맞추는 과정을 설명한다. |
| [02](steps/02-pod/) | Pod | Pod의 생애주기를 이해하고, Pod을 직접 만들지 않는 이유를 설명한다. |
| [03](steps/03-workloads/) | 워크로드 컨트롤러 | 자기 Go 앱을 이미지로 만들어 Deployment로 배포하고, 롤링 업데이트와 롤백을 수행한다. |
| [04](steps/04-service-dns/) | 서비스와 클러스터 DNS | Service 종류를 구분하고 Endpoints가 채워지는 과정을 확인한다. |
| [05](steps/05-ingress/) | Ingress | ingress-nginx로 호스트·경로 기반 라우팅을 구성한다. |
| [06](steps/06-config-secret/) | 설정과 비밀값 | ConfigMap과 Secret을 두 방식으로 주입하고 차이를 설명한다. |
| [07](steps/07-storage/) | 스토리지 | PV·PVC·StorageClass의 관계를 이해하고 StatefulSet에 볼륨을 붙인다. |
| [08](steps/08-health-resources/) | 헬스체크와 리소스 | 프로브 세 종류를 구분해 설정하고 requests·limits의 영향을 관찰한다. |
| [09](steps/09-operations-troubleshooting/) | 운영과 장애 진단 | 고장 난 매니페스트를 정해진 절차로 진단하고 처방한다. |
| [10](steps/10-security-basics/) | 보안 기초 | ServiceAccount와 RBAC로 권한을 최소화하고 NetworkPolicy로 통신을 제한한다. |
| [11](steps/11-helm/) | Helm | 실습 앱을 차트로 패키징하고 릴리스를 갱신·롤백한다. |
| [12](steps/12-gitops-argocd/) | GitOps (Argo CD) | Git 저장소를 단일 진실 공급원으로 삼아 배포하고 수동 변경을 감지한다. |

04단계 이후 문서는 진도가 도달할 때 작성합니다. 지금은 도달 목표와 다룰 내용만 적혀 있습니다.

## 진행 방식

각 단계 문서는 같은 순서로 짜여 있습니다.

1. **개념** — 왜 이런 것이 필요한지, 어떤 문제를 푸는지
2. **실습** — 명령과 매니페스트를 직접 실행
3. **검증** — `./verify.sh`로 실습 결과를 스스로 판정
4. **확인 질문** — 답할 수 있으면 다음 단계로

검증은 저장소 루트에서 단계 번호로도 실행할 수 있습니다.

```bash
./scripts/verify.sh 00      # 00단계 검증
./scripts/verify.sh 02 03   # 여러 단계
./scripts/verify.sh         # 사용법과 준비된 단계 목록
```

검증은 **그 단계의 실습 결과물이 클러스터에 남아 있는지**를 봅니다. 다음 단계로 넘어가며
결과물을 정리하면 앞 단계 검증은 자연히 실패하므로, 방금 마친 단계만 지정하십시오.

한 단계를 마치면 [`PROGRESS.md`](PROGRESS.md)에 완료 표시와 함께 **막혔던 지점**을
기록하십시오. 그 기록이 이후 단계 문서에 반영되고, 복습할 때도 가장 유용한 자료가 됩니다.

## 클러스터를 다루는 명령

```bash
./scripts/cluster-up.sh     # 클러스터 생성
./scripts/cluster-down.sh   # 클러스터 삭제
kubectl get nodes           # 노드 확인
k9s                         # 터미널 대시보드 (설치되어 있으면)
```

클러스터를 망가뜨렸을 때는 원인을 찾기보다 삭제하고 다시 만드는 편이 빠릅니다. 생성에
1~2분이면 충분하므로, 마음껏 망가뜨려도 됩니다. 다만 09단계 장애 진단 실습에서는 일부러
망가진 상태를 진단하는 것이 목적이므로 그때는 다시 만들지 마십시오.

## 주의할 점

Windows PATH에 제거된 Docker Desktop의 `kubectl`이 남아 있습니다. Windows 셸에서 `kubectl`을
실행하면 **명령은 성공하는데 클러스터만 보이지 않는** 상태가 됩니다. 원인을 찾기 어려운
함정이므로, 클러스터 관련 명령은 반드시 WSL 셸 안에서 실행하십시오. 00단계에서 이 잔재를
확인하고 정리합니다.
