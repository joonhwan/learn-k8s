# 학습 진도

각 단계를 마칠 때마다 상태를 갱신하고, **막혔던 지점**과 그때 알게 된 것을 기록합니다.
이 기록은 04단계 이후 문서를 작성할 때의 재료이자, 복습할 때 가장 먼저 읽을 자료입니다.

상태 표기: `[ ]` 시작 전 · `[~]` 진행 중 · `[x]` 완료

---

## 다음에 이어서 할 일

**마지막 작업: 2026-08-28.** 02단계를 검증까지 마쳤습니다(12/12). 이제 03단계입니다.

```bash
# 1. 새 터미널에서
wsl
cd /mnt/d/workspace/prj/oss/mine/learn-k8s

# 2. 클러스터가 살아 있는지 먼저 확인합니다
kubectl get nodes

# 3. 노드가 보이지 않으면(컨테이너가 Exited 상태) 다시 만듭니다. 1~2분입니다.
RECREATE=1 ./scripts/cluster-up.sh

# 4. 클러스터를 다시 만들었다면 이름공간부터 복원합니다.
#    kubectl get pods -n learn 은 이름공간이 없어도 "No resources found" 를 내므로
#    존재 확인은 get ns 로 합니다.
kubectl get ns learn || kubectl apply -f steps/01-declarative-model/manifests/

# 5. 02단계 결과물을 정리합니다 (검증을 이미 통과했습니다)
kubectl delete -f steps/02-pod/manifests/ --ignore-not-found

# 6. 03단계 시작
cd steps/03-workloads && cat README.md
```

**03단계의 이미지 준비:** 호스트 Docker 에는 `learn-k8s/demo:v1`·`:v2` 가 남아 있으므로
실습 1(`docker build`)은 건너뛰어도 됩니다. 다만 클러스터를 다시 만들었다면 **노드 안에는
없으므로** 실습 2의 `kind load` 는 반드시 해야 합니다. 확인 방법입니다.

```bash
docker images | grep demo                              # 호스트에 있는가
docker exec learn-worker crictl images | grep demo     # 노드 안에 있는가
```

---

## 단계별 상태

| 상태 | 단계 | 주제 | 완료일 |
|:---:|:---:|------|--------|
| [x] | 00 | 환경 구성 | 2026-08-24 |
| [x] | 01 | 선언형 모델과 컨트롤 플레인 | 2026-08-27 |
| [x] | 02 | Pod | 2026-08-28 |
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

### 01단계 (2026-08-27)

**막혔던 지점 1 — 튜터가 명령만 늘어놓아서 의미를 알 수 없었다**

실습 1~3(REST 요청 들여다보기, 리소스 목록, `explain`)을 진행하는 동안 "명령을 실행하고
출력을 붙여 넣는" 왕복이 반복되었는데, 그 명령이 무엇을 위한 것인지 알 수 없었다. 원인은
명령을 주기 전에 **목적을 말하지 않은 것**이었다. 게다가 짚어 준 내용이 10단계·12단계에서야
쓰일 이야기여서 지금 와닿을 수가 없었다.

이 단계에서 실제로 손에 남아야 하는 것은 실습 5번 하나였다. 나머지는 "등록이라는 것이 알고
보면 평범한 HTTP 요청이더라"를 확인하는 곁가지다.

- 교훈: **무엇을 위해 이 명령을 치는지 먼저 듣고 시작한다.** 목적이 없는 명령은 진도가
  아니라 타이핑이다.

**막혔던 지점 2 — README 의 grep 패턴이 아무것도 잡지 못했다**

`kubectl -v=8 get nodes 2>&1 | grep -E 'GET|Response Status'` 가 요청 줄만 내놓고 응답 줄은
하나도 내놓지 않았다. 실습이 실패한 것이 아니라 **로그 형식이 판올림으로 바뀐 것**이었다.
v1.36 이전에는 `Response Status: 200 OK in 3 ms` 라는 평문이었지만 지금은
`"Response" status="200 OK"` 라는 구조화된 형식이다. README 를 고쳐 두었다.

- 교훈: grep 이 침묵하면 패턴을 의심하기 전에 `grep -i 응답어` 로 **실제로 무엇이 찍히는지**
  먼저 본다.

**알게 된 것 — 표를 만드는 주체는 kubectl 이 아니라 API 서버다**

