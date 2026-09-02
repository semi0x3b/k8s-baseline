# 빈 클러스터에서 시작하기

kubeconfig 만 있는 새 클러스터를 이 저장소 구성으로 세우는 순서입니다.
각 단계는 앞 단계를 전제합니다.

## 0. 사전 구성요소

```bash
# cert-manager (ingress TLS)
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager -n cert-manager \
  --create-namespace --set crds.enabled=true

# External Secrets Operator (Vault → K8s Secret)
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# ingress controller — 쓰는 것으로 (예: ingress-nginx / kong). 설치 후
# IngressClass 이름을 monitoring/env/*.yaml 의 ingress_class 에 넣습니다.
```

cert-manager 는 ClusterIssuer(예: letsencrypt)를 하나 만들어야 Grafana ingress 의
TLS 가 발급됩니다. 발급자 구성은 환경(DNS·클라우드)에 따라 달라 여기서는 생략합니다.

## 1. 관측 스택 선행 Secret

helmfile 이 참조하는 Secret 두 개를 먼저 만듭니다.

```bash
kubectl create namespace monitoring

# Grafana 관리자 계정
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin --from-literal=admin-password='<비밀번호>'

# Alertmanager → Slack incoming webhook
kubectl -n monitoring create secret generic alertmanager-slack \
  --from-literal=webhookUrl='https://hooks.slack.com/services/...'
```

## 2. 관측 스택

`monitoring/helmfile.yaml.gotmpl` 의 `<dev-context>`/`<prod-context>` 와
`monitoring/env/*.yaml` 값을 채운 뒤:

```bash
cd monitoring
helmfile -e dev diff     # 반드시 diff 먼저
helmfile -e dev apply
```

확인:

```bash
kubectl -n monitoring get pods            # prometheus·grafana·loki·alloy Running
kubectl -n monitoring get ingress         # grafana 호스트·TLS
```

Alertmanager 경로는 테스트 알림을 직접 주입해 Slack 도착까지 봅니다 —
알림 체계는 만든 시점이 아니라 도착을 확인한 시점에 완성됩니다.

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093 &
curl -s -X POST http://localhost:9093/api/v2/alerts -H 'Content-Type: application/json' -d \
  '[{"labels":{"alertname":"BootstrapTest","severity":"warning"},"endsAt":"'"$(date -u -v+3M +%Y-%m-%dT%H:%M:%SZ)"'"}]'
```

## 3. 자격증명 체계

1. Vault 쪽: 앱별 config secret 을 만듭니다 — terraform 예시는
   `credentials/vault-secret-terraform-example.tf` (값은 CLI 로, 메타만 terraform)
2. 클러스터 쪽: `credentials/clustersecretstore-example.yaml` 의 provider 블록을
   자기 Vault 로 채워 적용
3. pull secret: `credentials/pull-secret-clusterexternalsecret.yaml` 적용 후,
   필요한 namespace 에 `registry-pull: enabled` 라벨

확인: `kubectl get externalsecret -A` 에서 `SecretSynced` 상태.

## 4. 앱 배포

`workloads/base/example-app/` 을 복사해 첫 앱을 만들고 overlay 에 이미지 태그를 pin 합니다.

```bash
kubectl kustomize workloads/overlays/dev   # 렌더 확인
kubectl apply -k workloads/overlays/dev    # 또는 ArgoCD Application 등록
```

ArgoCD 로 넘어갈 때의 저장소 구조는 [gitops-layout.md](gitops-layout.md),
sync 전 확인 절차는 [operations.md](operations.md) 를 따릅니다.

## 5. (선택) 장애 부검 봇

여기까지 서면 [log-autopsy](https://github.com/semi0x3b/log-autopsy) 를 붙일 기반이
완성된 상태입니다 — Alertmanager 라우팅과 Loki 룰은 그쪽 deploy/ 를 참고하세요.
