# 학습 진도

각 단계를 마칠 때마다 상태를 갱신하고, **막혔던 지점**과 그때 알게 된 것을 기록합니다.
이 기록은 04단계 이후 문서를 작성할 때의 재료이자, 복습할 때 가장 먼저 읽을 자료입니다.

상태 표기: `[ ]` 시작 전 · `[~]` 진행 중 · `[x]` 완료

---

## 다음에 이어서 할 일

**마지막 작업: 2026-08-31.** 03단계를 검증까지 마쳤습니다(14/14). 이제 04단계입니다.
`demo` Deployment 는 04단계에서 계속 쓰므로 **지우지 마십시오.**

```bash
# 1. 새 터미널에서
wsl
cd /mnt/d/workspace/prj/oss/mine/learn-k8s

# 2. 클러스터가 살아 있는지 확인합니다
kubectl get nodes

# 3. 노드가 보이지 않으면 다시 만듭니다. 1~2분입니다.
RECREATE=1 ./scripts/cluster-up.sh

# 4. 다시 만들었다면 01~03단계 결과물을 복원합니다.
#    이름공간 존재 확인은 get ns 로 합니다 (get pods 는 없어도 조용합니다).
kubectl get ns learn || kubectl apply -f steps/01-declarative-model/manifests/
kind load docker-image learn-k8s/demo:v1 --name learn
kind load docker-image learn-k8s/demo:v2 --name learn
kubectl apply -f steps/03-workloads/manifests/01-deployment.yaml

# 5. 04단계 시작 (문서가 아직 스텁이므로 함께 작성하며 진행합니다)
cd steps/04-service-dns && cat README.md
```

**04단계에서 갚아야 할 빚이 두 개 있습니다.**

- 03단계에서 롤링 업데이트 중에 서비스가 정말 끊기지 않는지 확인하지 못했습니다.
  트래픽을 보낼 안정된 주소가 없었기 때문입니다. Service 를 붙인 뒤 갱신하면서 응답이
  끊기는지 실제로 측정합니다.
- 02단계에서 Pod 을 다시 만들면 IP 가 바뀌는 것을 확인했습니다. 03단계에서도 Pod 을
  지울 때마다 IP 가 새로 붙었습니다. 그 문제의 해답이 04단계에 있습니다.

**환경 주의:** `kube-scheduler` 와 `kube-controller-manager` 가 여전히
`CrashLoopBackOff` 입니다. 원인은 디스크이며 실습 실패가 아닙니다. 아래 "디스크가
HDD 다" 절과 `CLAUDE.md` 실행 환경 6번을 읽으십시오.

---

## 단계별 상태

| 상태 | 단계 | 주제 | 완료일 |
|:---:|:---:|------|--------|
| [x] | 00 | 환경 구성 | 2026-08-24 |
| [x] | 01 | 선언형 모델과 컨트롤 플레인 | 2026-08-27 |
| [x] | 02 | Pod | 2026-08-28 |
| [x] | 03 | 워크로드 컨트롤러 | 2026-08-31 |
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

### 디스크가 HDD 다 (2026-08-28 확인)

WSL 배포판이 `D:\workspace\wsl\Ubuntu24\ext4.vhdx` 에 있고 D: 는 회전 디스크
(Seagate ST2000DM008)다. 측정값이다.

| 쓰기 방식 | 속도 | 비고 |
|---|---|---|
| 순차 쓰기(캐시 허용) | 534 MB/s | 디스크가 느려 보이지 않는다 |
| `fsync` 강제 쓰기 | 16.6 kB/s (한 번에 246ms) | 캐시를 우회하면 드러난다 |

etcd 는 모든 쓰기에 `fsync` 를 요구하므로 `kube-scheduler` 와
`kube-controller-manager` 가 리더 임차를 갱신하지 못하고 `CrashLoopBackOff` 에 빠져
있다. 03단계 진입 시점에 재시작 179회·173회였다. 자세한 내용과 진단 명령은
`CLAUDE.md` 의 실행 환경 6번에 적어 두었다.

근본 해결은 WSL 을 SSD 로 옮기는 것이나, C: 여유가 120GB 인데 vhdx 가 95GB 여서 지금은
어렵다. **그대로 진행하기로 결정했다.**

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

