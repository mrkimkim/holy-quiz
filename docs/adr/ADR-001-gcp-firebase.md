# ADR-001 — 백엔드 아키텍처: GCP + Firebase (서버리스)

| 상태 | 채택 (2026-07-12) |
|---|---|
| 맥락 | v1.0 MVP · 1인/소규모 개발 · 사업/조직 오버헤드 보류(백엔드 채용 D1 보류) |
| 대체 | `14-server.md`의 1순위 권고(Kotlin+Spring 모놀리스 + 자체 Postgres/Redis) |

## 결정

v1 백엔드를 **GCP + Firebase 서버리스**로 구성한다. 관리형 서비스로 인프라·운영 부담을 최소화하고, 개발 리소스를 코어 게임 로직과 앱에 집중한다.

| 영역 | 채택 | 비고 |
|---|---|---|
| 인증 | **Firebase Auth** (Apple 네이티브) + **카카오→커스텀 토큰** | 카카오 SDK 로그인 후 Cloud Function이 Firebase custom token 발급 |
| 권위 로직 | **Cloud Functions (2nd gen, TypeScript)** | 채점·포인트원장·초대귀속·리더보드 갱신 등 **모든 점수 관련 쓰기는 함수 경유** |
| 주 DB | **Firestore** (Native) | users·churches·questions·attempts·ledger·invites·reports. 트랜잭션으로 원장 정합성 |
| 리더보드 | **스케줄드 집계 스냅샷** (Cloud Scheduler + Functions) | 주간 리셋 구조라 실시간 랭킹 불필요. 순위/백분위는 스냅샷 기반 근사 |
| 캐시/랭킹(확장) | (선택) **Memorystore Redis ZSET** | 규모·실시간 정확 랭킹 필요 시 함수에서 호출 |
| 푸시 | **FCM** | 교회 순위변동·출석·주간마감 |
| 피처플래그/파라미터 | **Remote Config** | 상위 N(A4)·리셋요일(A3)·1.5초 임계·광고 주기 — 하드코딩 금지 결정과 정합 |
| 분석 | **Firebase Analytics + BigQuery export** | 이벤트 택소노미의 데이터 웨어하우스 |
| 크래시 | **Crashlytics** | |
| 스토리지 | **Cloud Storage** | 공유 카드 이미지·티어 아트 |
| 무결성/어뷰징 | **App Check** | 서버 권위 보강(비정상 클라이언트 차단) |
| 호스팅 | **Firebase Hosting** | 랜딩·초대 링크·(선택) 정적 자산 |
| 결제 검증 | **Functions + 스토어 RTDN(Pub/Sub)** 또는 RevenueCat | 구독 영수증 서버 검증 |
| F9 LLM 검증 | **Vertex AI(Gemini)** 또는 외부 LLM API를 Functions에서 호출 | 근거구절 주소↔사실 대조 |

## 지켜야 할 규율 (안 지키면 이 선택이 위험해짐)

1. **클라이언트는 점수·원장·리더보드 컬렉션에 직접 쓰지 않는다.** Firestore 보안 규칙으로 차단하고, 오직 Cloud Functions(호출형)만 쓴다 → 서버 권위 확보(교회 대항전 조작 방어).
2. **리더보드는 집계·스냅샷 모델.** 실시간 정확 순위를 Firestore에 기대하지 않는다. 주간 배치로 `church_weekly_scores`·개인 스냅샷을 만들고, 개인 순위는 버킷/근사로 노출.
3. **Cold start 관리.** 채점 등 지연 민감 함수는 2nd gen `minInstances`로 프리워밍.
4. **결제/민감정보는 서버에서만.** 영수증 검증·구독 상태·민감정보(종교) 처리는 함수 경유(보류한 법무 항목 복귀 시 여기에 얹음).

## 서버 설계 문서와의 관계

`14-server.md`의 **데이터 모델·리더보드 산식(상위20 합산·규모리그·주간리셋)·포인트 원장·안티치트 원칙·NFR**은 그대로 유효하다. 이 ADR은 그 구현 매핑만 바꾼다: `Postgres→Firestore`, `Spring 서비스→Cloud Functions`, `Redis ZSET→(주간 집계 스냅샷, 필요 시 Memorystore)`, `Cloud Tasks/PubSub→그대로`.

## 트레이드오프

- ➕ 인프라 0에 가까움, 인증/푸시/분석/크래시/플래그 내장, 스케일 자동, 1인 운영 가능.
- ➖ Firestore 쿼리 제약(랭킹·복잡 집계) → 집계 파이프라인으로 우회. 벤더 종속. 대량 읽기 비용은 캐시/스냅샷으로 관리.
- 언어: Functions = **TypeScript**(개발자 역량 적합). → 별도 "서버 언어" 결정 불필요(종결).
