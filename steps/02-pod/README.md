# 02단계 — Pod

## 이 단계를 마치면

- Pod 이 컨테이너 하나가 아니라 컨테이너의 묶음이라는 점과, 그 층이 왜 필요한지 설명할 수
  있습니다.
- Pod 의 생애주기 단계를 구분하고, 어디에서 멈췄는지 `describe`로 알아낼 수 있습니다.
- Pod 을 직접 만들어 쓰지 않는 이유를 실험으로 확인할 수 있습니다.

---

## 개념

### Pod 은 컨테이너가 아니다

쿠버네티스가 배치하는 최소 단위는 컨테이너가 아니라 **Pod** 입니다. Pod 은 컨테이너 하나
이상을 묶은 것이며, 묶인 컨테이너들은 다음을 공유합니다.

- **네트워크 이름공간** — IP 주소가 하나입니다. 같은 Pod 안의 컨테이너끼리는 `localhost`로
  통신합니다. 그래서 같은 포트를 두 컨테이너가 쓸 수 없습니다.
- **볼륨** — 같은 볼륨을 여러 컨테이너가 마운트할 수 있습니다.
- **생애** — 함께 스케줄되고, 같은 노드에 놓이며, 함께 사라집니다.

### 왜 이 층이 필요한가

컨테이너 하나면 될 것 같은데 왜 굳이 감싸는 층을 두었을까요. **긴밀하게 붙어 있어야 하는
보조 프로세스**가 실제로 자주 필요하기 때문입니다.

- 로그 파일을 읽어 전송하는 수집기
- 설정을 주기적으로 받아 파일로 떨어뜨리는 동기화 도구
- 트래픽을 가로채 암호화하는 프록시(서비스 메시)

이런 보조 컨테이너를 **사이드카**라고 합니다. 사이드카는 주 컨테이너와 같은 노드, 같은
네트워크, 같은 파일시스템 일부를 봐야 합니다. Pod 이 바로 그 경계입니다.

### 생애주기

Pod 에는 `status.phase` 가 있습니다.

| phase | 뜻 |
|-------|-----|
| `Pending` | 아직 노드에 배치되지 않았거나, 이미지를 받고 있다 |
| `Running` | 노드에 배치되어 컨테이너가 하나 이상 돌고 있다 |
| `Succeeded` | 모든 컨테이너가 성공(종료 코드 0)으로 끝났다 |
| `Failed` | 컨테이너가 실패로 끝났다 |

phase 는 거칠기 때문에, 진단할 때는 **컨테이너 상태**를 봅니다. 각 컨테이너는
`Waiting`·`Running`·`Terminated` 중 하나이고, `Waiting`에는 이유가 붙습니다
(`ImagePullBackOff`, `CrashLoopBackOff` 등). 09단계에서 이 이유들을 다룹니다.

### 초기화 컨테이너

`initContainers`에 적은 컨테이너는 주 컨테이너보다 **먼저, 순서대로, 끝까지** 실행됩니다.
하나가 실패하면 주 컨테이너는 시작하지 않습니다. 의존 서비스가 준비되기를 기다리거나,
설정 파일을 미리 만들어 두는 데 씁니다.

### Pod 은 일회용이다

이것이 이 단계의 결론입니다.

- Pod 은 **되살아나지 않습니다.** 삭제하면 끝입니다.
- Pod 의 **IP 는 보장되지 않습니다.** 다시 만들면 다른 주소를 받습니다.
- 노드가 사라지면 그 노드의 Pod 도 사라집니다.

그래서 실무에서는 Pod 을 직접 만들지 않습니다. **Pod 을 만들고 유지해 주는 컨트롤러**에게
맡깁니다(03단계). 이 단계에서 Pod 을 손으로 다루는 이유는, 컨트롤러가 무엇을 대신해 주는지
알기 위함입니다.

---

## 실습

```bash
cd steps/02-pod
```

### 1. 단일 컨테이너 Pod

```bash
kubectl apply -f manifests/01-pod-simple.yaml
kubectl get pods -n learn -o wide
```

`-o wide` 를 붙이면 IP 와 어느 노드에 놓였는지 보입니다. 어느 워커에 배치되었습니까?
스케줄러가 정한 것입니다.

