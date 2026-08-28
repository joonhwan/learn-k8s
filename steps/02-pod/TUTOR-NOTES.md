# 02단계 — 튜터가 틀렸던 지점

이 단계를 안내하기 전에 **반드시 읽으십시오.** 지난 학습에서 튜터(에이전트)가 잘못
설명했다가 학습자의 되물음으로 바로잡힌 내용입니다. 같은 실수를 반복하면 학습자가 잘못된
그림을 그대로 안고 다음 단계로 넘어갑니다.

`README.md` 자체가 틀렸던 것은 README 를 고쳐 두었으므로 여기에 남기지 않습니다. 여기 있는
것은 **문서에는 없고 튜터가 즉석에서 설명하다 틀린 것들**입니다.

---

## 1. 이름공간이 없어도 `get` 은 조용하다 (2026-08-28)

**틀린 설명:** `kubectl get pods -n learn` 이 `No resources found in learn namespace` 를
냈으므로 이름공간은 있고 그 안이 비어 있을 뿐이라고 판단했다.

**실제:** 이름공간이 **아예 없어도 같은 문장**이 나온다. 학습자가 `apply` 를 하고 나서야
`namespaces "learn" not found` 로 드러났다.

**다음에 할 일:** 02단계를 시작하기 전에 이름공간의 존재를 직접 확인한다. 클러스터를 다시
만들었다면 01단계 결과물이 사라져 있으므로 복원부터 안내한다.

```bash
kubectl get ns learn                        # 없으면 여기서 NotFound 로 명확히 실패한다
kubectl apply -f steps/01-declarative-model/manifests/
```

---

## 2. pause 컨테이너를 "IP 를 공유해 주는 것"으로 설명하지 말 것 (2026-08-28)

**틀린 설명:** "제3의 컨테이너(pause)가 네트워크 이름공간을 붙잡고 있고, 두 컨테이너가 그
IP 를 공유한다." 학습자가 "제3의 컨테이너가 제공하는 IP 를 다른 둘이 공유한다는 말이 이해가
안 된다"고 되물었다.

**왜 안 통하는가:** "공유"라는 말이 *각자 자기 것이 있는데 하나를 같이 쓴다*로 읽힌다.
실제 구조는 그것이 아니다.

**실제:** IP 는 컨테이너가 아니라 **네트워크 인터페이스**에 붙고, 그 인터페이스는 **네트워크
이름공간** 안에 있다. pause 가 먼저 만들어져 이름공간을 열면 CNI 가 거기에 인터페이스와
IP 를 붙이고, 나머지 컨테이너는 자기 이름공간을 만들지 않고 **그 안으로 들어간다.** 나눠
쓰는 것이 아니라 애초에 하나뿐인 것이다.

**다음에 할 일:** Docker 경험자에게는 `--network container:` 로 설명하면 한 번에 통한다.

```bash
docker run -d --rm --name ns-a nginx:alpine
docker run --rm --network container:ns-a busybox:1 ip addr   # ns-a 와 같은 IP
docker exec ns-a ip addr
docker rm -f ns-a
```

커널이 붙인 이름공간 번호를 직접 비교하면 결정적이다. 세 값이 완전히 같게 나온다.

```bash
id=$(docker exec learn-worker2 crictl ps --name writer -q | head -1)
pid=$(docker exec learn-worker2 crictl inspect --output go-template --template '{{.info.pid}}' $id)
docker exec learn-worker2 readlink /proc/$pid/ns/net
```

`crictl` 은 노드 안 `/usr/local/bin` 에 있다. `docker exec 노드 sh -c "..."` 로 감싸면 PATH
에서 빠져 `command not found` 가 나므로, `docker exec 노드 crictl ...` 로 직접 호출한다.

---

## 3. Events 만 보고 소요 시간을 판단하지 말 것 (2026-08-28)

**틀린 설명:** `init-demo` 의 Events 가 `Scheduled` 부터 `main` 시작까지 15초였으므로 금방
끝났다고 말했다. 그런데 학습자의 `-w` 화면에는 `Pending` 이 57초 지속되어 있었다.

**실제:** 학습자 화면이 맞았다. **Events 의 첫 줄이 `Scheduled` 이므로, 그 이전 구간은
Events 에 아무 흔적도 남지 않는다.** Pod 이 etcd 에 기록되고 스케줄러가 배정하기까지의
공백은 타임스탬프를 직접 비교해야 보인다.

```bash
kubectl get pod init-demo -n learn \
  -o jsonpath='생성 {.metadata.creationTimestamp}  배정 {.status.startTime}{"\n"}'
```

실제 값(2026-08-28): 생성 `03:27:27`, 배정 `03:28:24` 로 57초 차이였다.

**다음에 할 일:** 학습자가 화면에서 본 시간과 Events 가 어긋나면 **학습자 쪽을 먼저 믿고**
타임스탬프를 확인한다. 이 관찰은 09단계 진단으로 그대로 이어지므로 눌러 두지 말고 짚는다.

---

## 4. `Init:0/1` 은 phase 가 아니다 (2026-08-28)

틀린 설명은 아니었으나 학습자가 되물은 지점이므로 남긴다.

`STATUS` 열은 `kubectl` 이 phase 와 컨테이너 상태를 조합해 만든 요약이며, API 서버가 들고
있는 `status.phase` 는 그 시점에도 `Pending` 이다. 화면의 문자열을 API 필드로 착각하면
09단계에서 검색이 막힌다. 함께 짚을 것:

| 열 | 예시 | 세는 대상 |
|---|---|---|
| `READY` | `0/1` | 주 컨테이너 중 준비된 수 |
| `STATUS` | `Init:0/1` | 초기화 컨테이너 중 끝난 수 |

---

## 5. 초기화 컨테이너에는 `exec` 가 안 된다 (2026-08-28)

학습자가 스스로 시도해 발견했다. 미리 알려 주지 말고, 시도했을 때 설명할 수 있게 알아 둔다.

| 명령 | 필요한 것 | 종료된 초기화 컨테이너에 쓸 수 있는가 |
|---|---|---|
| `logs -c prepare` | 남아 있는 기록 | 된다 |
| `exec -c prepare` | 살아 있는 프로세스 | 안 된다 (`container not found`) |
