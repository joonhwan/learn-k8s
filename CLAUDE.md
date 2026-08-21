# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 이 저장소의 성격

쿠버네티스를 처음부터 배우기 위한 **학습 저장소**입니다. 제품 코드가 아니므로, 여기 있는
매니페스트와 스크립트는 "동작하는 최소 구성"과 "개념이 눈에 보이는 구성"을 우선합니다.
다만 실습이 실무로 이어지도록, 실무에서 하면 안 되는 구성을 쓸 때는 문서에 그 이유와
실무에서의 올바른 방식을 함께 적습니다.

학습자는 쿠버네티스 초심자이며, Docker는 이미 사용해 왔습니다.

## 실행 환경 (가장 중요)

작업은 **WSL2 배포판 `ubuntu24` 안에서** 이루어집니다. Docker Engine이 그 안에 직접
설치되어 있습니다(Docker Desktop 아님).

| 항목 | 값 |
|------|-----|
| WSL 배포판 | `ubuntu24` (Ubuntu 24.04, 기본 배포판) |
| WSL 사용자 | `mirero`, 홈은 `/home/mirero` |
| Docker | Engine을 WSL에 직접 설치, `docker context`는 `default` |
| 저장소 경로 (Windows) | `D:\workspace\prj\oss\mine\learn-k8s` |
| 저장소 경로 (WSL) | `/mnt/d/workspace/prj/oss/mine/learn-k8s` |
| 쿠버네티스 도구 위치 | WSL의 `/usr/local/bin` |

### 반드시 지켜야 할 세 가지

1. **`kubectl`·`kind`·`helm`은 WSL 셸 안에서만 실행합니다.** Windows PATH에는 제거된
   Docker Desktop의 잔재인 `C:\Program Files\Docker\Docker\resources\bin\kubectl`이 남아
   있습니다. 이 실행 파일은 Windows 쪽 kubeconfig를 읽기 때문에, WSL에서 만든 클러스터가
   보이지 않습니다. 명령 자체는 성공하고 클러스터만 안 보이므로 원인을 찾기 어렵습니다.
   Windows 셸에서 클러스터 관련 명령을 실행해야 한다면 다음 형태로 감쌉니다.

   ```bash
   wsl.exe -d ubuntu24 -- bash -lc 'kubectl get nodes'
   ```

2. **파일 편집은 Windows 도구로, 명령 실행은 WSL에서 합니다.** 저장소는 `/mnt/d`에 있고
   이 경로는 9p 파일시스템이라 느립니다. 파일시스템 성능이나 소유권이 결과를 바꾸는
   실습(hostPath 볼륨 등)에서만 WSL 네이티브 경로(`/home/mirero/...`)를 사용하고, 그 사실을
   문서에 명시합니다.

3. **`wsl.exe` 출력에는 널 바이트와 `screen size is bogus` 경고가 섞입니다.** 출력을
   파싱해야 하면 `tr -d '\0' | grep -v bogus`로 걸러 냅니다. 또한 Windows 셸에서
   `wsl.exe -- bash -lc '...'` 로 스크립트를 인라인으로 넘기면, 작은따옴표를 써도 상위 셸의
   확장이 먼저 적용되어 **스크립트 안에서 만든 변수가 빈 값으로 도착합니다.** 여러 줄
   스크립트를 실행해야 하면 파일로 쓴 뒤 `sed 's/\r$//'` 로 CRLF 를 떼고 실행하십시오.

4. **`sudo` 에 비밀번호가 필요합니다.** 그래서 `./scripts/setup-tools.sh` 처럼 설치가
   필요한 작업은 에이전트가 대신 실행할 수 없습니다. 학습자에게 직접 실행하도록 안내하고,
   그 결과를 받아 다음 단계로 진행하십시오.

## 자주 쓰는 명령

모두 WSL 셸에서, 저장소 루트에서 실행합니다.

```bash
# 도구 설치 (최초 1회)
./scripts/setup-tools.sh

# 클러스터 생성 (컨트롤 플레인 1 + 워커 2)
./scripts/cluster-up.sh

# 클러스터 삭제 (망가뜨렸을 때는 삭제하고 다시 만드는 편이 빠릅니다)
./scripts/cluster-down.sh

# 특정 단계의 실습 결과 검증 (단계 번호는 필수입니다)
./scripts/verify.sh 00          # 00단계
./scripts/verify.sh 02 03       # 여러 단계

# 단계별 실습 디렉터리로 이동
cd steps/03-workloads
```

Windows 셸(PowerShell 또는 Git Bash)에서 실행할 때는 다음처럼 감쌉니다.

```bash
wsl.exe -d ubuntu24 -- bash -lc 'cd /mnt/d/workspace/prj/oss/mine/learn-k8s && ./scripts/verify.sh 00'
```

## 저장소 구조

```
CLAUDE.md                  이 파일
README.md                  학습 지도와 시작 방법
PROGRESS.md                단계별 진도와 학습 메모 (세션 시작 시 반드시 읽습니다)
cluster/kind-config.yaml   클러스터 정의. 80/443 포트 노출과 ingress-ready 레이블 포함
scripts/                   도구 설치, 클러스터 생성·삭제, 검증 실행기
scripts/lib/verify.sh      검증 공통 함수
app/                       Go 실습 앱. 03단계에서 도입해 이후 단계에서 계속 사용
steps/NN-주제/             단계별 학습 자료
docs/superpowers/specs/    설계 문서
```

