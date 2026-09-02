# k8s-baseline

![License](https://img.shields.io/badge/license-MIT-blue) ![Helmfile](https://img.shields.io/badge/helmfile-v1-blue) ![Kustomize](https://img.shields.io/badge/kustomize-ArgoCD-blue)

쿠버네티스 클러스터를 세울 때 반복해서 쓰는 구성 모음입니다. 관측 스택, 앱 배포 패턴, 자격증명 주입, 운영 규칙 — 실제 운영 클러스터에서 쓰는 구성에서 환경 값만 `<placeholder>`로 바꾼 것입니다.

단순 보일러플레이트가 아니라 **각 구성에 판단이 들어 있습니다.** liveness가 왜 httpGet이어야 하는지, HPA 워크로드에 왜 replicas를 안 쓰는지 같은 것들이고, 근거는 [docs/](docs/)에 있습니다.

## Contents

| 경로 | 내용 | 진입점 |
|------|------|--------|
| [monitoring/](monitoring/) | kube-prometheus-stack + Loki + Alloy 설치 helmfile. Alertmanager Slack 라우팅, Grafana ingress, OOM·재시작·CPU throttling 알림 룰 포함 | `helmfile -e dev apply` |
| [workloads/](workloads/) | kustomize base/overlay + ArgoCD Application. probe·HPA·리소스·Secret 주입이 표준대로 들어간 예시 앱 | `kubectl kustomize workloads/overlays/dev` |
| [credentials/](credentials/) | Vault → External Secrets Operator 패턴. ns 라벨만으로 pull secret 자동 배포, terraform은 secret 메타만 추적 | 파일별 주석 |
| [docs/](docs/) | probe 표준, 운영 규칙(sync 전 이미지 대조, 배포 완료 판정 등) | — |

## 구성에 들어 있는 판단

| 주제 | 판단 | 이유 |
|------|------|------|
| liveness probe | httpGet + timeoutSeconds 명시 | tcpSocket은 포트 응답을 커널이 대신해서 앱이 멈춰도(행) 통과한다. 기본 timeout 1초는 부하 시 오탐 재시작 |
| readiness probe | 새 서비스 기본값 | 없으면 앱이 포트를 바인딩하기 전에 Endpoint에 등록돼 배포·스케일업 때 connection refused |
| HPA 워크로드 | base에 `spec.replicas` 없음 | 있으면 sync마다 그 값으로 강제돼 HPA와 영구 충돌 |
| 이미지 태그 | overlay에 pin | latest면 sync가 곧 배포가 아니게 되고, 우회 배포가 섞이면 sync가 운영 이미지를 되감는다 |
| helmfile | kubeContext를 `.Environment.Name`으로 고정 | 미지정이면 현재 kubectl 컨텍스트에 적용된다 — `-e dev`가 prod에 들어갈 수 있다 |
| 앱 자격증명 | Vault → ESO → Secret, 값은 CLI 관리 | terraform은 메타만 추적 — 값이 state에 남지 않고, plan이 값 변경을 드리프트로 오인하지 않는다 |
| pull secret | ns 라벨 → ClusterExternalSecret | 새 namespace마다 secret을 손으로 만들지 않는다 |
| 리소스 | CPU request만, limit은 memory만 | CPU limit은 CFS throttling을 만든다 |

## Requirements

- Kubernetes 1.28+, helmfile v1, kustomize (kubectl 내장)
- External Secrets Operator, cert-manager (사전 설치)
- ArgoCD (workloads/ 를 GitOps로 쓸 경우)

## Usage

**관측 스택** — `monitoring/env/{dev,prod}.yaml`의 grafana host·ingress class·storage class와 helmfile의 `<dev-context>`/`<prod-context>`를 교체한 뒤:

```bash
cd monitoring
helmfile -e dev diff    # 반드시 diff 먼저
helmfile -e dev apply
```

**앱 배포** — `workloads/base/example-app/`을 복사해 새 앱을 만들고, overlay에서 이미지 태그를 pin합니다. ArgoCD로 관리하면 `workloads/argocd/application.yaml`을 참고해 Application을 등록합니다. sync 전에는 [docs/operations.md](docs/operations.md)의 이미지 대조 절차를 따릅니다.

**자격증명** — `credentials/clustersecretstore-example.yaml`로 Vault 접점을 만들면, 앱 Secret은 base의 ExternalSecret이, 레지스트리 pull secret은 namespace에 `registry-pull: enabled` 라벨을 붙이는 것으로 끝납니다.

## 같이 보기

이 구성 위에서 도는 장애 분석 봇: [log-autopsy](https://github.com/semi0x3b/log-autopsy) — 장애 알림에 원인 분석을 자동으로 붙입니다.

## License

MIT
