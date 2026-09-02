# 운영 규칙

## sync 전에 git 과 live 의 이미지를 대조한다

GitOps 에서 sync 는 "git 에 적힌 상태로 강제 일치"입니다. 긴급 조치로 git 을 우회해
배포된 이미지가 있으면, sync 하는 순간 운영 이미지가 git 에 pin 된 과거 버전으로
되감깁니다. 그래서 sync 전에 각 워크로드의 live 이미지와 git 의 이미지를 대조하고,
어긋난 것은 먼저 git 으로 회수(pin)한 뒤 sync 합니다.

개발 환경도 예외로 두지 않습니다. "개발이니까 생략"이 사고 재현의 지름길입니다.

## HPA 대상 워크로드에 spec.replicas 를 두지 않는다

base 매니페스트에 `replicas` 가 있으면 sync 때마다 그 값으로 강제되어 HPA 와 영구
충돌합니다. HPA 를 붙이는 순간 Deployment 에서 replicas 필드를 제거하세요.

## helmfile 은 kubeContext 를 환경별로 고정한다

kubeContext 미지정 helmfile 은 현재 kubectl 컨텍스트에 적용됩니다. `-e dev` 를 쳤는데
현재 컨텍스트가 prod 면 dev 값이 prod 에 들어갑니다. `.Environment.Name` 분기로 파일에
고정하면 이 사고 유형 자체가 사라집니다 (monitoring/helmfile.yaml.gotmpl 참조).

## 상태를 바꾸기 전에 시뮬레이션한다

mutating 명령(helm/helmfile apply, kubectl apply, terraform apply)은
① 대상 확인(현재 컨텍스트·리소스) → ② diff/plan → ③ 실행 순서로만 합니다.
diff 결과가 의도와 다르면 실행하지 않습니다.

## 배포 완료의 정의

이미지 push ≠ 배포 완료. 롤아웃 상태와 실제 엔드포인트 응답을 확인한 뒤에만 완료입니다.
`kubectl rollout status` 는 새 ReplicaSet 이 준비되기 전에 성공을 반환하는 경우가 있어,
확실히 하려면 새 ReplicaSet 의 readyReplicas 를 직접 확인합니다.

## 주기 실행 자동화의 완성 시점

주기적으로 도는 자동화(알림·크론)는 만든 시점이 아니라 **알림이 실제로 도착하는 걸 본
시점**에 완성됩니다. 일부러 실패를 한 번 내서 경로를 확인하는 것까지가 구축의 일부입니다.