`-v=8` 의 응답 본문 첫머리가 `{"kind":"Table","apiVersion":"meta.k8s.io/v1",...}` 였다.
`NAME STATUS ROLES AGE` 라는 열 구성과 각 열의 설명문까지 서버가 만들어서 보낸다. `kubectl`
은 요청 헤더에 `Accept: application/json;as=Table;v=1;g=meta.k8s.io` 를 실어 그 형식을
요구하고, 받은 표를 화면 폭에 맞춰 늘어놓을 뿐이다. HTTP 의 내용 협상을 그대로 쓴다.

`kubectl get --raw /api/v1/nodes` 로는 `Table` 이 아니라 `NodeList` 가 오는데, 그 경로에는
이 헤더를 붙이지 않기 때문이다.

**막혔던 지점 3 — ConfigMap 을 적용하니 이름공간이 없다는 오류가 났다**

```
Error from server (NotFound): namespaces "learn" not found
```

`01-namespace.yaml` 을 먼저 적용해야 했다. 실습 2에서 본 `api-resources` 의 `NAMESPACED`
열이 여기서 실제로 걸린 것이다. ConfigMap 은 그 열이 `true` 라서 담길 그릇이 먼저 있어야
하고, Node 나 Namespace 는 `false` 라서 그릇이 필요 없다. 매니페스트 파일 이름이 `01-`,
`02-` 로 시작하는 것도 이 순서 때문이다(`kubectl apply -f manifests/` 는 파일 이름 순서로
처리한다).

**알게 된 것 — `kind` 는 클래스이고 만들어지는 것은 인스턴스다**

`kind: Namespace` 는 `Namespace` 라는 종류를 **만드는** 것이 아니라 **가리키는** 것이다.
실제로 만들어지는 것은 `metadata.name: learn` 이라는 인스턴스 하나다.

| YAML 의 줄 | 대응 |
|---|---|
| `kind: Namespace` | 클래스 이름. 이미 존재하는 종류를 가리킨다 |
| `metadata.name: learn` | 인스턴스 이름. 이것이 새로 생긴다 |
| `apiVersion: v1` | 그 클래스가 어느 그룹·버전에 속하는지 |

종류 자체의 목록은 `kubectl api-resources` 로 세어 이 클러스터에서 67개였다. 이 숫자는
고정이 아니다. CRD 를 등록하면 종류가 늘어나고, 12단계에서 Argo CD 를 설치하면 실제로
늘어난 것을 볼 수 있다.

**알게 된 것 — `apply` 의 세 가지 응답은 모두 같은 명령의 결과다**

| 결과 | 뜻 |
|---|---|
| `created` | 없던 것을 새로 만들었다 |
| `unchanged` | 이미 그 상태였다. 아무것도 하지 않았다 |
| `configured` | 달랐으므로 파일에 맞춰 고쳤다 |

만들라거나 고치라고 지시한 적이 없다. "이래야 한다"를 적었을 뿐이고 무엇을 할지는 클러스터가
현재 상태와 비교해서 정했다. 이 성질 때문에 매니페스트를 Git 에 두고 반복 적용하는 방식이
성립한다(12단계).

**막혔던 지점 4 — `kubectl diff` 가 아무 출력도 내지 않았다**

값을 바꾸고 `apply` 를 한 **뒤에** `diff` 를 실행했기 때문이다. 파일과 클러스터가 이미 같아서
간격이 0이었다. 시간이 지나서가 아니다. `diff` 는 그때그때 클러스터에 물어보므로 언제
실행해도 결과가 같다.

`diff` 가 보는 것은 파일도 클러스터도 아니라 **둘 사이의 간격**이다. 쓰는 자리는 수정과 적용
사이다.

```
파일 수정 → diff (무엇이 바뀔지 확인) → apply
```

빈 출력 자체도 정보다. "지금 적용해도 바뀌는 것이 없다"는 확인이므로, 배포 전에 돌려서
아무것도 안 나오면 그 배포는 건너뛸 수 있다.

**알게 된 것 — 삭제도 요청일 뿐이다**

`kubectl delete -f 파일` 은 만들 때 쓴 파일을 그대로 넘긴다. 무엇을 지울지는 파일의 `kind` 와
`name` 이 정한다. 지운 직후에 조회하면 `Terminating` 상태로 잠깐 남는데, API 서버는 "지워야
한다"고 표시만 하고 컨트롤러가 안에 든 것을 정리한 다음에야 실제로 사라지기 때문이다.
`apply` 가 컨테이너를 만들지 않고 etcd 에 글만 적었던 것과 같은 구조다.

이름공간을 지우면 **그 안의 것이 전부 함께 지워진다.** 실무에서 사고가 나는 자리다.

### 02단계 (2026-08-28)

