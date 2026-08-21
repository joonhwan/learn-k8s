# 03단계 — 워크로드 컨트롤러

## 이 단계를 마치면

- 자기가 만든 애플리케이션을 이미지로 만들어 클러스터에 배포할 수 있습니다.
- Deployment → ReplicaSet → Pod 의 계층과 각 층의 역할을 설명할 수 있습니다.
- 롤링 업데이트와 롤백을 수행하고, 그 과정에서 무엇이 일어나는지 관찰할 수 있습니다.

---

## 개념

### 02단계에서 남은 문제

Pod 은 되살아나지 않았습니다. 개수를 유지해 주는 것도 없었습니다. 그 일을 맡는 것이
**컨트롤러**입니다.

### ReplicaSet — 개수를 지킨다

ReplicaSet 이 하는 일은 하나입니다. **레이블 셀렉터로 골라낸 Pod 의 수를 `replicas` 와
같게 유지한다.** 적으면 만들고, 많으면 지웁니다. 01단계에서 본 조정 루프가 그대로
적용된 것입니다.

여기서 **레이블 셀렉터**가 소유 관계를 만든다는 점이 중요합니다. ReplicaSet 은 "내가 만든
Pod" 를 기억하는 방식이 아니라, **조건에 맞는 Pod 을 센다**는 방식으로 동작합니다.

### Deployment — 갱신을 지휘한다

ReplicaSet 은 개수만 지킬 뿐, 새 버전으로 바꾸는 일은 못 합니다. Deployment 가 그 위에서
**ReplicaSet 을 여러 개 두고 갈아 끼우는** 방식으로 갱신을 처리합니다.

```
Deployment            갱신 전략과 이력을 관리한다
    └── ReplicaSet    특정 버전(파드 템플릿)의 개수를 지킨다
            └── Pod   실제로 돌아가는 것
```

버전을 바꾸면 Deployment 는 새 ReplicaSet 을 하나 만들고, 새 것을 늘리면서 옛 것을 줄입니다.
옛 ReplicaSet 은 개수 0으로 남습니다. **남겨 두는 이유는 되돌리기 위함입니다.**

### 롤링 업데이트를 지배하는 두 숫자

| 필드 | 뜻 |
|------|-----|
| `maxUnavailable` | 갱신 중에 없어도 되는 Pod 의 최대 수(또는 비율) |
| `maxSurge` | 원래 개수보다 더 만들어도 되는 Pod 의 최대 수(또는 비율) |

`maxUnavailable: 0` 으로 두면 항상 원래 개수만큼은 살아 있습니다. 대신 새 Pod 을 먼저
띄워야 하므로 자원이 일시적으로 더 듭니다. **무중단이 필요하면 이 조합을 씁니다.**

### 다른 컨트롤러들

| 컨트롤러 | 언제 쓰는가 |
|----------|-------------|
| Deployment | 상태가 없는 애플리케이션(웹 서버, API). 대부분의 경우 |
| StatefulSet | 각 복제본이 고유한 신원과 저장소를 가져야 할 때(데이터베이스). 07단계 |
| DaemonSet | 모든 노드에 하나씩 필요할 때(로그 수집기, 네트워크 플러그인) |
| Job | 한 번 실행해서 끝나야 할 때(배치 작업, 마이그레이션) |
| CronJob | 정해진 시각에 반복 실행할 때 |

---

## 실습

```bash
cd steps/03-workloads
```

### 1. 앱 이미지 만들기

이제부터 쓰는 애플리케이션은 `app/` 에 있습니다. 어떤 엔드포인트가 있고 왜 그렇게
만들었는지는 [`app/README.md`](../../app/README.md) 에 적혀 있습니다. 한 번 읽어 보십시오.

```bash
cd ../../app
docker build -t learn-k8s/demo:v1 --build-arg VERSION=v1 .
docker images learn-k8s/demo
```

로컬에 Go 를 설치하지 않았는데도 빌드된 이유는, 빌드가 컨테이너 안에서 이루어지기
때문입니다(멀티스테이지 빌드). 최종 이미지에는 컴파일러와 소스가 없어서 20MB 남짓입니다.

컨테이너로 먼저 확인해 보십시오.

```bash
docker run --rm -d --name demo-check -p 18080:8080 learn-k8s/demo:v1
curl -s localhost:18080 | jq .
docker rm -f demo-check
```

### 2. 클러스터가 이 이미지를 볼 수 있게 하기

여기가 kind 를 쓸 때 반드시 걸리는 지점입니다.

**클러스터의 노드는 별개의 컨테이너이고, 자기만의 이미지 저장소를 갖습니다.** WSL 의
Docker 에 있는 이미지를 노드가 자동으로 보지는 못합니다. 실어 넣어야 합니다.