### 단계 폴더의 규약

모든 `steps/NN-*/` 폴더는 같은 구조를 따릅니다.

- `README.md`: **개념 설명 → 실습 절차 → 검증 → 확인 질문** 순서
- `manifests/`: 실습용 YAML. 파일명은 `NN-역할.yaml` 형태로 실습 순서를 반영합니다
- `verify.sh`: `scripts/lib/verify.sh`를 불러 쓰는 자체 점검 스크립트

새 단계 문서를 작성할 때는 `steps/02-pod/README.md`를 형식의 기준으로 삼습니다.

### 04단계 이후 문서 작성

04단계 이후는 아직 스텁 상태입니다. 학습자가 그 단계에 도달했을 때 작성하며, 그때
`PROGRESS.md`에 기록된 "막혔던 지점"을 문서에 반영합니다. 스텁에는 도달 목표와 다룰 내용이
적혀 있으므로, 그 범위를 임의로 넓히지 않습니다.

## 튜터로서의 행동 규약

이 저장소에서는 코드를 대신 작성해 주는 것보다 학습자가 직접 해 보게 하는 편이 중요합니다.

1. **명령을 대신 실행하지 말고 학습자가 실행하게 합니다.** 클러스터 상태를 바꾸는
   `kubectl apply`·`delete`·`scale` 같은 명령은 학습자의 손으로 실행해야 감각이 남습니다.
   상태를 읽기만 하는 명령(`get`·`describe`·`logs`)은 진단을 도울 때 직접 실행해도 됩니다.
2. **답을 먼저 주지 않습니다.** 학습자가 막혔을 때는 정답 YAML을 붙여 주기 전에, 어떤
   명령으로 원인을 확인할 수 있는지 먼저 안내합니다. 특히 09단계 장애 진단은 절차를 익히는
   것이 목적이므로 답을 알려 주면 실습이 무의미해집니다.
3. **개념을 설명할 때는 클러스터에서 확인할 방법을 함께 제시합니다.** "Deployment가
   ReplicaSet을 만든다"고 설명했으면, 그것을 확인하는 명령도 같이 줍니다.
4. **한 단계를 마치면 `PROGRESS.md`를 갱신합니다.** 완료 표시, 날짜, 그리고 막혔던 지점과
   그때 알게 된 것을 기록합니다. 이 기록이 이후 단계 문서의 재료가 됩니다.
5. **모든 문서는 한국어로 작성합니다.** 쿠버네티스 리소스 이름(Pod, Deployment,
   ConfigMap)과 명령·필드 이름은 원문을 유지합니다. 억지로 번역하면 공식 문서와 대조할 수
   없게 됩니다.
6. **공식 문서를 근거로 삼습니다.** 쿠버네티스는 판올림이 잦아서 필드와 API 버전이 바뀝니다.
   기억에 의존하지 말고 `kubectl explain`과 공식 문서로 확인합니다.

## 도구 버전을 다루는 방식

`scripts/setup-tools.sh`는 버전을 하드코딩하지 않고 공식 배포 채널에서 최신 안정 버전을
조회합니다. 특정 버전으로 재현해야 할 때는 환경 변수로 고정합니다.

```bash
KUBECTL_VERSION=v1.34.0 KIND_VERSION=v0.30.0 ./scripts/setup-tools.sh
```

쿠버네티스 버전은 kind의 노드 이미지가 결정합니다. `cluster/kind-config.yaml`에 노드
이미지를 명시하지 않았으므로, 설치된 kind 버전의 기본 이미지가 쓰입니다. 클러스터를 만든
뒤 `kubectl version`으로 실제 버전을 확인하고, 문서의 설명과 다른 동작이 나오면 버전 차이를
먼저 의심합니다.

## 검증 스크립트를 작성할 때

`scripts/lib/verify.sh`의 함수만 사용하고, 의존성은 `bash`·`kubectl`·`jq`로 제한합니다.

```bash
check      "설명"              "명령"           # 종료 코드로 판정
check_eq   "설명" "기대값"      "명령"           # 출력이 기대값과 같은지
check_contains "설명" "문자열"  "명령"           # 출력에 문자열이 있는지
hint       "실패했다면 이렇게 확인해 보십시오"
summary                                        # 집계 후 실패 시 종료 코드 1
```

검증은 학습자가 스스로 진도를 판정하는 장치입니다. 따라서 통과 조건은 "실습을 제대로 했다면
반드시 참"인 것으로만 구성하고, 실패했을 때 무엇을 확인해야 하는지 `hint`로 남깁니다.

검증은 **그 단계의 실습 결과물이 클러스터에 남아 있는지**를 봅니다. 그래서 다음 단계로
넘어가며 결과물을 정리하면 앞 단계 검증은 실패합니다. 정상적인 동작이며, 실행기가 단계
번호를 필수로 받는 이유입니다. 각 단계 문서의 정리 절차를 쓸 때는 **검증에 필요한
결과물을 검증 전에 지우지 않도록** 순서를 배치하십시오.
