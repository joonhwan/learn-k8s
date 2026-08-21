# 00단계 — 환경 구성

## 이 단계를 마치면

- 도구를 설치하고 세 개의 노드로 된 클러스터를 띄울 수 있습니다.
- 클러스터의 노드가 실제로 무엇인지 확인할 수 있습니다.
- `kubectl`이 어떤 파일을 읽고 어디에 접속하는지 설명할 수 있습니다.

---

## 개념

### 클러스터란 무엇인가

쿠버네티스 클러스터는 두 부분으로 나뉩니다.

**컨트롤 플레인**은 "무엇이 어떤 상태여야 하는가"를 관리하는 쪽입니다. 사용자의 요청을
받고(API 서버), 그 요청을 저장하고(etcd), 저장된 바람과 현재 상태를 맞추려고 계속
움직이는(컨트롤러, 스케줄러) 부품들이 여기 있습니다.

**워커 노드**는 실제로 컨테이너를 돌리는 쪽입니다. 각 노드에는 컨테이너를 띄우고 돌보는
kubelet, 그리고 서비스 트래픽을 알맞은 곳으로 보내는 kube-proxy가 있습니다.

### kind가 노드를 만드는 방식

보통 노드는 물리 서버나 가상 머신입니다. kind는 그 자리에 **Docker 컨테이너**를 씁니다.
컨테이너 하나가 노드 하나 역할을 하고, 그 안에서 다시 컨테이너(Pod)를 돌립니다.

노드가 컨테이너이므로 생성과 삭제가 아주 빠릅니다. 그래서 학습에 적합합니다. 클러스터를
망가뜨렸으면 지우고 다시 만드는 편이 원인을 찾는 것보다 빠릅니다.

이 학습에서 쓰는 구성은 컨트롤 플레인 1개와 워커 2개입니다. 워커를 두 개 둔 이유는
스케줄링이 실제로 일어나는 모습을 보기 위함입니다. 노드가 하나면 "어디에 배치되는가"라는
개념 자체를 관찰할 수 없습니다.

### kubeconfig — `kubectl`이 읽는 파일

`kubectl`은 그 자체로 아무것도 모릅니다. **API 서버에 HTTP 요청을 보내는 클라이언트**일
뿐입니다. 어디로 보낼지, 어떤 신분으로 보낼지는 kubeconfig 파일에서 읽습니다. 기본 위치는
`~/.kube/config`입니다.

kubeconfig에는 세 종류의 항목이 있습니다.

| 항목 | 담고 있는 것 |
|------|--------------|
| cluster | API 서버 주소와 서버 인증서 |
| user | 내 신분을 증명할 인증서나 토큰 |
| context | 어떤 cluster에 어떤 user로, 어떤 namespace를 기본으로 접속할지 묶은 것 |

여러 클러스터를 다룰 때는 context를 갈아 끼웁니다. **지금 어떤 context를 보고 있는지
모르는 상태가 사고의 시작점**이므로, 명령을 실행하기 전에 확인하는 습관을 들이십시오.

---

## 실습

### 1. Windows 쪽 잔재 확인

이 실습에서 가장 먼저 정리할 것은 제거된 Docker Desktop의 잔재입니다. **Windows 터미널
(PowerShell)** 에서 확인하십시오.

```powershell
Get-Command kubectl -All | Select-Object Source
```

`C:\Program Files\Docker\Docker\resources\bin\kubectl` 이 나올 것입니다. 이 실행 파일은
Windows 쪽 `%USERPROFILE%\.kube\config`를 읽습니다. WSL에서 만들 클러스터의 접속 정보는
WSL 쪽 `~/.kube/config`에 기록되므로, 이 `kubectl`로는 클러스터가 보이지 않습니다.

문제는 **오류가 나지 않는다**는 점입니다. 명령은 성공하고 결과만 비어 있습니다. 그래서
원인을 찾기 어렵습니다.

정리 방법은 두 가지입니다.

- **권장**: 클러스터 관련 명령을 항상 WSL 셸 안에서 실행합니다. Windows 쪽 파일은 그대로
  두어도 됩니다. 헷갈릴 일 자체를 없애려면 아래 방법을 쓰십시오.
- Windows PATH에서 `C:\Program Files\Docker\Docker\resources\bin` 항목을 제거합니다.
  (시스템 속성 → 환경 변수)

`docker-desktop` WSL 배포판도 멈춘 상태로 남아 있습니다. 쓰지 않으므로 지워도 됩니다.

```powershell
wsl --list --verbose
wsl --unregister docker-desktop   # 지우기로 결정했다면
```

### 2. 여기서부터는 WSL 안에서

```bash
wsl
cd /mnt/d/workspace/prj/oss/mine/learn-k8s
```

프롬프트가 `mirero@...`로 바뀌었는지 확인하십시오. 이제부터 모든 명령은 이 셸 안에서
실행합니다.

### 3. 도구 설치

```bash
./scripts/setup-tools.sh
```

