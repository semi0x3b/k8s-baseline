# GitOps 저장소 레이아웃

이 저장소의 workloads/ 는 앱 하나의 패턴입니다. 실제 운영에서는 그 패턴이 여러 앱·여러 환경으로
늘어나며, 그때의 저장소 구조를 여기 정리합니다.

## 저장소는 셋으로 나눕니다

| 저장소 | 담는 것 | 변경 주체 |
|--------|---------|-----------|
| 앱 repo (서비스별) | 애플리케이션 코드 + Dockerfile | 개발자, CI가 이미지 빌드 |
| gitops repo | kustomize 매니페스트 + ArgoCD Application | CI(이미지 태그 갱신), 운영자 |
| infra repo | terraform + 관측 스택 helmfile | 운영자 |

앱 코드와 매니페스트를 한 repo에 두면 이미지 태그 갱신 커밋이 앱 히스토리를 덮습니다.
관측 스택을 gitops repo에 두지 않는 이유는 ArgoCD 자신이 죽었을 때도 배포할 수단(helmfile)이
필요하기 때문입니다.

## gitops repo 디렉토리

```
gitops/
├── apps/                        # ArgoCD Application 정의 모음
│   ├── dev/                     #   환경별로 분리
│   └── prod/
├── workloads/
│   ├── base/<app>/              # 이 저장소의 workloads/base 패턴
│   └── overlays/
│       ├── dev/<app>/           # 환경별 이미지 태그 pin + 환경 차이
│       └── prod/<app>/
└── cluster-addons/              # ingress controller·cert-manager 등
    ├── dev/                     # 클러스터 공용 구성요소의 Application
    └── prod/
```

## 환경과 브랜치 매핑

targetRevision 을 환경별로 다르게 두는 방식(dev=develop, prod=main)을 쓴다면
**Application 정의에 그 매핑이 박혀 있다는 걸 팀 전체가 알아야 합니다** — develop 에만
머지하고 prod 가 왜 안 바뀌는지 찾는 일이 반복됩니다. 단일 브랜치 + 환경 디렉토리 방식이
혼동은 적습니다. 어느 쪽이든 한 저장소 안에서 통일하세요.

## sync 정책

- 새로 시작한다면 자동 sync 보다 수동 sync 를 권합니다. 자동 sync 는 "git 을 우회한 배포가
  없다"는 규율이 선 뒤에 켜야 안전합니다 — 우회 배포가 있는 상태에서 자동 sync 는
  운영 이미지를 예고 없이 과거로 되감습니다 (operations.md 의 이미지 대조 규칙).
- 클러스터 공용 구성요소(cluster-addons)는 앱보다 보수적으로 — 수동 sync 유지를 권합니다.

## Application 을 묶어서 관리하기

환경당 Application 이 수십 개가 되면 개별 kubectl apply 대신 "Application 들을 생성하는
상위 차트" 하나로 묶는 편이 낫습니다 (app-of-apps 패턴). 환경별 values 파일 하나가
그 환경의 앱 목록·브랜치·경로를 결정하게 됩니다.
