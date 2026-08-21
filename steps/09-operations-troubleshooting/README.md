# 09단계 — 운영과 장애 진단

> **이 단계의 문서는 아직 작성되지 않았습니다.** 진도가 여기에 도달하면, 그동안
> `PROGRESS.md`에 기록된 막혔던 지점을 반영해서 작성합니다. 아래는 다룰 범위입니다.

## 이 단계를 마치면

- 고장 난 배포를 정해진 절차로 진단할 수 있습니다.
- 대표적인 장애 유형을 상태 문자열만 보고 갈래를 좁힐 수 있습니다.

## 다룰 내용

### 진단 절차

추측으로 설정을 바꿔 보는 방식이 아니라, 판정 근거를 하나씩 확보하는 순서를 익힙니다.

1. 상태 문자열을 읽는다 (`kubectl get pods`)
2. 사건 기록을 읽는다 (`kubectl describe`, `kubectl get events`)
3. 애플리케이션 로그를 읽는다 (`kubectl logs`, 재시작 전 로그는 `--previous`)
4. 안에서 확인한다 (`kubectl exec`, 셸이 없으면 `kubectl debug`)
5. 네트워크 경로를 따라간다 (Service → EndpointSlice → Pod)

### 장애 유형별 처방

| 상태 | 흔한 원인 | 먼저 볼 곳 |
|------|-----------|-----------|
| `Pending` | 자원 부족, 스케줄 제약, PVC 미결합 | `describe` 의 Events |
| `ImagePullBackOff` | 태그 오타, `kind load` 누락, 인증 실패 | Events 의 pull 메시지 |
| `CrashLoopBackOff` | 애플리케이션이 시작 직후 죽는다 | `logs --previous` |
| `OOMKilled` | 메모리 limit 초과 | `describe` 의 Last State |
| `Running` 인데 응답이 없다 | readiness 실패, 셀렉터 불일치, 포트 오류 | EndpointSlice 가 비었는지 |
| `Terminating` 에서 멈춤 | finalizer, 종료 신호 무시 | 종료 처리 코드 |

### 도구와 기법

- 셸이 없는 이미지를 진단하는 방법 (`kubectl debug` 로 임시 컨테이너 붙이기)
- 노드 유지 보수: `cordon`, `drain`, `uncordon`
- `k9s` 로 상태를 한눈에 보기
- 리소스 사용량 확인 (`kubectl top`, metrics-server 필요)

## 이 단계의 실습 방식

일부러 망가진 매니페스트 몇 개를 제공하고, **답을 보지 않고** 절차대로 진단해 원인을 찾는
방식으로 진행합니다. 02단계 7번 실습(`05-pod-broken.yaml`)에서 한 번 맛본 방식입니다.

이 단계에서는 클러스터를 지우고 다시 만들지 마십시오. 망가진 상태를 진단하는 것이
목적입니다.
