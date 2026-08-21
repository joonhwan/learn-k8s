# 실습용 이미지입니다. 두 단계로 나뉘어 있습니다.
#
#   1단계(build): Go 툴체인이 든 이미지에서 정적 바이너리를 만듭니다.
#   2단계(런타임): 바이너리만 alpine 위에 올립니다.
#
# 이렇게 나누면 최종 이미지에 Go 컴파일러와 소스가 남지 않습니다. 그 결과 이미지가 작아지고,
# 공격 표면도 줄어듭니다. 이것이 멀티스테이지 빌드를 쓰는 이유입니다.
#
# 로컬에 Go 를 설치하지 않아도 됩니다. 빌드는 컨테이너 안에서 이루어집니다.
#
# 빌드:
#   docker build -t learn-k8s/demo:v1 --build-arg VERSION=v1 .
#
# 런타임 베이스를 alpine 으로 고른 이유는 셸이 들어 있어서 `kubectl exec` 로 들어가
# 안을 들여다볼 수 있기 때문입니다. 실무에서 권장되는 더 작고 단단한 구성은
# Dockerfile.distroless 를 보십시오.

FROM golang:1-alpine AS build

WORKDIR /src

# 의존성 파일을 먼저 복사하면, 소스만 바뀔 때 의존성 계층을 캐시에서 재사용합니다.
# 이 앱은 표준 라이브러리만 쓰므로 내려받을 것이 없지만, 계층 순서의 원칙은 같습니다.
COPY go.mod ./
RUN go mod download

COPY *.go ./

# VERSION 을 바꿔 가며 빌드하면 롤링 업데이트를 눈으로 확인할 수 있습니다.
ARG VERSION=dev

# CGO_ENABLED=0 으로 정적 링크합니다. 그래야 런타임 이미지에 C 라이브러리가 없어도 됩니다.
# -trimpath 는 빌드 경로를 지워 재현 가능한 빌드에 가깝게 만듭니다.
# -s -w 는 디버그 정보를 떼어 바이너리를 줄입니다.
RUN CGO_ENABLED=0 GOOS=linux go build \
      -trimpath \
      -ldflags="-s -w -X main.version=${VERSION}" \
      -o /out/demo .

# ---------------------------------------------------------------------------

FROM alpine:3

# root 로 실행하지 않습니다. 10단계 securityContext 실습에서 이 사용자를 다시 다룹니다.
RUN adduser -D -u 10001 demo

COPY --from=build /out/demo /usr/local/bin/demo

USER 10001

# 문서 역할만 하는 선언입니다. 실제 노출은 쿠버네티스의 Service 가 담당합니다.
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/demo"]