### 03단계 (2026-08-28 시작 ~ 2026-08-31 완료)

**막혔던 지점 1 — Pod 세 개가 Pending 에서 3분 넘게 멈췄다. 원인은 실습이 아니라 디스크였다**

`kubectl apply` 로 Deployment 를 만들었는데 Pod 이 셋 다 `Pending` 이고 `NODE` 가
`<none>` 이었다. `FailedScheduling` 이벤트는 없었다. 02단계에서 밝히지 못했던 "57초
지연"과 같은 현상이며, 이번에 끝까지 파고들어 원인을 찾았다.

```
D: 드라이브가 HDD (Seagate ST2000DM008)
  └ WSL 배포판이 그 위에 있다 (D:\workspace\wsl\Ubuntu24\ext4.vhdx)
      └ fsync 한 번에 246ms (순차 쓰기는 534 MB/s 로 멀쩡하다)
          └ etcd 의 WAL 쓰기가 매번 그만큼 지연된다
              └ API 서버가 5초 타임아웃 안에 응답하지 못한다
                  └ 스케줄러가 리더 임차를 갱신하지 못하고 스스로 종료한다
                      └ CrashLoopBackOff (재시작 179회)
                          └ 아무도 배정하지 않으므로 Pending 에 머문다
```

진단의 순서가 그대로 교훈이다. **`Pending` 을 보면 `FailedScheduling` 이 있는지부터
본다.** 없다면 스케줄러가 자리를 못 찾은 것이 아니라 **아무도 찾고 있지 않은 것**이므로,
`kube-system` 의 컨트롤 플레인 구성 요소를 봐야 한다.

```bash
kubectl get pods -n kube-system | grep -E 'scheduler|controller-manager'
kubectl logs -n kube-system kube-scheduler-learn-control-plane --previous --tail=5
```

로그의 마지막 세 줄이 전부였다.

```
Failed to update lease ... context deadline exceeded
Failed to renew lease
Leaderelection lost
```

**스케줄러가 고장 난 것이 아니라 API 서버가 느려서 스스로 물러난 것이다.** 이 구분이
중요하다. 증상이 나타난 곳과 원인이 있는 곳이 다르다. `kube-controller-manager` 도 재시작
173회로 같은 이유였다.

etcd DB 는 3.2MB, 메모리는 15GB 중 12GB 유휴, CPU 부하는 0.7 이었다. **자원이 모자라서가
아니다.** 측정으로 확정했다.

```bash
dd if=/dev/zero of=/tmp/probe bs=4k count=500 oflag=dsync   # 16.6 kB/s (246ms/회)
dd if=/dev/zero of=/tmp/probe bs=1M count=200               # 534 MB/s
```

근본 해결은 WSL 을 SSD 로 옮기는 것이나, C: 여유 120GB 에 vhdx 가 95GB 라 지금은 어렵다.
**그대로 진행하기로 결정했다.**

**알게 된 것 — `kind load` 는 레지스트리를 건너뛰는 지름길이다**

실무에서는 kind 를 쓰지 않으므로, `kind load` 에 해당하는 일이 무엇인지 사내 프로젝트
(`D:\workspace\prj\work\dms\Setup`)를 열어 대조했다. 한 줄이 세 조각으로 나뉜다.

| 조각 | 학습(kind) | DMS |
|---|---|---|
| 이미지를 둘 곳 | 필요 없음 | 컨트롤 노드에 레지스트리 컨테이너를 띄운다 |
| 이미지를 올린다 | `kind load` | `podman build → tag → push registry.internal:7000/...` |
| 노드가 받아 온다 | 필요 없음 | 각 노드 containerd 에 `certs.d/.../hosts.toml` 등록 |

**이미지 이름의 맨 앞이 곧 레지스트리 주소다.** 우리 실습에서 노드 안 이름이
`docker.io/learn-k8s/demo` 로 보인 것은, 주소를 적지 않으면 containerd 가 `docker.io/` 를
채워 넣기 때문이다. 실제로 그 주소에는 없으므로 `imagePullPolicy: IfNotPresent` 가 없으면
받으러 갔다가 실패한다.

