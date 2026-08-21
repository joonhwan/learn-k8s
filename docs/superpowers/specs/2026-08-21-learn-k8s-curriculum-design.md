# learn-k8s 학습 과정 설계

작성일: 2026-08-21

## 목적

WSL2 안에 직접 설치한 Docker Engine 위에서, 쿠버네티스의 개념 학습과 손으로 하는 실습을
같은 자리에서 병행할 수 있는 학습 환경을 만든다. 최종 목표는 자기가 만든 애플리케이션을
클러스터에 올리고 운영하며 GitOps 방식으로 배포할 수 있는 수준이다.

## 학습자의 실행 환경 (2026-08-21 실측)

| 항목 | 확인된 값 |
|------|-----------|
| WSL 배포판 | `ubuntu24` (Ubuntu 24.04.3 LTS), 기본 배포판, 실행 중 |
| 커널 | 6.6.87.2-microsoft-standard-WSL2 (x86_64) |
| WSL 사용자 | `mirero`, 홈은 `/home/mirero` |
| systemd | `/etc/wsl.conf`에서 활성화됨 |
| Docker | Engine 29.7.2를 WSL 안에 직접 설치, `docker context`는 `default`(유닉스 소켓) |
| 가용 자원 | CPU 24코어, 메모리 15GiB |
| 쿠버네티스 도구 | `kubectl`·`kind`·`minikube`·`k3d`·`helm`·`k9s` 모두 미설치 |
| 프로젝트 경로 | Windows `D:\workspace\prj\oss\mine\learn-k8s`, WSL에서는 `/mnt/d/workspace/prj/oss/mine/learn-k8s` |

### 정리해야 할 잔재

Docker Desktop을 제거했지만 두 가지가 남아 있어서 학습 중 혼란을 일으킬 수 있다.

1. Windows PATH에 `C:\Program Files\Docker\Docker\resources\bin\kubectl`이 남아 있다.
   이 실행 파일은 Windows 쪽 `%USERPROFILE%\.kube\config`를 읽으므로, WSL에서 만든 kind
   클러스터가 보이지 않는다. 명령 자체는 성공하는데 클러스터만 안 보이는 상태가 되어
   원인을 찾기 어렵다.
2. `docker-desktop` WSL 배포판이 Stopped 상태로 남아 있다.

두 잔재는 00단계에서 확인하고 정리한다.

## 결정 사항

| 축 | 결정 | 근거 |
|----|------|------|
| 클러스터 도구 | **kind** | 이미 있는 Docker Engine만으로 동작한다. 멀티노드를 YAML 한 장으로 구성할 수 있어서 노드·스케줄링·drain을 실제로 관찰할 수 있다. 생성과 삭제가 빨라 망가뜨리고 다시 만드는 학습에 적합하다. |
| 목표 수준 | **실무 배포 역량 + GitOps** | 자기 앱을 배포·노출·갱신·진단하는 데까지 가고, Helm 패키징과 Argo CD 동기화로 마무리한다. |
| 실습 앱 | **직접 만든 Go 앱** | 쿠버네티스 생태계가 Go로 만들어져 있어 이후 학습이 이어진다. 정적 바이너리라 멀티스테이지·distroless 이미지 실습에 적합하고, 프로브 실패나 무중단 갱신을 눈으로 확인할 엔드포인트를 직접 심을 수 있다. |
| 자료 형태 | **문서 + 검증 스크립트** | 단계마다 개념 문서와 실습 절차를 두고, 실습 결과를 스스로 판정하는 `verify.sh`를 붙인다. 혼자 진도를 확인할 수 있고 복습에도 재사용된다. |
| 생성 범위 | **골자 전체 + 00~03단계 상세** | 04단계 이후는 진도가 도달하는 시점에, 그동안 막혔던 지점을 반영해서 작성한다. |
| 버전 관리 | **git 저장소로 초기화** | 12단계 GitOps 실습에 Git이 필요하고, 학습 기록을 커밋으로 남기면 복습에 유리하다. |

## 커리큘럼 단계 구성

| 단계 | 주제 | 도달 목표 |
|------|------|-----------|
| 00 | 환경 구성 | 도구를 설치하고 멀티노드 kind 클러스터를 띄운다. kubeconfig가 무엇을 가리키는지 설명할 수 있다. |
| 01 | 선언형 모델과 컨트롤 플레인 | `kubectl`이 API 서버에 보내는 요청을 관찰하고, 컨트롤러 루프가 상태를 맞추는 과정을 설명할 수 있다. |
| 02 | Pod | Pod의 생애주기와 컨테이너 여러 개의 관계를 이해하고, Pod을 직접 만들지 않는 이유를 설명할 수 있다. |
| 03 | 워크로드 컨트롤러 | 자기 Go 앱을 이미지로 만들어 Deployment로 배포하고, 롤링 업데이트와 롤백을 수행할 수 있다. |
| 04 | 서비스와 클러스터 DNS | Service 종류를 구분하고 Endpoints가 어떻게 채워지는지 확인할 수 있다. |
| 05 | Ingress | ingress-nginx로 호스트·경로 기반 라우팅을 구성할 수 있다. |
| 06 | 설정과 비밀값 | ConfigMap과 Secret을 환경 변수와 볼륨 두 방식으로 주입하고 차이를 설명할 수 있다. |
| 07 | 스토리지 | PV·PVC·StorageClass의 관계를 이해하고 StatefulSet에 볼륨을 붙일 수 있다. |
| 08 | 헬스체크와 리소스 | 프로브 세 종류를 구분해 설정하고, requests·limits와 QoS 등급의 영향을 관찰할 수 있다. |
| 09 | 운영과 장애 진단 | 고장 난 매니페스트를 정해진 절차로 진단하고 대표 장애 유형을 처방할 수 있다. |
| 10 | 보안 기초 | ServiceAccount와 RBAC로 권한을 최소화하고 NetworkPolicy로 통신을 제한할 수 있다. |
| 11 | Helm | 실습 앱을 차트로 패키징하고 릴리스를 갱신·롤백할 수 있다. |
| 12 | GitOps (Argo CD) | Git 저장소를 단일 진실 공급원으로 삼아 배포하고 수동 변경을 감지할 수 있다. |