```bash
cd ../steps/03-workloads
kind load docker-image learn-k8s/demo:v1 --name learn
```

실제로 들어갔는지 노드 안에서 확인해 보십시오.

```bash
docker exec learn-worker crictl images | grep demo
```

> **왜 이런 일이 필요한가**
> 실무에서는 이미지를 레지스트리(Docker Hub, 사내 Harbor 등)에 올리고, 노드가 거기서
> 받아 옵니다. kind 로 학습할 때는 레지스트리가 없으므로 `kind load` 로 직접 실어
> 넣습니다. 12단계 GitOps 실습에서는 이 차이가 다시 문제가 되므로, **이미지가 어디에
> 있고 누가 받아 오는가**를 늘 의식하십시오.

### 3. Deployment 로 배포하기

```bash
kubectl apply -f manifests/01-deployment.yaml
kubectl get deploy,rs,pods -n learn
```

세 층이 한 번에 보입니다. 이름의 규칙을 눈여겨보십시오.

```
deployment.apps/demo
replicaset.apps/demo-7d4b8c9f5      <- Deployment 이름 + 템플릿 해시
pod/demo-7d4b8c9f5-x2k9p            <- ReplicaSet 이름 + 임의 문자열
```

ReplicaSet 이름에 붙은 해시는 **파드 템플릿의 해시**입니다. 템플릿이 바뀌면 해시가 바뀌고,
그래서 새 ReplicaSet 이 생깁니다.

소유 관계를 직접 확인해 보십시오.

```bash
# Pod 의 소유자는 ReplicaSet 이다
kubectl get pod -n learn -l app=demo -o jsonpath='{.items[0].metadata.ownerReferences[0]}' | jq .

# ReplicaSet 의 소유자는 Deployment 다
kubectl get rs -n learn -o jsonpath='{.items[0].metadata.ownerReferences[0]}' | jq .
```

### 4. 02단계와 비교되는 실험 — Pod 을 지우면

```bash
kubectl get pods -n learn -l app=demo
kubectl delete pod -n learn -l app=demo --field-selector 'status.phase=Running' \
  --wait=false | head -1

# 바로 이어서 지켜보십시오
kubectl get pods -n learn -l app=demo -w
# Ctrl+C
```

02단계에서는 지운 Pod 이 사라진 채 끝났습니다. 지금은 즉시 새 Pod 이 생깁니다. ReplicaSet
이 개수를 세다가 부족한 것을 발견하고 채운 것입니다.

기록으로도 확인해 보십시오.

```bash
kubectl get events -n learn --sort-by='.lastTimestamp' | tail -5
```

### 5. 개수 바꾸기

```bash
kubectl scale deployment demo -n learn --replicas=5
kubectl get pods -n learn -l app=demo -o wide
```

어느 노드에 배치되었습니까? 두 워커에 나뉘어 있을 것입니다.

`scale` 은 명령형입니다. 선언형으로 하려면 매니페스트의 `replicas` 를 고쳐서 적용합니다.
**두 방식을 섞으면 나중에 값이 어긋납니다.** 12단계 GitOps 에서는 이 문제가 본격적으로
다뤄집니다. 지금은 매니페스트를 진실로 삼고 되돌려 놓으십시오.

```bash
kubectl apply -f manifests/01-deployment.yaml
kubectl get deploy demo -n learn
```

### 6. 새 버전 만들고 롤링 업데이트

```bash
cd ../../app
docker build -t learn-k8s/demo:v2 --build-arg VERSION=v2 .
kind load docker-image learn-k8s/demo:v2 --name learn
cd ../steps/03-workloads
```

이제 갱신합니다. **다른 터미널을 하나 더 열어** Pod 을 지켜보면서 하십시오.

```bash
# 터미널 A (지켜보기)
kubectl get pods -n learn -l app=demo -w

# 터미널 B (갱신)
kubectl set image deployment/demo -n learn demo=learn-k8s/demo:v2
kubectl rollout status deployment/demo -n learn
```

터미널 A 에서 새 Pod 이 하나씩 생기고 옛 Pod 이 하나씩 사라지는 과정이 보입니다.
`maxSurge`·`maxUnavailable` 값이 그 속도와 순서를 정합니다.

갱신 뒤 상태를 확인하십시오.

```bash
# ReplicaSet 이 두 개가 되었고, 옛 것은 0개로 남아 있습니다
kubectl get rs -n learn -o custom-columns=\
'NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'

# 각 Pod 이 실제로 어떤 이미지로 돌고 있는가
kubectl get pods -n learn -l app=demo \
  -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image,NODE:.spec.nodeName'
```

응답으로도 확인해 보십시오.

```bash
POD=$(kubectl get pod -n learn -l app=demo -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n learn "$POD" -- wget -qO- localhost:8080
```

`version` 이 `v2` 이고 `hostname` 이 Pod 이름과 같습니다.