DMS 는 폐쇄망이라 **pause 이미지까지** 사내 레지스트리로 바꿔 두었다(`sandbox_image`).
02단계에서 만난 그 pause 다. 이 한 줄을 빠뜨리면 모든 Pod 이 뜨지 못한다.

**알게 된 것 — `kind load` 로 넣은 이미지는 ID 가 호스트와 다르다**

호스트는 `28875d58...`, 노드 안은 `2f977b14...` 였다. `kind load` 가 tar 로 내보낸 뒤
containerd 로 불러들이면서 이미지 설정의 표현이 바뀌었기 때문이다. 노드 쪽 repoDigest 가
`docker.io/library/import-2026-08-28@sha256:...` 인 것이 증거다.

- **호스트의 이미지 ID 로 노드의 이미지를 찾으면 못 찾는다.** 이름과 태그로 대조한다.
- `import-...` 는 레지스트리에서 온 다이제스트가 아니므로, `image: repo@sha256:...` 로
  못 박는 실습은 kind 에서 할 수 없다.

**알게 된 것 — `Pending` 은 서로 다른 두 상황을 한 이름으로 부른다**

`scale` 로 늘렸을 때 이런 두 줄이 연달아 나왔다.

```
demo-...-8mv9g   0/1   Pending   7s   <none>   <none>         <- 배정 전
demo-...-8mv9g   0/1   Pending   9s   <none>   learn-worker   <- 배정 후에도 Pending
```

`status.phase` 가 `Pending` 이라는 것은 **"컨테이너가 하나도 실행되지 않았다"**는 뜻이지
"배정되지 않았다"는 뜻이 아니다. 그래서 진단이 갈린다.

| `Pending` 인데 `NODE` 가 | 문제가 있는 곳 |
|---|---|
| `<none>` | 스케줄러 (자리가 없거나, 스케줄러가 죽었거나) |
| 노드 이름이 있음 | 그 노드의 kubelet (이미지·볼륨·런타임) |

**`-o wide` 로 `NODE` 열을 함께 보는 습관이 필요하다.** 02단계의 "STATUS 는 phase 가
아니다"에 이어, 이번에는 같은 phase 안에 두 상황이 들어 있다는 것을 보았다.

**알게 된 것 — ReplicaSet 이 줄일 때 어느 Pod 을 지울지 규칙이 있다**

`scale` 로 5개로 늘렸다가 `apply` 로 3개로 되돌리니, 방금 만든 두 개가 지워지고 원래 있던
것이 남았다. 우연이 아니라 정해진 순서다.

1. `Pending` 이거나 배정되지 못한 Pod 을 먼저
2. `controller.kubernetes.io/pod-deletion-cost` 주석 값이 낮은 것을 먼저
3. **복제본이 많이 몰린 노드**의 Pod 을 먼저
4. **더 최근에 만들어진** Pod 을 먼저

오래 살아남은 Pod 은 이미 트래픽을 받아 왔으므로 더 믿을 만하다. 2번은 사람이 개입하는
통로다.

**알게 된 것 — Pod 이름은 세 토막이고 각 토막의 주인이 다르다**

```
demo - bcb9d6678 - x9jd8
 │        │           └── API 서버가 붙인 임의 5자 (generateName 방식)
 │        └────────────── 파드 템플릿의 해시
 └─────────────────────── Deployment 이름 (사람이 지었다)
```

**가운데 해시가 "어느 버전인가"다.** `spec.template` 을 해시한 값이라, 이미지를 바꾸면
값이 달라지고 그래서 새 ReplicaSet 이 생긴다. 실습 4(Pod 삭제)에서는 가운데가 유지되고
실습 6(이미지 변경)에서는 바뀐 것이 이 차이다.

이름을 사람이 직접 지을 수도 있다(02단계의 `web`). 다만 같은 이름이 이미 있으면 거부되므로
복제에 쓸 수 없다. StatefulSet 만 임의 문자열 대신 순번(`redis-0`)을 쓰는데, 각 복제본이
고유한 저장소를 가져야 하기 때문이다(07단계).

**막혔던 지점 2 — `--sort-by=.lastTimestamp` 로는 이벤트가 시간순으로 정렬되지 않는다**

