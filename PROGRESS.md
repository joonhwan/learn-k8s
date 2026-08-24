# 학습 진도

각 단계를 마칠 때마다 상태를 갱신하고, **막혔던 지점**과 그때 알게 된 것을 기록합니다.
이 기록은 04단계 이후 문서를 작성할 때의 재료이자, 복습할 때 가장 먼저 읽을 자료입니다.

상태 표기: `[ ]` 시작 전 · `[~]` 진행 중 · `[x]` 완료

---

## 다음에 이어서 할 일

**마지막 작업: 2026-08-24.** 00단계를 검증까지 마쳤습니다(15/15 통과). 이제 01단계입니다.

클러스터는 살아 있는 상태였습니다. 재부팅을 겪었더라도 WSL 과 Docker 데몬이 다시 떠 있고
노드 컨테이너가 `Up` 이라면 다시 만들 필요가 없습니다. 아래 순서로 이어서 진행하십시오.

```bash
# 1. 새 터미널에서
wsl
cd /mnt/d/workspace/prj/oss/mine/learn-k8s

# 2. 클러스터가 살아 있는지 먼저 확인합니다
kubectl get nodes

# 3. 노드가 보이지 않으면(컨테이너가 Exited 상태) 다시 만듭니다. 1~2분입니다.
RECREATE=1 ./scripts/cluster-up.sh

# 4. 01단계 시작
cd steps/01-declarative-model && cat README.md
```

---

## 단계별 상태

| 상태 | 단계 | 주제 | 완료일 |
|:---:|:---:|------|--------|
| [x] | 00 | 환경 구성 | 2026-08-24 |
| [~] | 01 | 선언형 모델과 컨트롤 플레인 | |
| [ ] | 02 | Pod | |
| [ ] | 03 | 워크로드 컨트롤러 | |
| [ ] | 04 | 서비스와 클러스터 DNS | |
| [ ] | 05 | Ingress | |
| [ ] | 06 | 설정과 비밀값 | |
| [ ] | 07 | 스토리지 | |
| [ ] | 08 | 헬스체크와 리소스 | |
| [ ] | 09 | 운영과 장애 진단 | |
| [ ] | 10 | 보안 기초 | |
| [ ] | 11 | Helm | |
| [ ] | 12 | GitOps (Argo CD) | |

---

## 환경 기록

문서의 설명과 실제 동작이 어긋날 때 버전 차이를 먼저 의심할 수 있도록 기록합니다.

```
확인 날짜:  2026-08-21
kubectl:    v1.36.4          (/usr/local/bin/kubectl)
kind:       v0.32.0          (/usr/local/bin/kind)
kubernetes: v1.36.1          (kindest/node)
helm:       v3.21.4+g813176c
k9s, jq:    설치됨
```

같은 버전에서 00~03단계 문서와 검증 스크립트가 실제로 통과함을 확인했습니다
(각 15·8·12·14개 항목).

### 캐시된 것 (다시 받지 않아도 됩니다)

```
kindest/node        1.31GB   <- 클러스터 재생성이 1~2분으로 끝나는 이유
learn-k8s/demo:v1   22.5MB   <- 03단계 실습 앱
learn-k8s/demo:v2   22.5MB
```

`.bashrc` 에 셸 스니펫(자동완성, `k` 별칭, `$do`)이 적용되어 있습니다.

---

## 학습 메모

### 00단계 (2026-08-21)

**막혔던 지점 1 — 셸 설정을 적용하다 터미널이 먹통이 되었다**

`.bashrc` 에 스니펫을 붙이고 `. ~/.bashrc` 를 실행하니 프롬프트가 돌아오지 않았고
Ctrl+C 도 듣지 않았다.

- 원인은 붙인 스니펫이 아니었다. `.bashrc` 를 **이미 초기화된 셸에서 다시 실행한 것**
  자체가 문제였다. starship·zoxide 의 init 이 `PROMPT_COMMAND` 를 자기 값으로 덮어써서,
  터미널 셸 통합 훅(`__it_shellinteg_prompt`)이 밀려났다. 그 훅은 터미널에게 프롬프트의
  시작과 끝을 알려 주는 역할이라, 빠지면 터미널이 화면을 갱신하지 않는다.
