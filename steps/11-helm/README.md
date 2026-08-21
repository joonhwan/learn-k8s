# 11단계 — Helm

> **이 단계의 문서는 아직 작성되지 않았습니다.** 진도가 여기에 도달하면, 그동안
> `PROGRESS.md`에 기록된 막혔던 지점을 반영해서 작성합니다. 아래는 다룰 범위입니다.

## 이 단계를 마치면

- 지금까지 만든 매니페스트를 하나의 차트로 묶어 배포할 수 있습니다.
- 값(values)으로 환경별 차이를 표현하고, 릴리스를 갱신·롤백할 수 있습니다.

## 다룰 내용

- 매니페스트를 그대로 복사해 환경별로 관리할 때 생기는 문제
- 차트의 구조: `Chart.yaml`, `values.yaml`, `templates/`, `_helpers.tpl`
- 템플릿 문법의 최소 집합과, 템플릿이 과해지면 오히려 읽기 어려워지는 지점
- `helm template` 로 결과를 먼저 확인하는 습관 (`kubectl diff` 와 같은 성격)
- `helm install`·`upgrade`·`rollback`·`history`. 릴리스 상태가 어디에 저장되는가
- `--set` 과 `-f values-prod.yaml` 의 사용 구분
- 남의 차트를 쓰는 경우: 저장소 추가, 버전 고정, `values` 를 덮어쓰는 방법
- Kustomize 와의 차이 (개념 비교만)

## 실습 순서

지금까지 `steps/` 아래에 흩어져 있던 Deployment·Service·Ingress·ConfigMap 을 하나의
차트로 옮깁니다. 결과가 이전과 같은지 `helm template` 출력과 기존 매니페스트를 비교해
확인합니다.