## 디렉터리 구조

```
learn-k8s/
  CLAUDE.md                    # 미래 세션용 지침: 환경 사실 + 튜터 행동 규약
  README.md                    # 학습 지도와 시작 방법
  PROGRESS.md                  # 단계별 진도와 학습 메모
  cluster/kind-config.yaml     # 컨트롤 플레인 1 + 워커 2, 80/443 포트 노출
  scripts/
    setup-tools.sh             # WSL에 kubectl·kind·helm·k9s·jq 설치
    cluster-up.sh              # 클러스터 생성
    cluster-down.sh            # 클러스터 삭제
    verify.sh                  # 단계 검증 실행기
    lib/verify.sh              # 검증 공통 함수
  app/                         # Go 실습 앱 (03단계에서 도입)
  steps/NN-주제/
    README.md                  # 개념 -> 실습 절차 -> 확인 질문
    manifests/                 # 실습용 YAML
    verify.sh                  # 실습 결과 자체 점검
  docs/superpowers/specs/      # 설계 문서
```

모든 단계 폴더가 같은 규약을 따르므로, 새 단계를 추가할 때 형식을 다시 정할 필요가 없다.

## 환경 운용 규칙

1. **`kubectl`은 WSL 셸 안에서만 실행한다.** Windows 쪽 `kubectl`은 다른 kubeconfig를
   읽으므로 클러스터가 보이지 않는다. 도구는 모두 WSL의 `/usr/local/bin`에 설치한다.
2. **파일은 `/mnt/d/...`에 두고 명령만 WSL에서 실행한다.** 편집은 Windows 도구로 하고,
   파일시스템 성능이나 권한이 결과를 바꾸는 실습(hostPath 볼륨 등)에서만 WSL 네이티브
   경로를 쓴다.
3. **kind 설정에 `extraPortMappings`를 미리 넣는다.** 05단계 Ingress 실습에서 클러스터를
   다시 만들지 않아도 되게 한다. `ingress-ready=true` 레이블도 컨트롤 플레인 노드에 미리 준다.
4. **도구 버전을 하드코딩하지 않는다.** 설치 스크립트가 공식 배포 채널에서 최신 안정
   버전을 조회한다. 재현이 필요하면 환경 변수로 버전을 고정할 수 있게 한다.

## 검증 스크립트 설계

`scripts/lib/verify.sh`가 공통 함수를 제공한다.

- `check <설명> <명령>`: 명령의 종료 코드로 통과와 실패를 판정한다.
- `check_eq <설명> <기대값> <명령>`: 명령 출력이 기대값과 같은지 비교한다.
- `check_contains <설명> <기대 문자열> <명령>`: 출력에 문자열이 있는지 확인한다.
- `hint <문장>`: 실패한 항목에 대한 다음 행동을 안내한다.
- `summary`: 통과와 실패 개수를 집계하고, 실패가 있으면 0이 아닌 코드로 끝난다.

의존성은 `bash`, `kubectl`, `jq`로 제한한다. 각 단계의 `verify.sh`는 이 라이브러리를
불러 쓰기만 하므로, 새 단계의 검증을 추가하는 부담이 작다.

## 진도 관리

`PROGRESS.md`에 단계별 상태와 학습 메모를 기록한다. 세션을 다시 시작할 때 이 파일을 읽으면
어디까지 했는지, 무엇에 막혔는지 파악할 수 있다. `CLAUDE.md`에 이 규약을 명시한다.

## 이번 작업 범위와 이후 작업

이번에 만드는 것:

- `CLAUDE.md`, `README.md`, `PROGRESS.md`, `.gitignore`
- `cluster/kind-config.yaml`, `scripts/` 전체
- 13개 단계 폴더 골격 (04~12단계는 목표와 예정 내용을 담은 스텁)
- 00~03단계의 상세 문서, 매니페스트, 검증 스크립트
- `app/`의 Go 실습 앱 (03단계에서 사용)

이후 작업: 04단계 이후의 상세 문서는 진도가 그 단계에 도달할 때 작성한다. 그때까지
`PROGRESS.md`에 쌓인 막힌 지점을 문서에 반영한다.