정렬했는데도 `Scheduled` 사건들만 시각이 뒤섞인 채 맨 앞에 몰려 있었다. 확인해 보니
**스케줄러만 새 이벤트 API(`events.k8s.io/v1`)를 써서 `lastTimestamp` 가 비어 있었다.**
kubelet 과 replicaset-controller 는 구 API 를 쓰므로 값이 있다. 정렬 기준이 없는 항목이
앞으로 밀린 것이다.

```bash
kubectl get events -n learn --sort-by=.metadata.creationTimestamp   # 이것을 쓴다
```

02단계에서 "Events 만 보고 시간을 판단하지 말 것"을 배웠는데, 이번 것은 더 위험하다.
**정렬했다고 믿는 화면에서 하필 배정 시각만 엉뚱한 자리에 있기 때문이다.**

**알게 된 것 — 이벤트는 1시간만 남는다**

실습 도중 앞선 이벤트들이 통째로 사라졌다. API 서버가 기본 1시간만 보관하고 지운다.
**"Events 에 아무것도 없다"가 "아무 일도 없었다"를 뜻하지 않는다.** 어젯밤에 죽은 Pod 을
아침에 조사하면 사건은 이미 없다. 실무에서 로그를 클러스터 밖으로 모으는 이유다.

**막혔던 지점 3 — `maxUnavailable` 을 반대로 이해했다**

실습 9에서 "`maxUnavailable` 이 0이므로 없어도 되는 Pod 수가 무한대"라고 판단했다. 두 가지가
틀렸다.

- 이 필드는 **상한**이다. 0이면 "없어도 되는 개수가 0", 즉 **가장 엄격한** 값이다.
- 그리고 `demo` 의 값은 0이 아니라 **1**이다. 0은 `02-deployment-strategy.yaml` 의
  `demo-strict` 쪽이다. 튜터가 힌트를 주면서 파일명을 밝히지 않아 혼동이 생겼다
  (`steps/03-workloads/TUTOR-NOTES.md` 에 기록).

**알게 된 것 — 없는 이미지로 갱신해도 서비스가 죽지 않는 이유**

`replicas: 3`, `maxUnavailable: 1`, `maxSurge: 1` 이면 지켜야 할 경계선이 둘이다.

- 준비된 Pod 최소 **2개** (3 - 1)
- Pod 총수 최대 **4개** (3 + 1)

v99 로 갱신했더니 정확히 그 경계선에서 멈췄다. 옛것 2개(준비됨) + 새것 2개(실패) = 4개.
더 진행하려면 둘 중 하나를 어겨야 하므로 **갱신이 얼어붙은 채 옛 버전이 계속 서비스한다.**

```
demo-6cf4d5d8d9   2   <none>   v99   <- 2개를 요구하지만 준비된 것이 없다
demo-bcb9d6678    2   2        v1    <- 3에서 2로 줄었을 뿐 0이 되지 않는다
```

**옛 ReplicaSet 을 0으로 내리는 일은 새 Pod 이 준비된 뒤에야 한다.** 이 순서가 안전장치
자체다. `maxUnavailable` 이 3이었다면 옛것을 한꺼번에 지운 뒤 새것을 띄우려 했을 것이고,
그 순간 서비스가 완전히 끊겼을 것이다.

실패한 Pod 에도 IP 가 붙어 있었다(`10.244.2.5`). pause 컨테이너는 이미 떠서 네트워크
이름공간을 열었고 **앱 컨테이너만 못 뜬 것**이다. 재시도 간격도 12초에서 시작해 5분 상한에
도달했다(02단계의 백오프와 같은 값).

**알게 된 것 — `rollout undo` 는 `last-applied-configuration` 을 갱신하지 않는다**

`undo` 를 하면 경고가 나온다. `kubectl apply` 는 적용할 때마다 **그 파일의 내용을 통째로**
이 주석에 저장해 두고, 다음 `apply` 때 세 가지를 비교한다.

| 비교 대상 | 뜻 |
|---|---|
| 주석에 저장된 옛 파일 | 지난번에 뭐라고 적었나 |
| 지금 적용하는 파일 | 이번에 뭐라고 적나 |
| 클러스터의 실제 상태 | 지금 실제로 어떤가 |