**막혔던 지점 1 — 이름공간이 없는데 `get` 이 조용했다**

`kubectl get pods -n learn` 이 `No resources found in learn namespace` 를 냈길래 이름공간은
있고 안이 비었다고 판단했는데, `apply` 를 하니 `namespaces "learn" not found` 가 나왔다.
**이름공간이 아예 없어도 같은 문장이 나온다.** 재부팅으로 클러스터를 다시 만들면서 01단계
결과물이 사라져 있었던 것이다.

- 교훈: 존재 확인은 `kubectl get ns learn` 으로 한다. 없으면 `NotFound` 로 명확히 실패한다.

**막혔던 지점 2 — `writer` 의 로그가 비어 있었다**

`kubectl logs -c writer` 가 아무것도 내지 않았다. 고장이 아니라 정상이었다. **`logs` 가
보여 주는 것은 표준 출력과 표준 에러뿐**인데, `writer` 는 `>> /shared/log.txt` 로 파일에만
쓰기 때문이다. 옆의 `reader` 는 화면으로 내보내므로 보였다.

이 차이가 **로그 수집 사이드카가 존재하는 이유** 그 자체다. 파일에만 쓰는 프로그램은
쿠버네티스의 로그 경로에 잡히지 않으므로, 옆에 붙은 컨테이너가 읽어서 표준 출력으로
흘려보낸다. `reader` 가 하던 일이 그것이다. README 를 고쳐 두었다.

**알게 된 것 — IP 는 "공유"되는 것이 아니라 애초에 하나뿐이다**

튜터가 처음에 "pause 컨테이너가 IP 를 두 컨테이너에게 공유해 준다"고 설명했는데 이해되지
않았다. "공유"라는 말이 *각자 자기 것이 있는데 하나를 같이 쓴다*로 읽히기 때문이다.

실제 구조는 다르다. IP 는 컨테이너가 아니라 **네트워크 인터페이스**에 붙고, 그 인터페이스는
**네트워크 이름공간**이라는 칸막이 안에 있다. pause 컨테이너가 먼저 만들어져 이름공간을
열면 CNI 가 거기에 인터페이스와 IP 를 붙이고, 나머지 컨테이너는 자기 이름공간을 만들지 않고
**그 안으로 들어간다.** 나눠 쓰는 것이 아니라 하나뿐인 것이다.

Docker 로 옮기면 `--network container:이름` 과 같다. 커널이 붙인 이름공간 번호를 비교하면
셋이 완전히 같게 나온다.

```
writer   pid=2818  netns=net:[4026532785]
reader   pid=2850  netns=net:[4026532785]
pause    pid=2790  netns=net:[4026532785]
```

PID 가 pause → writer → reader 순인 것도 증거다. **pause 가 먼저 이름공간을 열고 나머지가
뒤따라 들어갔다.** 그래서 Pod 이 사라지면 이름공간도 사라지고 IP 도 함께 사라진다.

**막혔던 지점 3 — `Pending` 이 57초였는데 Events 는 15초라고 했다**

`init-demo` 를 `-w` 로 지켜보니 `Pending` 이 57초 지속되었다. 그런데 `describe` 의 Events 는
`Scheduled` 부터 `main` 시작까지 15초로 보였다. 튜터가 Events 를 믿고 "금방 끝났다"고 했으나
화면 쪽이 맞았다.

**Events 의 첫 줄이 `Scheduled` 이므로, 그 이전 구간은 Events 에 아무 흔적도 남기지
않는다.** 타임스탬프를 직접 비교해야 보인다.

```
Pod 생성 03:27:27  →  배정 03:28:24   (57초 공백)
prepare 시작 03:28:34 → 종료 03:28:39 (sleep 5 그대로)
main 시작 03:28:40
```

- 진단 순서: `phase` → `Events` → **타임스탬프**. 해상도를 이 순서로 높인다.
- 왜 배정에 57초가 걸렸는지는 밝히지 않았다. `FailedScheduling` 이 없었으므로 스케줄러가
  자리를 못 찾은 것은 아니다.

**알게 된 것 — 화면의 STATUS 는 API 의 phase 가 아니다**

`Init:0/1`·`Completed`·`Error` 는 모두 `status.phase` 에 없는 값이다. STATUS 열은 `kubectl`
이 phase 와 컨테이너 상태를 조합해 만든 요약이다. 초기화 중인 Pod 의 실제 phase 는
`Pending` 이고, 계속 재시작하는 Pod 은 화면에 `Error` 가 찍혀도 phase 는 `Running` 이다.

화면의 문자열을 API 필드로 착각하면 09단계에서 검색이 막힌다.

