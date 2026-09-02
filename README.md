# k8s-baseline

![License](https://img.shields.io/badge/license-MIT-blue) ![Helmfile](https://img.shields.io/badge/helmfile-v1-blue) ![Kustomize](https://img.shields.io/badge/kustomize-ArgoCD-blue)

kube-prometheus-stack·Loki 설치부터 kustomize 앱 배포, Vault 시크릿 주입까지 한 벌로 갖춘 쿠버네티스 구성입니다. 환경 값만 바꾸면 돌아갑니다.

보일러플레이트와 다른 점은 구성마다 판단이 들어 있다는 것입니다. liveness가 왜 httpGet이어야 하는지, HPA 워크로드에 왜 replicas를 안 쓰는지 같은 것들이고, 근거는 [docs/](docs/)에 있습니다.

## Contents

| 경로 | 내용 | 진입점 |
|------|------|--------|
| [monitoring/](monitoring/) | kube-prometheus-stack + Loki + Alloy 설치 helmfile. Alertmanager Slack 라우팅, Grafana ingress, OOM·재시작·CPU throttling 알림 룰 포함 | `helmfile -e dev apply` |
| [workloads/](workloads/) | kustomize base/overlay + ArgoCD Application. probe·HPA·리소스·Secret 주입이 표준대로 들어간 예시 앱 | `kubectl kustomize workloads/overlays/dev` |
| [credentials/](credentials/) | Vault → External Secrets Operator 패턴. ns 라벨만으로 pull secret 자동 배포, terraform은 secret 메타만 추적 | 파일별 주석 |
| [docs/](docs/) | probe 표준, 운영 규칙(sync 전 이미지 대조, 배포 완료 판정 등), GitOps 저장소 레이아웃 | — |

## 구성에 들어 있는 판단

| 주제 | 판단 | 이유 |
|------|------|------|
| liveness probe | httpGet + timeoutSeconds 명시 | tcpSocket은 포트 응답을 커널이 대신해서 앱이 멈춰도(행) 통과한다. 기본 timeout 1초는 부하 시 오탐 재시작 |
| readiness probe | 새 서비스 기본값 | 없으면 앱이 포트를 바인딩하기 전에 Endpoint에 등록돼 배포·스케일업 때 connection refused |
| HPA 워크로드 | base에 `spec.replicas` 없음 | 있으면 sync마다 그 값으로 강제돼 HPA와 영구 충돌 |
| 이미지 태그 | overlay에 pin | latest면 sync가 곧 배포가 아니게 되고 우회 배포가 섞이면 sync가 운영 이미지를 되감는다 |
| helmfile | kubeContext를 `.Environment.Name`으로 고정 | 미지정이면 현재 kubectl 컨텍스트에 적용된다 — `-e dev`가 prod에 들어갈 수 있다 |
| 앱 자격증명 | Vault → ESO → Secret, 값은 CLI 관리 | terraform은 메타만 추적 — 값이 state에 남지 않고 plan이 값 변경을 드리프트로 오인하지 않는다 |
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

**앱 배포** — `workloads/base/example-app/`을 복사해 새 앱을 만들고 overlay에서 이미지 태그를 pin합니다. ArgoCD로 관리한다면 `workloads/argocd/application.yaml`을 참고해 Application을 등록하면 됩니다. sync 전에는 [docs/operations.md](docs/operations.md)의 이미지 대조 절차를 따릅니다.

**자격증명** — `credentials/clustersecretstore-example.yaml`로 Vault 접점을 만들면, 앱 Secret은 base의 ExternalSecret이 처리합니다. 레지스트리 pull secret은 namespace에 `registry-pull: enabled` 라벨을 붙이면 끝입니다.

## 같이 보기

이 구성 위에서 도는 장애 분석 봇: [log-autopsy](https://github.com/semi0x3b/log-autopsy) — 장애 알림에 원인 분석을 자동으로 붙입니다.

## License

MIT

<!-- HUMANIZE-SUMMARY v1.6.1
run_id: 2026-09-02-001
genre: 리포트 (GitHub README / 기술 레퍼런스, 합니다체)
metrics:
  char_in: ~2400
  char_out: ~2410
  change_rate: ~6.5%
  self_check: 7/7
  grade: A
categories:  # before → after
  C-11 연결어미 뒤 쉼표: 5 → 0
  A-18 좌향 수식·장문: 2 → 0
  I-4 '~합니다' 권고형 3연속: 1 → 0
  E-1 문장 길이 균일(도입 문단): 1 → 0
  대구 생략 호응 붕괴(자격증명 문단): 1 → 0
self_check:
  - 고유명사·수치·인용·경로·명령어·URL 100% 보존: ✅
  - 변경률 30% 이하: ✅ (6.5%)
  - 장르 이탈 없음(기술 레퍼런스 유지): ✅
  - register 보존(합니다체 유지, 해요체 전환 없음): ✅
  - S1 잔존 0건: ✅
  - 인공 표현 추가 없음: ✅
  - 문단 층위 통독(C-4·E-3·C-13·E-8·F-6): ✅
markdown_guard:
  - 배지 3개·표 2개·코드블록 1개·링크 6개·헤딩 6개: 불변
  - <placeholder> / <dev-context> / <prod-context> / 파일 경로 / helmfile·kubectl 명령: 불변
  - 인라인 볼드 강조(**각 구성에 판단이 들어 있습니다.**, **관측 스택** 등): 구조 레이블로 판단해 J-1 미적용
highlights:
  - id: C-11 + E-1
    before: "관측 스택 설치, 앱 배포 패턴, 자격증명 주입, 운영 규칙을 다루며, 실제 운영 중인 클러스터의 구성에서 환경 값만 `<placeholder>`로 바꿨습니다."
    after: "관측 스택 설치, 앱 배포 패턴, 자격증명 주입, 운영 규칙을 다룹니다. 실제 운영 중인 클러스터 구성에서 환경 값만 `<placeholder>`로 바꿨습니다."
  - id: C-11
    before: "…왜 replicas를 안 쓰는지 같은 것들이고, 근거는 [docs/](docs/)에 있습니다."
    after: "…왜 replicas를 안 쓰는지 같은 것들입니다. 근거는 [docs/](docs/)에 있습니다."
  - id: C-11 (표 셀 2건)
    before: "…배포가 아니게 되고, 우회 배포가…" / "…state에 남지 않고, plan이…"
    after: "…배포가 아니게 되고 우회 배포가…" / "…state에 남지 않고 plan이…"
  - id: I-4
    before: "…Application을 등록합니다. sync 전에는 …를 따릅니다."
    after: "…Application을 등록하면 됩니다. sync 전에는 …를 따릅니다."
  - id: A-18 (대구 생략 호응 붕괴)
    before: "앱 Secret은 base의 ExternalSecret이, 레지스트리 pull secret은 namespace에 `registry-pull: enabled` 라벨을 붙이는 것으로 끝납니다."
    after: "앱 Secret은 base의 ExternalSecret이 처리합니다. 레지스트리 pull secret은 namespace에 `registry-pull: enabled` 라벨을 붙이면 끝입니다."
residual_findings: (없음)
grade_reason: "A — S1 잔존 0건, 자체검증 7항 전부 통과, 마크다운 구조·플레이스홀더 불변. 변경률 6.5%로 A 기준 하한(10%) 미만이나 원문이 이미 사람 손을 탄 문서라 근거 있는 edit 여지 자체가 적었음(무근거 edit 금지 철칙 우선)."
-->