이 셋을 맞춰 봐야 **"내가 이번에 지운 필드"**를 알 수 있다. 그런데 주석은 "클러스터가 지금
어떤가"가 아니라 "내가 마지막으로 무엇을 적용했는가"만 기록한다. `undo`·`set image`·`scale`
처럼 `apply` 를 거치지 않고 상태를 바꾸면 둘이 어긋나고, 다음 `apply` 의 계산이 틀린 전제
위에서 이루어진다.

**실무의 올바른 되돌리기는 매니페스트를 옛 내용으로 고쳐서 다시 `apply` 하는 것이다.**
`rollout undo` 는 파일을 찾을 시간이 없는 급한 상황을 위한 수단이다. 12단계 GitOps 는 사람이
클러스터를 직접 바꾸는 통로를 막아서 이 문제를 없앤다.

**알게 된 것 — REVISION 번호는 재사용된다**

`undo` 뒤에 이력을 보니 REVISION 1이 사라지고 2, 3만 남았다. v1 로 돌아오면서 그것이
**3번으로 새 번호를 받은 것**이다. 개정 번호는 일련번호일 뿐 특정 버전을 가리키는 고정된
이름이 아니다. "3번으로 돌려 달라"고 나중에 말하면 그때 3번이 무엇일지 알 수 없다.

DMS 가 Deployment 이름에 버전 문자열을 박아 넣은 이유가 여기 있다
(`admintool-v1-0-2601-0900`). 그 이름은 바뀌지 않는다.

**알게 된 것 — 되살릴 수 있는 것은 정의이지 인스턴스가 아니다**

`undo` 로 v1 로 돌아왔을 때 가운데 해시는 `bcb9d6678` 로 복귀했지만 뒤 5자는 전부 새것이었고
`AGE` 도 79초였다. **옛 Pod 이 되살아난 것이 아니라, 옛 ReplicaSet 이 다시 3개를 요구해서
새로 만든 것이다.**

**실무와 다른 점 — DMS 는 롤링 업데이트를 쓰지 않는다**

| | 03단계에서 배운 것 | DMS |
|---|---|---|
| 갱신 방법 | `set image` 로 같은 Deployment 를 갱신 | 버전마다 별개의 Deployment 를 만든다 |
| 되돌리기 | `rollout undo` | 옛 버전 Deployment 를 다시 올린다 |
| 옛 버전이 남는 곳 | Deployment 안의 옛 ReplicaSet | 별개의 Deployment 오브젝트 |

블루/그린 배포에 가깝다. 서비스 시작·중지 순서가 정해져 있고(로그 관리자 먼저, 트리거
마지막) 큐가 비워질 때까지 기다려야 하는 성격이라, 한 개씩 교대하는 방식으로는 다루기
어려웠을 것이다.

**이 단계에서 문서에 반영한 것**

- `CLAUDE.md` 실행 환경에 6번 추가: 디스크가 HDD 라서 컨트롤 플레인이 계속 재시작한다는
  사실과 진단 명령. 08·09단계에서 학습자가 낸 고장과 구분하기 위해서다.
- `PROGRESS.md` 환경 기록에 "디스크가 HDD 다" 절 추가.
- `steps/02-pod/TUTOR-NOTES.md` 3번에 덧붙임: `--sort-by=.lastTimestamp` 정렬 함정.
- `steps/03-workloads/TUTOR-NOTES.md` 신설: `maxUnavailable` 힌트를 줄 때 파일명과 값을
  함께 밝힐 것, 환경이 느리다는 이유로 실습을 미리 잘라내지 말 것.

**알게 된 것 — `maxUnavailable: 0` 은 교대 순서를 뒤집는다 (실습 8)**

`demo-strict`(`maxUnavailable: 0`, `maxSurge: 1`)를 v2 로 갱신하니 세 번 모두 같은
순서였다.

```
d88pw   1/1  Running       3s      <- 새것이 준비되고
d9ml8   1/1  Terminating   110s    <- 그 다음에 옛것이 지워진다
```

실습 9의 `demo`(`maxUnavailable: 1`)는 정반대였다. 새 Pod 이 `ImagePullBackOff` 인
상태에서도 옛 Pod 하나를 먼저 `Terminating` 시켰다.

