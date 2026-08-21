# 10단계 — 보안 기초

> **이 단계의 문서는 아직 작성되지 않았습니다.** 진도가 여기에 도달하면, 그동안
> `PROGRESS.md`에 기록된 막혔던 지점을 반영해서 작성합니다. 아래는 다룰 범위입니다.

## 이 단계를 마치면

- ServiceAccount 와 RBAC 로 권한을 최소한으로 좁힐 수 있습니다.
- NetworkPolicy 로 Pod 사이의 통신을 제한할 수 있습니다.
- 컨테이너를 root 가 아닌 사용자로, 필요한 권한만 갖게 실행할 수 있습니다.

## 다룰 내용

- 인증과 인가의 구분. 클러스터에는 사람 계정과 ServiceAccount 두 종류의 주체가 있다
- Role·ClusterRole 과 RoleBinding·ClusterRoleBinding 의 조합
- `kubectl auth can-i` 로 권한을 확인하는 방법
- Pod 에 마운트되는 ServiceAccount 토큰. 필요 없으면 끄는 것이 기본
- `securityContext`: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation`,
  capabilities 떨어내기
- Pod Security Admission (`baseline`·`restricted`)
- NetworkPolicy: **정책이 하나도 없으면 모두 통신 가능**이라는 기본값과, 정책을 붙이는
  순간 화이트리스트로 바뀌는 성질
- 이름공간을 경계로 삼는 설계

## 실습 앱에 준비된 것

`app/Dockerfile` 은 이미 UID 10001 의 비-root 사용자로 실행됩니다. `app/Dockerfile.distroless`
는 셸조차 없는 이미지를 만듭니다. 두 이미지에 같은 `securityContext` 를 적용해 보고,
`readOnlyRootFilesystem: true` 를 켰을 때 무엇이 깨지는지 확인합니다.