```bash
# 무슨 일이 있었는지 시간순으로 보기 — 진단의 출발점입니다
kubectl describe pod web -n learn

# 로그
kubectl logs web -n learn

# 안으로 들어가기
kubectl exec -it web -n learn -- sh
#   컨테이너 안에서:
#   hostname          -> Pod 이름과 같습니다
#   ip addr           -> Pod IP
#   exit
```

`describe` 출력의 맨 아래 `Events` 부분을 잘 보십시오. 스케줄 → 이미지 받기 → 컨테이너
생성 → 시작의 순서가 기록되어 있습니다. **문제가 생기면 이 순서 중 어디에서 멈췄는지가
곧 원인의 위치입니다.**

### 2. 밖에서 접속해 보기

Pod IP 는 클러스터 안에서만 유효합니다. 밖에서 닿게 하려면 통로가 필요합니다.

```bash
kubectl port-forward -n learn pod/web 8080:80
# 다른 터미널에서:
curl -s localhost:8080 | head -5
```

`port-forward`는 개발과 진단용 임시 통로입니다. 실제 서비스 노출은 04·05단계에서 다룹니다.

### 3. 컨테이너 두 개가 한 Pod 에 있으면

```bash
kubectl apply -f manifests/02-pod-multi-container.yaml
kubectl get pod sidecar-demo -n learn
```

`READY 2/2` 가 될 때까지 기다리십시오. 컨테이너가 두 개입니다.

```bash
# 컨테이너를 지정해 로그를 봅니다 (-c 없이는 어느 것인지 물어봅니다)
kubectl logs sidecar-demo -n learn -c writer --tail=5
kubectl logs sidecar-demo -n learn -c reader --tail=5
```

`writer`의 로그는 **비어 있는 것이 정상입니다.** `kubectl logs`가 보여 주는 것은 컨테이너의
표준 출력과 표준 에러뿐인데, `writer`는 `>> /shared/log.txt`로 방향을 돌려 **파일에만**
쓰기 때문입니다. 반면 `reader`는 화면으로 출력하므로 보입니다.

이 차이가 개념 설명에서 말한 **로그 수집 사이드카가 존재하는 이유**입니다. 파일에만 쓰는
프로그램은 쿠버네티스의 로그 경로에 잡히지 않으므로, 옆에 붙은 컨테이너가 그 파일을 읽어
표준 출력으로 흘려보내 줍니다. `reader`가 지금 하는 일이 그것입니다.

파일을 직접 비교하면 공유가 확인됩니다. 컨테이너 이름만 다르고 경로는 같습니다.

```bash
kubectl exec -n learn sidecar-demo -c writer -- tail -3 /shared/log.txt
kubectl exec -n learn sidecar-demo -c reader  -- tail -3 /shared/log.txt
```

이제 네트워크 공유를 확인하십시오.

```bash
# reader 안에서 writer 가 아니라 자기 자신의 localhost 로 접속됩니다
kubectl exec -n learn sidecar-demo -c reader -- wget -qO- localhost:8081 | head -3
```

`reader` 컨테이너에는 웹 서버가 없는데도 `localhost:8081`에서 응답이 옵니다. 같은 Pod 안의
`writer`가 그 포트를 듣고 있기 때문입니다. **IP 와 포트 공간이 하나**임을 보여 줍니다.

```bash
# 두 컨테이너의 IP 가 같은지 직접 비교
kubectl exec -n learn sidecar-demo -c writer -- hostname -i
kubectl exec -n learn sidecar-demo -c reader  -- hostname -i
```

### 4. 초기화 컨테이너

```bash
kubectl apply -f manifests/03-pod-init.yaml

# 바로 이어서 상태를 보십시오. Init:0/1 단계가 잠깐 보입니다
kubectl get pod init-demo -n learn -w
# Ctrl+C 로 중단
```

`Init:0/1` → `PodInitializing` → `Running` 순서가 보입니다.

```bash
kubectl logs init-demo -n learn -c prepare      # 초기화 컨테이너의 로그
kubectl exec -n learn init-demo -- cat /work/prepared.txt
```

