# 05단계 — Ingress

> **이 단계의 문서는 아직 작성되지 않았습니다.** 진도가 여기에 도달하면, 그동안
> `PROGRESS.md`에 기록된 막혔던 지점을 반영해서 작성합니다. 아래는 다룰 범위입니다.

## 이 단계를 마치면

- Ingress 컨트롤러를 설치하고 호스트·경로 기반 라우팅을 구성할 수 있습니다.
- Service 만으로 외부 노출을 처리할 때의 한계를 설명할 수 있습니다.

## 다룰 내용

- Ingress 리소스와 Ingress 컨트롤러의 차이 (규칙을 적는 것과 실제로 처리하는 것)
- ingress-nginx 설치 (kind 배포본)
- 호스트 기반 라우팅과 경로 기반 라우팅
- `pathType` 세 가지의 차이
- TLS 종료 (자체 서명 인증서로 실습)
- Gateway API 가 Ingress 를 대체해 가고 있는 흐름 (개념만)

## 준비된 환경

`cluster/kind-config.yaml` 에 이미 두 가지가 들어 있습니다. 그래서 이 단계에서 클러스터를
다시 만들 필요가 없습니다.

- 컨트롤 플레인 노드의 `ingress-ready=true` 레이블 — ingress-nginx 의 kind 배포본이 이
  레이블이 붙은 노드에만 컨트롤러를 배치합니다.
- 호스트의 80·443 포트를 그 노드로 전달하는 `extraPortMappings` — 그래서
  `http://localhost` 로 접속할 수 있습니다.

확인: `docker port learn-control-plane`