`sudo` 비밀번호를 물어봅니다. 스크립트는 `kubectl`·`kind`·`helm`·`k9s`·`jq`를
`/usr/local/bin`에 설치합니다. 버전을 하드코딩하지 않고 공식 배포 채널에서 최신 안정
버전을 조회하며, `kubectl`은 체크섬까지 검증합니다.

설치가 끝나면 화면에 셸 설정 스니펫이 나옵니다. **이것을 `~/.bashrc`에 붙이는 것을
권합니다.** 자동완성과 `k` 별칭은 이후 모든 단계의 실습 속도를 크게 바꿉니다.

```bash
# 안내대로 ~/.bashrc 를 고친 뒤
source ~/.bashrc
kubectl version --client
```

### 4. 클러스터 생성

```bash
./scripts/cluster-up.sh
```

처음 실행할 때는 노드 이미지(1.3GB 남짓)를 내려받으므로 몇 분 걸립니다.

**첫 시도가 실패할 수 있습니다.** 스크립트가 자동으로 한 번 더 시도하며, 그때는
성공합니다. 이 실패에는 이유가 있고, 그 이유가 그대로 학습 재료입니다.

> 노드 이미지를 갓 내려받은 직후에 세 개의 노드 컨테이너를 동시에 펼치면 디스크 입출력이
> 몰립니다. 그러면 etcd 와 API 서버의 기동이 늦어집니다. `kubeadm`(클러스터를 초기화하는
> 도구)은 API 서버가 응답하기를 기다리는데, 그 대기 시간을 넘기면 초기화를 포기합니다.
> 이미지가 캐시된 두 번째 시도에서는 같은 설정으로 정상 생성됩니다.
>
> 여기서 알아 둘 것은 **쿠버네티스의 기동에는 순서가 있다**는 점입니다.
> etcd 가 먼저 떠야 API 서버가 뜨고, API 서버가 떠야 나머지가 움직입니다. 09단계에서
> 장애를 진단할 때 이 순서가 판단의 기준이 됩니다.

### 5. 노드가 실제로 무엇인지 확인

```bash
kubectl get nodes -o wide
```

세 개가 보입니다. 이제 같은 것을 Docker 쪽에서 보십시오.

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

`learn-control-plane`, `learn-worker`, `learn-worker2` 컨테이너가 있습니다. **쿠버네티스가
말하는 노드가 곧 이 컨테이너들**입니다.

노드 안으로 들어가 볼 수도 있습니다.

```bash
docker exec -it learn-control-plane bash
# 컨테이너 안에서:
crictl ps          # 이 노드에서 돌고 있는 컨테이너들
ls /etc/kubernetes/manifests/   # 컨트롤 플레인 부품들의 정의
exit
```

`/etc/kubernetes/manifests/`에 있는 YAML 파일들이 API 서버·etcd·스케줄러·컨트롤러
매니저의 정의입니다. 이들은 API 서버 없이도 kubelet이 직접 띄우는 **정적 Pod**입니다.
API 서버 자신을 API 서버로 만들 수는 없으므로, 이 방식이 필요합니다.

### 6. kubeconfig 들여다보기

```bash
# 지금 어떤 context 를 보고 있는가 (가장 중요한 확인)
kubectl config current-context

# 전체 구조
kubectl config view

# 접속 주소만
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'; echo
```

주소가 `https://127.0.0.1:포트번호` 형태입니다. 이 포트를 Docker 쪽에서 확인해 보십시오.

```bash
docker port learn-control-plane
```

`6443/tcp -> 127.0.0.1:포트번호` 가 보입니다. 노드 컨테이너 안의 API 서버 포트가 호스트로
전달되어 있고, `kubectl`은 그 주소로 접속합니다. `80`과 `443`도 전달되어 있는데, 이것은
05단계 Ingress 실습을 위해 미리 열어 둔 것입니다.

### 7. 클러스터를 지웠다 다시 만들어 보기

지금 한 번 해 보십시오. 이후 단계에서 마음 편히 실험할 수 있게 됩니다.

```bash
./scripts/cluster-down.sh
docker ps          # 노드 컨테이너가 사라진 것을 확인
./scripts/cluster-up.sh
```

두 번째 생성은 이미지가 캐시되어 있어 1~2분이면 끝납니다.

---

## 검증

```bash
./verify.sh
```

또는 저장소 루트에서 `./scripts/verify.sh 00` 으로도 실행할 수 있습니다.

---

## 확인 질문

답할 수 있으면 다음 단계로 넘어가십시오.

1. `kubectl get nodes`가 보여 주는 노드는 이 환경에서 실제로 무엇입니까?
2. Windows 셸에서 `kubectl get nodes`를 실행하면 왜 클러스터가 보이지 않습니까? 오류가
   나지 않는 것이 왜 더 위험합니까?
3. `/etc/kubernetes/manifests/`에 있는 정의들은 왜 일반적인 방식이 아니라 정적 Pod으로
   떠야 합니까?
4. 컨트롤 플레인과 워커 노드는 각각 무엇을 담당합니까?

---

## 기록

`PROGRESS.md`의 '환경 기록'에 실제 버전을 적고, 00단계를 완료로 표시하십시오. 막혔던
지점이 있었다면 그것도 함께 적으십시오.