`Init:0/1` 은 "초기화 컨테이너 1개 중 0개가 끝났다"는 뜻이며, 같은 줄의 `READY 0/1` 과 세는
대상이 다르다(READY 는 주 컨테이너 중 준비된 수).

**알게 된 것 — `restartPolicy` 를 적지 않으면 `Always` 다**

`init-demo` 를 한참 뒤에 보니 `RESTARTS 1` 이었다. 확인해 보니 직전 종료 이유가
`Completed`, 종료 코드 `0` 이었다. **성공으로 끝났는데도 다시 시작한 것**이다. 그 매니페스트
에는 `restartPolicy` 가 없고 기본값이 `Always` 이기 때문이다.

같은 화면에 세 정책이 나란히 있었다.

| Pod | restartPolicy | 성공으로 끝났을 때 |
|---|---|---|
| `once-never` | `Never` | `Completed` 로 멈춰 남는다 |
| `init-demo` | 없음 → `Always` | **다시 시작한다** |
| `once-onfailure` | `OnFailure` | 다시 시작하지 않는다 |

그리고 `once-onfailure` 의 백오프가 실제로 상한 5분에 도달했다(`RESTARTS 13 (5m47s ago)`).
처음 1초, 다음 20초로 벌어지던 간격이 여기까지 늘어난 것이다.

**실습 7 진단 기록 — `ImagePullBackOff`**

`describe` 의 Events 를 보고 `nginx:this-tag-does-not-exist` 를 찾아 태그를 고쳤다. 어느
사건까지 성공했는지(`Scheduled`) 어디에서 멈췄는지(`Pulling`)를 보면 원인의 위치가 이미
좁혀진다.

고친 뒤 `configured` 가 떴는데도 **4분 15초가 지나서야** `Running` 이 되었다. kubelet 이
이미 늘려 놓은 재시도 간격은 파일을 고쳐도 줄어들지 않는다. 지우고 다시 만드니 9초 만에
끝났다.

`nginx:latest` 로 고쳤는데 실무에서는 피해야 한다. 가리키는 대상이 언제든 바뀌어 재현성이
깨지고, `imagePullPolicy` 의 기본값까지 `Always` 로 달라진다(다른 태그는 `IfNotPresent`).
버전을 고정하거나 다이제스트로 못 박는다.

**틀렸던 확인 질문 — 노드가 죽으면 누가 되살리는가**

"각 노드의 kubelet"이라고 답했으나 **아무도 되살리지 않는다.** 노드가 죽으면 그 위의
kubelet 도 함께 죽고, 다른 노드의 kubelet 은 자기 노드에 배정된 Pod 만 본다.

`restartPolicy` 는 **컨테이너가 죽었을 때**를 다루지 **노드가 죽었을 때**를 다루지 않는다.
층이 다르다. 이 빈틈이 03단계 컨트롤러가 필요한 이유다.

**확인 질문 4번의 표현이 모호했다**

"Pod 을 직접 만들어 쓰면 안 되는 이유"에서 "직접"이 무엇의 반대인지 알 수 없었다. **`kind:
Pod` 을 사람이 써서 `apply` 하는 것**이 "직접"이고, 그 반대는 **`kind: Deployment` 를
등록하고 Pod 오브젝트는 컨트롤러가 만들게 하는 것**이다. 질문을 고쳐 두었다.

달라지는 것은 흐름의 맨 앞 한 칸뿐이다. 그 한 칸이 바뀌면 **Pod 을 계속 지켜보는 존재가
생긴다.**

**이 단계에서 문서에 반영한 것**

- `steps/02-pod/TUTOR-NOTES.md` 신설. 튜터가 잘못 설명했던 지점을 단계 폴더에 남기고, 다음
  학습 때 반드시 읽도록 `CLAUDE.md` 규약에 넣었다. 이 과정을 여러 번 반복할 것이므로.
- `CLAUDE.md` 행동 규약 7~10번 추가: 명령보다 목적을 먼저, 옵션은 매번 설명, `TUTOR-NOTES`
  선행 읽기, 학습자 화면과 튜터 판단이 어긋나면 학습자를 먼저 믿기.
- `steps/01-declarative-model/README.md` 에 "노드 위의 kubelet" 절 추가. 02단계에서
  kubelet 이 무엇인지 물었는데 정체를 설명하는 자리가 어디에도 없었다.

---

---

## 기록 형식 참고

<!--
### NN단계 (YYYY-MM-DD)

- 막혔던 지점:
- 원인:
- 알게 된 것:
-->
