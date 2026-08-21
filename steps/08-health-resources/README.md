# 08단계 — 헬스체크와 리소스

> **이 단계의 문서는 아직 작성되지 않았습니다.** 진도가 여기에 도달하면, 그동안
> `PROGRESS.md`에 기록된 막혔던 지점을 반영해서 작성합니다. 아래는 다룰 범위입니다.

## 이 단계를 마치면

- 프로브 세 종류를 구분해서 설정하고, 각각이 실패했을 때 무엇이 달라지는지 설명할 수
  있습니다.
- requests 와 limits 를 설정하고 QoS 등급과 축출 순서에 미치는 영향을 관찰할 수 있습니다.
- 진짜 무중단 배포를 완성할 수 있습니다.

## 다룰 내용

- `livenessProbe` 실패 → **컨테이너 재시작**
- `readinessProbe` 실패 → **Service 대상 목록에서 제외** (재시작하지 않음)
- `startupProbe` → 시작이 느린 애플리케이션을 위해 liveness 판정을 늦춘다
- 프로브 설정값(`initialDelaySeconds`, `periodSeconds`, `failureThreshold`)의 실제 효과
- `requests` 와 `limits` 의 차이. requests 는 스케줄링 기준, limits 는 실행 시 상한
- QoS 등급(`Guaranteed`·`Burstable`·`BestEffort`)과 자원이 부족할 때의 축출 순서
- CPU 제한과 메모리 제한의 성질 차이 (CPU 는 조절, 메모리 초과는 OOMKilled)
- metrics-server 설치와 HPA 로 부하에 따라 개수를 늘리기
- `nodeSelector`·affinity·taint 와 toleration
- 종료 처리: `terminationGracePeriodSeconds`, preStop 훅, 그리고 readiness 를 먼저 내리는
  순서가 왜 중요한가

## 실습 앱에 준비된 것

- `GET /healthz`, `GET /readyz` — 프로브가 찌를 엔드포인트
- `POST /toggle/live` — liveness 를 실패로 만들어 **재시작**을 관찰
- `POST /toggle/ready` — readiness 를 실패로 만들어 **트래픽에서 빠지는 것**을 관찰
- `GET /burn?seconds=30&threads=4` — CPU 를 소모해 limits 와 HPA 를 관찰
- `STARTUP_DELAY`·`READY_AFTER`·`SHUTDOWN_DELAY` 환경 변수 — 시작과 종료의 타이밍을 조절

## 앞 단계에서 남겨 둔 질문

- **03단계**: `maxUnavailable: 0` 전략만으로는 무중단이 보장되지 않는다고 했습니다.
  readinessProbe 가 없으면 "준비되었다"의 판단이 부실하기 때문입니다. 이 단계에서 프로브를
  붙여 진짜 무중단을 완성합니다.
- **앱의 종료 처리**: `SHUTDOWN_DELAY` 를 0으로 바꿔 가며 갱신 중 502 가 나는지 측정합니다.