초기화 컨테이너가 만든 파일을 주 컨테이너가 읽고 있습니다.

### 5. 종료하는 Pod 과 restartPolicy

```bash
kubectl apply -f manifests/04-pod-restart-policy.yaml

# 두 Pod 을 함께 지켜보십시오
kubectl get pods -n learn -l demo=restart -w
# 30초쯤 본 뒤 Ctrl+C
```

`once-never`는 `Succeeded`로 끝나고 그대로 남습니다. `once-onfailure`는 실패로 끝나므로
계속 다시 시작합니다. `RESTARTS` 값이 올라가는 것을 보십시오.

```bash
kubectl get pods -n learn -l demo=restart
kubectl describe pod once-onfailure -n learn | grep -A5 'Last State'
```

**restartPolicy 는 Pod 수준의 설정이며 `Always`(기본)·`OnFailure`·`Never` 세 가지입니다.**
여기서 재시작하는 주체는 그 노드의 kubelet 이고, Pod 을 **같은 노드에서** 다시 시작합니다.
노드 자체가 죽으면 아무도 살려 주지 않습니다.

### 6. 결정적인 실험 — Pod 을 지우면

```bash
# 지금 IP 를 적어 두십시오
kubectl get pod web -n learn -o jsonpath='{.status.podIP}{"\n"}'

kubectl delete pod web -n learn

# 다시 살아납니까?
kubectl get pods -n learn
```

되살아나지 않습니다. 이것이 03단계가 필요한 이유입니다.

다시 만들어서 IP 를 비교해 보십시오.

```bash
kubectl apply -f manifests/01-pod-simple.yaml
kubectl get pod web -n learn -o jsonpath='{.status.podIP}{"\n"}'
```

주소가 바뀌었습니다. **Pod IP 를 어딘가에 적어 두는 설계는 반드시 깨집니다.** 04단계의
Service 가 이 문제를 풉니다.

### 7. 진단 감각 기르기 — 일부러 틀린 Pod

```bash
kubectl apply -f manifests/05-pod-broken.yaml
kubectl get pods -n learn
```

`ImagePullBackOff` 가 보일 것입니다. **답을 보지 말고** 다음 순서로 원인을 찾아보십시오.

```bash
kubectl describe pod broken -n learn | tail -20
```

`Events` 에 무엇이 적혀 있습니까? 무엇이 원인이고, 매니페스트의 어느 줄을 고쳐야
합니까? 확인했으면 파일을 고쳐서 정상으로 만들어 보십시오.

### 8. 정리

재시작 실습용 Pod 과 고장 낸 Pod 만 지웁니다. 앞의 셋은 검증에서 쓰므로 남겨 두십시오.

```bash
kubectl delete -f manifests/04-pod-restart-policy.yaml --ignore-not-found
kubectl delete -f manifests/05-pod-broken.yaml --ignore-not-found
kubectl get pods -n learn
```

`web`, `sidecar-demo`, `init-demo` 가 남아 있어야 합니다. 6번 실습에서 `web` 을 지웠다면
다시 만드십시오.

```bash
kubectl apply -f manifests/01-pod-simple.yaml
```

검증을 통과한 뒤, 03단계로 넘어가기 전에 모두 지우십시오.

```bash
kubectl delete -f manifests/ --ignore-not-found
```

---

## 검증

```bash
./verify.sh
```

---

## 확인 질문

1. 같은 Pod 안의 두 컨테이너가 같은 포트를 들을 수 없는 이유는 무엇입니까?
2. `status.phase` 가 `Pending` 인 Pod 을 만났을 때, 다음으로 볼 것은 무엇입니까?
3. `restartPolicy: Always` 인 Pod 이 있는 노드가 죽으면 어떻게 됩니까? 누가 되살립니까?
4. Pod 을 직접 만들어 쓰면 안 되는 이유를 두 가지 이상 대십시오.

---

## 기록

`PROGRESS.md`를 갱신하십시오. 특히 7번 실습에서 원인을 찾는 데 걸린 과정을 적어 두면,
09단계에서 같은 감각을 다시 쓰게 됩니다.