> **아직 못 하는 것**: 갱신 중에 서비스가 정말 끊기지 않았는지는 아직 확인할 수 없습니다.
> 트래픽을 보낼 안정된 주소가 없기 때문입니다. 04단계에서 Service 를 붙인 뒤에 다시
> 확인합니다.

### 7. 이력과 롤백

```bash
kubectl rollout history deployment/demo -n learn
```

`CHANGE-CAUSE` 가 비어 있습니다. 매니페스트에 `kubernetes.io/change-cause` 주석을 달면
채워집니다. 실무에서는 이 주석에 배포 이유나 커밋 해시를 적어 둡니다.

되돌려 보십시오.

```bash
kubectl rollout undo deployment/demo -n learn
kubectl rollout status deployment/demo -n learn

kubectl get pods -n learn -l app=demo \
  -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image'
```

v1 으로 돌아왔습니다. 옛 ReplicaSet 이 남아 있었기 때문에 가능한 일입니다.

**경고가 하나 나왔을 것입니다.** 읽어 보십시오.

> resource deployments/demo was previously managed with 'kubectl apply'. Rolling back will
> not update the kubectl.kubernetes.io/last-applied-configuration annotation ...

`kubectl apply` 로 관리하던 리소스를 `rollout undo` 로 되돌리면, 클러스터의 실제 상태와
"마지막으로 적용한 설정" 기록이 어긋납니다. 그 상태에서 원래 매니페스트를 다시 적용하면
의도하지 않은 결과가 나올 수 있습니다.

실무에서 되돌리는 올바른 방법은 **매니페스트를 옛 내용으로 고쳐서 다시 적용하는 것**입니다.
`rollout undo` 는 급할 때 쓰는 응급 수단입니다. 이 어긋남을 근본적으로 없애는 방식이
12단계의 GitOps 입니다.

### 8. 갱신 전략을 바꿔서 차이 보기

```bash
kubectl apply -f manifests/02-deployment-strategy.yaml
kubectl get pods -n learn -l app=demo-strict -w
# 안정되면 Ctrl+C
```

이 Deployment 는 `maxUnavailable: 0`, `maxSurge: 1` 입니다. 갱신할 때 **먼저 새 Pod 을
띄우고 준비된 뒤에** 옛 Pod 을 지웁니다. 지켜보면서 갱신해 보십시오.

```bash
kubectl set image deployment/demo-strict -n learn demo=learn-k8s/demo:v2
```

`READY` 개수가 갱신 중에 원래 개수 아래로 내려가지 않는 것을 확인하십시오.

### 9. 흔한 함정 두 가지

**첫째, `kind load` 를 잊는 경우.**

```bash
kubectl set image deployment/demo -n learn demo=learn-k8s/demo:v99
kubectl get pods -n learn -l app=demo
```

`ErrImagePull` 또는 `ImagePullBackOff` 가 보입니다. 그런데 **기존 Pod 은 그대로 살아
있습니다.** Deployment 가 새 Pod 이 준비되지 않으면 옛 Pod 을 지우지 않기 때문입니다.
이것이 롤링 업데이트의 안전장치입니다.

```bash
kubectl rollout undo deployment/demo -n learn
```

**둘째, `latest` 태그.** 태그가 `latest` 이면 `imagePullPolicy` 의 기본값이 `Always` 가
되어, `kind load` 로 넣은 로컬 이미지를 무시하고 레지스트리에서 받으려 합니다. 그래서 이
학습에서는 태그를 항상 명시적으로 붙입니다(`v1`, `v2`). 실무에서도 `latest` 는 어떤 버전이
돌고 있는지 알 수 없게 만들므로 쓰지 않습니다.

### 10. 정리

`demo` Deployment 는 04단계에서 계속 씁니다. 남겨 두십시오.

```bash
kubectl delete -f manifests/02-deployment-strategy.yaml --ignore-not-found
kubectl get all -n learn
```

---

## 검증

```bash
./verify.sh
```

---

## 확인 질문

1. Deployment, ReplicaSet, Pod 은 각각 무엇을 책임집니까?
2. 이미지 태그를 바꿔 적용하면 왜 새 ReplicaSet 이 생깁니까? 옛 것은 왜 남습니까?
3. `maxUnavailable: 0` 과 `maxSurge: 1` 의 조합은 무엇을 보장하고, 그 대가는 무엇입니까?
4. 존재하지 않는 이미지로 갱신했을 때 서비스가 죽지 않은 이유는 무엇입니까?
5. `kubectl scale` 로 개수를 바꾼 뒤 원래 매니페스트를 다시 적용하면 어떻게 됩니까? 이것이
   왜 문제가 될 수 있습니까?

---

## 기록

`PROGRESS.md`를 갱신하십시오.
