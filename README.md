# k8s-baseline

![License](https://img.shields.io/badge/license-MIT-blue) ![Helmfile](https://img.shields.io/badge/helmfile-v1-blue) ![Kustomize](https://img.shields.io/badge/kustomize-ArgoCD-blue)

운영하면서 다듬어진 쿠버네티스 구성 레퍼런스입니다. 관측 스택 설치부터 앱 배포 패턴,
자격증명 주입, 운영 규칙까지 — 실클러스터에서 검증된 구성을 일반화해 담았습니다.
값은 전부 `<placeholder>` 라 자기 환경 값으로 바꿔 씁니다.

장애 알림에 원인 분석을 붙이는 봇은 별도 저장소입니다: [log-autopsy](https://github.com/semi0x3b/log-autopsy)

## 구성

```
monitoring/          관측 스택 helmfile — kube-prometheus-stack + Loki + Alloy
  helmfile.yaml.gotmpl   환경별 kubeContext 고정, dev/prod 환경 분리
  values/                Alertmanager 라우팅·Grafana ingress·Loki 보관 정책 포함
workloads/           앱 배포 패턴 — kustomize base/overlay + ArgoCD Application
  base/example-app/      probe 표준·HPA·ESO Secret 주입이 반영된 예시 앱
credentials/         Vault + External Secrets Operator 패턴
  clustersecretstore-example.yaml       클러스터 공용 Vault 접점
  pull-secret-clusterexternalsecret.yaml  ns 라벨만으로 pull secret 자동 배포
  vault-secret-terraform-example.tf     값은 CLI, 메타만 terraform 추적
docs/
  probe-standard.md      tcpSocket 이 행(hang)을 못 잡는 이유와 httpGet 기준
  operations.md          sync 전 이미지 대조, HPA↔replicas 충돌, 배포 완료 판정
```

## 이 구성이 전제하는 판단

| 주제 | 판단 | 근거 |
|------|------|------|
| liveness probe | httpGet, timeoutSeconds 명시 | tcpSocket 은 포트 응답을 커널이 대신해 앱이 멈춰도 통과한다. 기본 timeout 1초는 부하 시 오탐 재시작 |
| HPA 워크로드 | base 에 `spec.replicas` 없음 | 있으면 sync 마다 강제 축소돼 HPA 와 영구 충돌 |
| 이미지 태그 | overlay 에 pin, sync 전 live 대조 | 우회 배포가 섞이면 sync 가 운영 이미지를 되감는다 |
| helmfile | 환경별 kubeContext 고정 | 미지정이면 현재 kubectl 컨텍스트에 적용된다 |
| 앱 자격증명 | Vault → ESO → Secret, 값은 CLI 관리 | terraform 은 메타만 추적 — 값이 state 에 남지 않는다 |
| CPU limit | 두지 않음 (memory limit 만) | CFS throttling 회피 |

각 판단의 상세한 이유는 [docs/](docs/)에 있습니다.

## 시작

```bash
# 관측 스택 (kubeContext·grafana host 등 env 파일 교체 후)
cd monitoring && helmfile -e dev apply

# 예시 앱 렌더 확인
kubectl kustomize workloads/overlays/dev
```

External Secrets Operator 와 cert-manager 는 사전 설치가 필요합니다.

## License

MIT
