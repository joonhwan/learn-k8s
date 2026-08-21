# 07단계 — 스토리지

> **이 단계의 문서는 아직 작성되지 않았습니다.** 진도가 여기에 도달하면, 그동안
> `PROGRESS.md`에 기록된 막혔던 지점을 반영해서 작성합니다. 아래는 다룰 범위입니다.

## 이 단계를 마치면

- PV·PVC·StorageClass 의 관계를 설명하고 동적 프로비저닝을 사용할 수 있습니다.
- StatefulSet 이 Deployment 와 무엇이 다른지, 왜 필요한지 설명할 수 있습니다.

## 다룰 내용

- `emptyDir` 의 한계 (Pod 이 사라지면 함께 사라진다 — 02단계에서 이미 사용해 봤습니다)
- PersistentVolume 과 PersistentVolumeClaim 의 역할 분담 (제공하는 쪽과 요구하는 쪽)
- StorageClass 와 동적 프로비저닝. kind 의 기본 StorageClass (`standard`, local-path)
- 접근 모드(`ReadWriteOnce` 등)와 그 의미. 노드 단위 제약이 왜 생기는가
- 반환 정책(`Delete`·`Retain`)과 데이터를 잃는 사고
- StatefulSet: 안정된 이름, 순서 있는 기동, Pod 마다 붙는 고유 볼륨
  (`volumeClaimTemplates`)
- headless Service 와 StatefulSet 의 조합

## WSL 환경에서 주의할 점

`hostPath` 볼륨을 실습할 때는 `/mnt/d/...`(Windows 파일시스템) 대신 WSL 네이티브
경로(`/home/mirero/...`)를 씁니다. `/mnt/d` 는 9p 파일시스템이라 성능이 낮고 소유권·권한이
리눅스와 다르게 보여서, 실습 결과가 개념 때문이 아니라 파일시스템 때문에 달라질 수
있습니다.
