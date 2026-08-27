# 01단계 — 선언형 모델과 컨트롤 플레인

## 이 단계를 마치면

- `kubectl`이 API 서버에 무엇을 보내는지 직접 눈으로 확인할 수 있습니다.
- 모든 쿠버네티스 오브젝트가 공통으로 갖는 네 부분을 설명할 수 있습니다.
- 컨트롤러 루프가 무엇을 반복하는지, 그것이 왜 선언형 모델의 핵심인지 설명할 수 있습니다.

---

## 개념

### 명령형과 선언형의 차이

Docker 를 쓸 때는 이렇게 말합니다. "컨테이너를 띄워라." 이것이 **명령형**입니다. 명령을
내리는 순간의 동작을 지시하고, 그 뒤의 일은 지시한 사람의 책임입니다. 컨테이너가 죽으면
누군가 다시 띄워야 합니다.

쿠버네티스에는 이렇게 말합니다. "이 이미지를 쓰는 복제본이 세 개 있어야 한다." 이것이
**선언형**입니다. 동작이 아니라 **바람직한 상태**를 적습니다. 그 상태를 만들고 유지하는
일은 클러스터가 맡습니다. 하나가 죽으면 클러스터가 알아서 새로 만듭니다.

이 차이는 사고방식 전체를 바꿉니다. 쿠버네티스를 쓸 때 우리가 하는 일은 대부분 "무엇을
해라"가 아니라 **"무엇이어야 한다"를 적는 것**입니다.

### API 서버가 중심이다

쿠버네티스의 모든 것은 API 서버를 지나갑니다. `kubectl`도, 컨트롤러도, kubelet도, 심지어
클러스터 자신의 부품들도 API 서버와 대화합니다.

```
kubectl ─┐
         │
컨트롤러 ─┼──> API 서버 ──> etcd (유일한 저장소)
         │
kubelet ─┘
```

이 구조가 뜻하는 바가 있습니다. **`kubectl`은 특별한 도구가 아닙니다.** REST API 를
호출하는 클라이언트일 뿐입니다. 이 단계에서 그것을 직접 확인합니다.

### 오브젝트의 네 부분

모든 오브젝트는 같은 골격을 갖습니다.

```yaml
apiVersion: v1        # 어떤 API 그룹과 버전에 속하는가
kind: ConfigMap       # 무슨 종류인가
metadata:             # 이름, 이름공간, 레이블, 주석
  name: demo
spec:                 # 바람직한 상태 — 사람이 쓴다
  ...
status:               # 현재 상태 — 시스템이 쓴다. 사람이 쓰지 않는다
  ...
```

`spec`과 `status`의 구분이 선언형 모델의 뼈대입니다. 사람은 `spec`에 바람을 적고, 시스템은
`status`에 현실을 적습니다. **둘 사이의 차이를 없애려고 계속 움직이는 것**이 클러스터의
일입니다.

### 컨트롤러 루프

컨트롤러는 아주 단순한 일을 끝없이 반복합니다.

1. **관찰한다** — API 서버에서 현재 상태를 읽는다.
2. **비교한다** — `spec`과 `status`가 다른가?
3. **조정한다** — 다르면 좁히는 방향으로 한 걸음 움직인다.

이 반복을 조정 루프(reconciliation loop)라고 합니다. 컨트롤러는 종류마다 다르지만
(Deployment 컨트롤러, ReplicaSet 컨트롤러, Node 컨트롤러 등) 하는 일의 모양은 모두 같습니다.

여기서 중요한 성질이 나옵니다. **같은 선언을 몇 번 적용해도 결과가 같습니다.** 이미
바람직한 상태라면 컨트롤러는 아무것도 하지 않습니다. 이 성질 덕분에 매니페스트를 Git 에
두고 반복해서 적용하는 방식(12단계 GitOps)이 성립합니다.

---

## 실습

### 1. `kubectl`이 실제로 보내는 요청 보기

`-v=8` 을 붙이면 주고받는 HTTP 요청이 다 보입니다.

```bash
kubectl -v=8 get nodes 2>&1 | grep -Ei '"Request"|"Response" status|accept:' | head -10
```

`url="https://127.0.0.1:포트/api/v1/nodes?limit=500"` 같은 줄이 보일 것입니다. 평범한 REST
호출입니다.

> 로그의 형식은 판올림을 따라 바뀝니다. v1.36 이전에는 `Response Status: 200 OK in 3 ms`
> 라는 평문이었지만 지금은 `"Response" status="200 OK"` 라는 구조화된 형식입니다. 위
> grep 이 아무것도 잡지 못하면 패턴을 의심하기 전에 `grep -i response` 로 실제로 무엇이
> 찍히는지 먼저 보십시오.

응답의 첫머리에서 `"kind":"Table"` 을 확인하십시오. **표를 만드는 주체는 `kubectl` 이
아니라 API 서버입니다.** 요청 헤더의 `Accept: application/json;as=Table;v=1;g=meta.k8s.io`
가 그 형식을 달라고 요구한 부분이고, 서버는 열 이름과 각 열의 설명까지 담아서 돌려줍니다.
`kubectl` 은 받은 표를 화면 폭에 맞춰 늘어놓을 뿐입니다.

이번에는 `kubectl` 없이 같은 정보를 가져와 보십시오.

```bash
# kubectl 을 단순한 인증 대리인으로만 쓰는 방법
kubectl get --raw /api/v1/nodes | jq '.items[].metadata.name'
```

