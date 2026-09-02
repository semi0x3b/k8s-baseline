# probe 표준

## liveness 는 httpGet 으로 한다

tcpSocket probe 는 "포트가 열리는가"만 봅니다. 포트 응답은 커널이 대신 해주기 때문에
애플리케이션 프로세스가 완전히 멈춰도(이벤트 루프 블로킹 등) 검사는 계속 통과합니다.
즉 tcpSocket liveness 는 프로세스 사망은 잡아도 행(hang)은 못 잡습니다 — 행 상태에서는
사람이 개입할 때까지 장애가 지속됩니다.

httpGet 으로 바꾸면 앱이 실제로 요청을 처리하는지를 검사하므로 행도 자동 복구됩니다.
전용 `/health` 엔드포인트가 없으면 `/` 라도 httpGet 이 tcpSocket 보다 낫습니다.
TCP 프록시처럼 HTTP 를 말하지 않는 워크로드만 tcpSocket 이 정답입니다.

## timeoutSeconds 는 명시한다

기본값 1초는 부하 시 오탐 재시작을 만듭니다. 권장 기준:

| probe | timeout | period | failureThreshold | 의미 |
|-------|---------|--------|------------------|------|
| readiness | 3s | 10s | 3 | 느려진 파드를 트래픽에서 빠르게 격리 |
| liveness | 5s | 10s | 3 | 행 감지·재시작까지 최대 ~45초 |

## readiness 없는 배포는 순단을 만든다

readinessProbe 가 없으면 컨테이너가 뜨자마자(앱이 포트를 바인딩하기 전에) Endpoint 에
등록됩니다. HPA 스케일업이나 배포 직후 connection refused 가 간헐적으로 난다면 이것부터
의심하세요. 새 서비스에는 readiness/liveness 를 기본으로 넣습니다.

## 전환 시 검증

- 배포 전: 전 서비스 헬스 경로를 실측(클러스터 안에서 후보 경로 GET)해 경로를 확정
- 배포 후: 재시작 카운트가 0인지 확인 (오탐 재시작이 없다는 증거)
- 행 감지 실증: 앱 프로세스를 직접 정지시켜 readiness 격리 → liveness 재시작을 확인.
  컨테이너 PID 1은 내부에서 보낸 정지 시그널을 무시하므로 실제 앱 프로세스(워커)를 골라야 합니다