- 진단의 갈림길은 **자식 프로세스의 유무**였다. 셸에 자식이 하나도 없고 상태가
  `S+`·`do_select` 라면 어떤 명령이 실행 중인 것이 아니라 입력을 기다리는 정상 상태다.
  그러면 `.bashrc` 내용을 뒤질 것이 아니라 화면과 입력 전달을 의심해야 한다.
- 해결: 터미널 창을 닫고 새로 열었다. 파일 자체는 멀쩡하므로 새 셸은 정상이다.
- 교훈: **셸 설정을 고친 뒤에는 `source` 하지 말고 새 터미널을 연다.**

**막혔던 지점 2 — 첫 클러스터 생성이 실패할 수 있다**

`cluster-up.sh` 가 첫 시도에 실패하고 두 번째에 성공하도록 만들어져 있다. 노드 이미지를 갓
내려받은 직후에 세 노드를 동시에 펼치면 디스크 입출력이 몰려 etcd 와 API 서버의 기동이
늦어지고, `kubeadm` 이 기다리는 시간을 넘기기 때문이다. **쿠버네티스의 기동에는 순서가
있다**는 사실을 기억해 둘 것. etcd → API 서버 → 나머지. 09단계 진단에서 이 순서가 판단
기준이 된다.

**알게 된 것 — 클러스터는 일회용이다**

노드 컨테이너의 재시작 정책이 `on-failure` 라서 PC를 껐다 켜면 클러스터가 자동으로
살아나지 않는다. `docker start` 로 되살리는 것도 권하지 않는다. API 서버 인증서와 etcd 가
컨테이너의 **원래 IP** 를 자기 신원으로 쓰는데, Docker 는 시작 순서에 따라 IP 를 다시
배정하기 때문이다.

그래서 재부팅 뒤에는 그냥 다시 만든다. 실습 결과물은 매니페스트 파일에 있으므로
`kubectl apply -f` 로 복원된다. **클러스터를 언제든 버릴 수 있다**는 것이 선언형 모델의
이점이고, 01단계에서 이 성질을 개념으로 다룬다.

### 00단계 마무리 (2026-08-24)

**알게 된 것 — 아래층과 위층을 구분한다**

재부팅 뒤의 복구는 두 층으로 나뉜다.

- **아래층(WSL 배포판과 Docker 데몬):** `wsl docker ps` 처럼 아무 명령이나 한 번 실행하면
  배포판이 깨어나고 `docker.service` 도 함께 뜬다. 손댈 것이 없다.
- **위층(노드 컨테이너 세 개):** 재시작 정책이 `on-failure` 라서 `Exited` 로 남는다.
  `docker start` 로 되살리지 않고 `RECREATE=1 ./scripts/cluster-up.sh` 로 다시 만든다.

되살리지 않는 근거를 눈으로 확인하는 방법도 알았다. API 서버 인증서의 SAN 에 컨테이너의
IP 주소가 박혀 있다.

```bash
docker exec learn-control-plane   openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"
```

**막혔던 지점 3 — Windows 쪽 kubectl 의 오류가 엉뚱한 곳을 가리킨다**

PowerShell 에서 `kubectl get nodes` 를 실행하니 이런 결과가 나왔다.

```
Error from server (NotFound): the server could not find the requested resource
$ kubectl config current-context
error: current-context is not set
```

- context 가 설정되어 있지 않으면 `kubectl` 은 기본값 `http://localhost:8080` 으로 붙는다.
  그 포트에 떠 있던 **쿠버네티스와 무관한 프로그램**이 404 를 돌려주었고, 그것이
  `NotFound` 로 표시된 것이다.
- 위험한 지점은 여기다. `connection refused` 나 `Unauthorized` 가 아니라 `NotFound` 이므로,
  리소스 종류·네임스페이스·API 버전을 의심하게 된다. 진짜 원인은 훨씬 앞단, 즉 **애초에
  다른 상대에게 말을 걸고 있다**는 사실이다.
- 교훈: 진단의 0번 단계는 **"나는 지금 어디에 말을 걸고 있는가"** 다.

```bash
kubectl config current-context
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'; echo
```

**알게 된 것 — 정적 Pod 은 닭과 달걀을 끊는 장치다**