원한다면 `curl` 로도 할 수 있습니다. 인증서를 직접 넘겨야 합니다.

```bash
kubectl proxy --port=8001 &
sleep 2
curl -s localhost:8001/api/v1/nodes | jq '.items[].metadata.name'
kill %1
```

**여기서 얻는 것**: 클러스터를 다루는 모든 도구(Helm, Argo CD, 대시보드)는 결국 이 API 를
호출합니다. 특별한 통로는 없습니다.

### 2. 어떤 종류의 오브젝트가 있는가

```bash
# 이 클러스터가 아는 모든 리소스 종류
kubectl api-resources | head -30

# 개수를 세어 보십시오
kubectl api-resources | wc -l

# 이름공간에 속하지 않는(클러스터 전체에 걸친) 것들
kubectl api-resources --namespaced=false
```

Node 와 Namespace 는 이름공간에 속하지 않습니다. 클러스터 전체에 하나씩 있는 것들이기
때문입니다. Pod 이나 ConfigMap 은 이름공간에 속합니다.

### 3. 필드를 찾는 방법 — 기억이 아니라 `explain`

쿠버네티스는 판올림이 잦고 필드가 바뀝니다. **기억에 의존하지 말고 클러스터에 물어보는
습관**을 들이십시오.

```bash
kubectl explain pod
kubectl explain pod.spec.containers
kubectl explain pod.spec.containers.livenessProbe
kubectl explain deployment.spec.strategy --recursive | head -20
```

이 명령은 지금 이 클러스터의 API 서버가 아는 진짜 구조를 보여 줍니다. 문서나 기억보다
정확합니다.

### 4. spec 과 status 를 눈으로 구분하기

```bash
# 노드 오브젝트의 spec (바람직한 상태 — 아주 짧습니다)
kubectl get node learn-worker -o jsonpath='{.spec}' | jq .

# status (현실 — 훨씬 깁니다)
kubectl get node learn-worker -o jsonpath='{.status.conditions}' | jq '.[] | {type, status}'
kubectl get node learn-worker -o jsonpath='{.status.capacity}' | jq .
```

`spec`은 사람이 정한 것(파드 CIDR, 스케줄 가능 여부)뿐이고, `status`에는 시스템이 관찰한
것(조건, 용량, 이미지 목록)이 들어 있습니다.

### 5. 선언형을 체험하기 — apply 를 두 번

```bash
cd steps/01-declarative-model

# 첫 적용
kubectl apply -f manifests/01-namespace.yaml
kubectl apply -f manifests/02-configmap.yaml

# 같은 파일을 그대로 다시 적용
kubectl apply -f manifests/02-configmap.yaml
```

두 번째에는 `unchanged`라고 나옵니다. **이미 바람직한 상태이므로 아무것도 하지 않은
것**입니다. 명령형 도구라면 두 번 실행하면 두 번 동작합니다. 선언형은 그렇지 않습니다.

이제 파일을 고치고 적용 전에 차이를 확인해 보십시오.

```bash
# manifests/02-configmap.yaml 의 greeting 값을 아무렇게나 바꿉니다
kubectl diff -f manifests/02-configmap.yaml     # 적용하면 무엇이 바뀌는가
kubectl apply -f manifests/02-configmap.yaml    # configured 로 바뀝니다
```

`kubectl diff`는 실무에서 사고를 막아 주는 습관입니다. 적용 전에 무엇이 바뀔지 봅니다.

### 6. 명령형 명령으로 매니페스트 초안 만들기

매니페스트를 처음부터 손으로 쓰는 사람은 없습니다. 명령으로 뽑아낸 뒤 고칩니다.

```bash
kubectl create configmap draft --from-literal=key=value \
  --dry-run=client -o yaml
```

`--dry-run=client` 는 클러스터에 보내지 않고 결과만 출력합니다. 설치 안내에서 `$do`
별칭을 만든 이유가 이것입니다.

```bash
kubectl create deployment web --image=nginx $do    # ~/.bashrc 에 별칭을 넣었다면
```

### 7. 컨트롤러 루프의 증거 찾기

컨트롤러가 실제로 일하는 모습을 로그에서 봅니다.

```bash
# 컨트롤러 매니저가 무엇을 하고 있는가
kubectl logs -n kube-system -l component=kube-controller-manager --tail=20

# 클러스터가 남긴 사건 기록
kubectl get events -A --sort-by='.lastTimestamp' | tail -15
```

`events` 는 09단계 장애 진단에서 가장 먼저 보게 될 정보입니다. 지금은 "클러스터가 스스로
한 일을 기록으로 남긴다"는 사실만 확인하십시오.

### 8. 정리

```bash
kubectl delete -f manifests/02-configmap.yaml
# 이름공간은 검증에서 쓰므로 남겨 둡니다
```

---

## 검증

```bash
./verify.sh
```

---

## 확인 질문

1. `kubectl`이 하는 일을 한 문장으로 설명하면 무엇입니까?
2. 같은 매니페스트를 두 번 적용했을 때 두 번째에 아무 일도 일어나지 않는 이유는
   무엇입니까? 그 성질이 왜 중요합니까?
3. `spec`과 `status`는 각각 누가 씁니까? 컨트롤러는 이 둘로 무엇을 합니까?
4. 어떤 리소스의 필드 이름이 기억나지 않을 때, 문서를 찾지 않고 확인하는 방법은
   무엇입니까?

---

## 기록

`PROGRESS.md`를 갱신하십시오.