| | `demo` (`maxUnavailable: 1`) | `demo-strict` (`maxUnavailable: 0`) |
|---|---|---|
| 준비된 Pod 최소 | 2개 | **3개** (줄어들 수 없다) |
| Pod 총수 최대 | 4개 | 4개 |
| 교대 방식 | 제거와 생성이 겹칠 수 있다 | 새것이 준비된 뒤에만 제거한다 |

**대가는 자원과 시간이다.** 갱신 중 Pod 이 `replicas + 1` 개까지 존재하므로 여유 자원이
필요하고, 교대가 엄격히 직렬이라 앱 기동이 느릴수록 전체 갱신 시간이 길어진다.
가용성을 자원·시간과 맞바꾸는 것이다.

**알게 된 것 — `Terminating` 은 세지 않으므로 실제로는 5개가 공존했다**

`maxSurge: 1` 이 제한하는 것은 **ReplicaSet 이 자기 몫으로 세는 Pod 수**이고, 삭제 표시가
붙은 Pod 은 거기서 빠진다(실습 4에서 본 것과 같은 원리). 그래서 물리적으로는 상한을 넘는
순간이 있다. 로그의 `AGE` 로 113초 시점을 재구성하면 이렇다.

| Pod | 상태 |
|---|---|
| `d9ml8` | Terminating (110초 시작, 116초에 사라짐) |
| `g8sc5` | Terminating (막 시작) |
| `wl2d7`, `d88pw`, `l79f8` | Running |

**다섯 개다.** 종료가 6초나 걸린 이유는 이 앱의 `SHUTDOWN_DELAY` 기본값이 5초여서,
SIGTERM 을 받고도 5초를 기다린 뒤에 종료하기 때문이다(`app/main.go:24`).

실무 함의가 있다. 자원을 계산할 때 `replicas + maxSurge` 만 보면 모자랄 수 있다. **종료
중인 Pod 도 노드의 CPU 와 메모리를 그대로 쓰고 있다.** 종료가 느린 앱일수록 겹치는 구간이
길어진다.

**알게 된 것 — `maxUnavailable: 0` 만으로는 무중단이 가짜다 (08단계로 이어짐)**

이것이 실습 8의 가장 중요한 발견이다.

```
demo-strict-69c78b89f6-d88pw   0/1   ContainerCreating   2s
demo-strict-69c78b89f6-d88pw   1/1   Running             3s   <- 3초 만에 "준비됨"
```

이 앱은 `READY_AFTER=5` 라서 **5초가 지나야 스스로 준비된다.** 그런데 쿠버네티스는 3초
만에 `1/1` 로 판정했고 곧바로 옛 Pod 을 지웠다. `readinessProbe` 가 없어서 **앱에게 묻지
않고 컨테이너 프로세스가 떴다는 것만으로** 판단했기 때문이다.

**`maxUnavailable: 0` 이 보장하는 것은 "준비되었다고 판단된 Pod 의 수"일 뿐이고, 그 판단이
실제와 맞는지는 별개의 문제다.** 판단을 실제와 맞추는 장치가 `readinessProbe` 이며,
전략과 프로브가 둘 다 있어야 진짜 무중단이 된다. 08단계에서 붙인다.

`02-deployment-strategy.yaml` 이 `READY_AFTER=5` 를 넣어 두고 프로브는 일부러 빼 둔 것이
이 간극을 실제로 만들어 보여 주기 위한 장치였다.

**튜터의 오판 — 환경이 느리다는 이유로 실습을 미리 잘라냈다**

튜터가 "실습 8은 컨트롤 플레인이 불안정해서 교대 과정을 관찰하기 어렵다"고 판단해
건너뛰자고 했다. 학습자가 확인 질문 3번을 직접 확인하고 싶다고 해서 진행했더니 **관찰이
아주 잘 되었다.** 새 Pod 이 3~4초 만에 떴고 교대 순서가 선명했으며, 오히려 실습 9보다
빨랐다.

교훈은 두 가지다. 환경이 느리다는 이유로 실습을 미리 잘라내지 말 것. 그리고 이 환경의
지연은 **일정하지 않다**는 것. 스케줄러가 살아 있는 구간에 걸리면 정상 속도로 진행된다.

---

---

## 기록 형식 참고

<!--
### NN단계 (YYYY-MM-DD)

- 막혔던 지점:
- 원인:
- 알게 된 것:
-->