일반적인 Pod 은 API 서버 → etcd → 스케줄러 → kubelet 순서로 만들어진다. 그런데 이 경로로
API 서버를 띄우려면 API 서버가 이미 있어야 하고, etcd 를 띄우려면 etcd 에 저장해야 한다.
순환에 빠진다.

kubelet 은 API 서버를 지켜보는 일 외에 **디스크의 특정 디렉터리를 직접 감시**하는 기능도
갖고 있다. 그 경로를 지정하는 설정이 `staticPodPath`(kind 노드에서는
`/etc/kubernetes/manifests`)다. 파일만 놓아 두면 kubelet 이 API 서버 없이 컨테이너를
띄우므로 최초 기동이 가능해진다. 스케줄러가 관여하지 않으니 **파일의 위치가 곧 배치**다.

정적 Pod 을 알아보는 두 가지 특징:

```bash
# 소유자가 ReplicaSet 이 아니라 Node 다 (kubelet 이 사후 보고한 미러 Pod)
kubectl get pods -n kube-system kube-apiserver-learn-control-plane   -o jsonpath='{.metadata.ownerReferences[0].kind}{"
"}'
```

그리고 `kubectl delete` 로 지워도 다시 살아난다. 삭제는 API 서버의 사본에만 닿고 실체인
파일은 그대로이기 때문이다. 진짜로 멈추려면 파일을 옮겨야 하는데, 그 방법이 09단계에서
의도적으로 고장을 낼 때 쓰인다.

### 01단계 진입 전 개념 문답 (2026-08-24)

01단계 실습을 시작하기 전에 나온 질문과 답이다. 01단계 5번 실습이 이 내용을 손으로 확인
하는 절차이므로, 실습할 때 다시 대조해 볼 것.

**질문 — `kubectl apply` 는 시스템의 Docker 컨테이너들을 변경하는 것인가?**

아니다. `apply` 는 **컨테이너를 하나도 건드리지 않는다.** API 서버에 HTTP 요청을 보내고,
API 서버가 그 내용을 etcd 에 적으면 끝이다. 응답을 받은 `kubectl` 은 종료한다. 이 시점까지
컨테이너는 만들어지지 않았고, 바뀐 것은 etcd 에 적힌 글뿐이다.

컨테이너는 그 뒤에 별개로 만들어진다.

```
etcd 에 새 글이 적혔다
   → 스케줄러가 발견하고 "learn-worker 에 두자"고 결정해 다시 적는다
   → learn-worker 의 kubelet 이 자기 몫을 발견하고 그 노드에서 컨테이너를 띄운다
```

각 부품이 API 서버를 지켜보다가 자기 할 일을 스스로 찾아서 한다. `kubectl` 은 이 과정에
참여하지 않는다. `apply` 직후에 보이는 `Pending` 상태가 그 간격의 증거다.

```bash
kubectl get pods -w
```

**질문에 딸린 오해 — 컨테이너는 두 층으로 있다**

- **노드 컨테이너 세 개**(`learn-control-plane`, `learn-worker`, `learn-worker2`): 호스트의
  Docker 가 관리하고 `docker ps` 에 보인다. kind 가 만든 것이며, 쿠버네티스는 이것들을
  만들지도 지우지도 않는다. 쿠버네티스에게는 "노드"라는 하드웨어에 해당한다.
- **워크로드 컨테이너**: `apply` 로 띄우는 Pod 의 컨테이너다. 노드 컨테이너 **안에서** 그
  안의 containerd 가 만든다.

그래서 Pod 을 띄워도 호스트의 `docker ps` 에는 나타나지 않는다. 보려면 노드 안으로 들어
가야 한다.

```bash
docker exec learn-worker crictl ps
```

**이 구분이 09단계에서 쓰이는 이유**

Pod 이 뜨지 않을 때 물어야 할 것은 "어느 단계에서 멈췄는가"이고, 그 단계가 위의 세 개다.
etcd 에 적혔는가 → 노드가 배정되었는가 → kubelet 이 띄웠는가. 단계마다 확인하는 명령이
다르다.

---

## 기록 형식 참고

<!--
### NN단계 (YYYY-MM-DD)

- 막혔던 지점:
- 원인:
- 알게 된 것:
-->
