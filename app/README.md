# 실습용 애플리케이션

03단계에서 도입해 이후 모든 단계에서 사용하는 작은 Go 웹 서버입니다. 표준 라이브러리만
쓰므로 의존성이 없고, 로컬에 Go 를 설치할 필요도 없습니다. 빌드는 컨테이너 안에서 합니다.

이 앱의 목적은 **클러스터에서 관찰하고 싶은 상황을 요청 하나로 만들어 내는 것**입니다.
프로브를 일부러 실패시키고, 프로세스를 죽이고, CPU 를 소모하는 엔드포인트가 그래서 있습니다.

## 빌드와 실행

```bash
cd app

# 이미지 빌드 (VERSION 을 바꾸면 응답의 version 값이 바뀝니다)
docker build -t learn-k8s/demo:v1 --build-arg VERSION=v1 .

# 컨테이너로 먼저 확인 (쿠버네티스 없이)
docker run --rm -p 8080:8080 -e MESSAGE="첫 실행" learn-k8s/demo:v1
curl -s localhost:8080 | jq .
```

kind 클러스터는 로컬 Docker 이미지를 자동으로 보지 못합니다. 만든 이미지를 노드에 실어
넣어야 합니다. 이 점은 03단계에서 자세히 다룹니다.

```bash
kind load docker-image learn-k8s/demo:v1 --name learn
```

## 엔드포인트

| 메서드 | 경로 | 용도 | 쓰이는 단계 |
|---|---|---|---|
| GET | `/` | Pod 이름·버전·누적 요청 수를 JSON 으로 | 03, 04 |
| GET | `/healthz` | liveness 프로브 | 08 |
| GET | `/readyz` | readiness 프로브 | 08 |
| POST | `/toggle/ready` | ready 상태를 뒤집어 트래픽에서 빠지게 함 | 08 |
| POST | `/toggle/live` | live 상태를 뒤집어 재시작을 유발 | 08 |
| POST | `/crash` | 프로세스 즉시 종료 (CrashLoopBackOff 관찰) | 09 |
| GET | `/burn?seconds=5&threads=2` | CPU 소모 | 08 |
| GET | `/sleep?seconds=3` | 응답 지연 | 08, 09 |
| GET | `/env` | 환경 변수 전체 출력 | 06 |
| GET | `/file?path=...` | 파일 내용 출력 | 06, 07 |

`/env` 와 `/file` 은 Secret 의 내용까지 그대로 드러냅니다. "Secret 은 암호화가 아니다"를
직접 확인하기 위한 장치이므로, 실제 서비스에는 이런 엔드포인트를 두면 안 됩니다.

## 환경 변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `PORT` | `8080` | 수신 포트 |
| `APP_VERSION` | 빌드 시 주입값 | 버전 표시를 덮어씀 |
| `MESSAGE` | 없음 | 응답에 함께 실어 보낼 문구 (ConfigMap 실습) |
| `STARTUP_DELAY` | `0` | 시작을 이 초만큼 지연 (startupProbe 실습) |
| `READY_AFTER` | `0` | 시작 후 이 초가 지난 뒤 ready 가 됨 |
| `SHUTDOWN_DELAY` | `5` | SIGTERM 을 받은 뒤 기다릴 시간 |

`POD_NAME`·`POD_IP`·`POD_NAMESPACE`·`NODE_NAME` 은 Downward API 로 주입하면 응답에
채워집니다. 06단계에서 다룹니다.

## 종료 처리를 이렇게 만든 이유

SIGTERM 을 받으면 이 앱은 다음 순서로 움직입니다.

1. readiness 를 실패로 바꿉니다. 그러면 Service 의 대상 목록에서 빠집니다.
2. `SHUTDOWN_DELAY` 만큼 기다립니다. 이미 전달 중인 요청이 끝날 시간입니다.
3. 그다음에 HTTP 서버를 닫습니다.

이 순서가 무중단 배포의 핵심입니다. 신호를 받자마자 서버를 닫아 버리면, 아직 대상 목록에서
빠지지 않은 Pod 으로 새 요청이 흘러들어 502 가 발생합니다. 08단계에서 이 지연을 0으로
바꿔 가며 차이를 직접 확인합니다.

## 두 가지 Dockerfile

| 파일 | 런타임 베이스 | 특징 |
|---|---|---|
| `Dockerfile` | `alpine:3` | 셸이 있어 `kubectl exec` 로 들어가 볼 수 있습니다. 학습에 씁니다. |
| `Dockerfile.distroless` | `gcr.io/distroless/static-debian12:nonroot` | 셸이 없어 작고 단단합니다. 실무 권장 구성입니다. |

09단계에서 셸이 없는 이미지를 어떻게 진단하는지(`kubectl debug`) 다룹니다.
