# 13. 클라이언트 개발(Flutter)

> 한 줄 목적: 40~70대가 도움 없이 큰 글씨로 매일 성경 퀴즈를 풀고 "우리 교회"를 위해 명예를 겨루도록, **서버 권위 점수**를 지키면서도 약전파·저사양 환경에서 즉시 반응하는 Flutter 클라이언트를 iOS/Android 단일 코드베이스로 10주 안에 출시 가능하게 만든다.

이 문서는 클라이언트 파트의 **실행 사양**이다. 원론이 아니라 "무엇을 고르고, 어떻게 짜고, 어디까지 클라가 책임지는가"를 결정한다. 제품 원칙(매일의 습관 / 명예로 경쟁 / 교회가 팀 / 중장년이 기본값)과 갭 분석의 클라이언트 항목(안티치트 클라 책임, ATT·국외이전·탈퇴·연령게이트 동의 UI, 오프라인/저사양, 계정복구, 접근성 심화, 오탐 소명, 타임존)을 문서 내에서 실질 해소한다.

---

## 13.1 기술 스택 결정 (한눈표)

| 영역 | 결정 | 대안 | 결정 근거 |
|---|---|---|---|
| 상태관리 | **Riverpod 2.x** (`flutter_riverpod` + `riverpod_generator`) | Bloc, Provider | 컴파일타임 안전, provider 단위 테스트 용이, 코드젠으로 보일러플레이트 최소, `select`로 리빌드 최소화(저사양 유리) |
| 모델/불변성 | **freezed + json_serializable** | 수기 모델 | 채점 결과·세션 상태를 union으로 안전 표현, `copyWith`·직렬화 자동 |
| 네트워크 | **dio + retrofit** | http | 인터셉터로 토큰 갱신·serve_token 반환·재시도·ETag를 한 곳에서 처리 |
| 로컬 DB | **Drift(SQLite)** | Isar, Hive | 마이그레이션 신뢰성, 오답노트·출석·outbox의 관계형/트랜잭션 요구, SQL 디버깅 용이 |
| 보안 저장 | **flutter_secure_storage** | - | 토큰을 Keychain/Keystore에 저장(평문 금지) |
| 단순 플래그 | **shared_preferences** | - | 온보딩 완료·큰글씨 설정 등 비민감 플래그 |
| 라우팅 | **go_router** | auto_route | 딥링크·redirect 가드·ShellRoute(하단탭) 1급 지원 |
| 광고 | **google_mobile_ads** | - | 공식 AdMob, 미디에이션 지원 |
| 동의(광고) | **Google UMP SDK** + iOS **ATT** | - | 개인화 광고 동의·국외이전 고지 요구 |
| 인증 | **kakao_flutter_sdk_user**, **sign_in_with_apple** | - | PRD 지정(카카오 단일 + Apple 심사요건) |
| 결제 | **in_app_purchase** + 서버 영수증 검증 | RevenueCat | 상품 2종(월/연)뿐이라 자체+서버검증이 저비용, 가짜 영수증 차단 |
| 푸시 | **firebase_messaging** + `flutter_local_notifications` | - | 표준, 포그라운드 표시·예약 |
| 딥링크/어트리뷰션 | **app_links** + **MMP(딥링크 SDK)** | AppsFlyer OneLink / Airbridge / Adjust | FDL 종료 대응, 설치(deferred) 어트리뷰션 + 초대 자동귀속. **벤더는 공동 확정 대기(하단 주)** |
| 크래시 | **Firebase Crashlytics** | Sentry | Firebase 스택 통합, 무료, non-fatal 로깅 |
| 분석 | **Firebase Analytics** (+ MMP) | - | data 파트 `taxonomy.yaml` 연계(church_id 등 민감속성 GA4 미전송, 13.13) |
| 기기 무결성 | **Play Integrity API / App Attest** + **freerasp** | - | 안티치트(루팅·후킹·에뮬레이터 탐지) |
| 피처플래그 | **Firebase Remote Config** | - | 광고 빈도·상위N·초대 리더보드 명칭·킬스위치·강제업데이트 |
| CI/CD | **GitHub Actions + fastlane** | Codemagic | 레포가 GitHub, 서명·스토어 배포 자동화 |

> **MMP/딥링크 SDK 벤더 확정은 다른 파트와 공동 결정**이다. client(13.7)·marketing은 초대 자동귀속(deferred deep link)이 **v1 필수**임을 전제하지만, 후보가 AppsFlyer(client) vs Airbridge(marketing) vs Adjust로 갈리고 data(17.5.1)는 'MMP 스케일업까지 보류'를 주장해 정면 충돌한다. **data를 조정 오너로 지정**해 W3까지 단일 벤더를 확정하되, 선정 기준으로 **카카오 딥링크 자동귀속·iOS SKAN·KR/원화 지원**을 필수로 못박는다(13.7.1·13.17.2). 이 밖에 **미디에이션 네트워크 구성**, **최소 OS 하한**도 openQuestion. 나머지는 클라이언트 파트가 확정한다.

---

## 13.2 아키텍처 · 레이어링 · 폴더구조

### 13.2.1 레이어링 원칙 (feature-first + 4레이어)

```
presentation → application → domain ← data
```

- **presentation**: 화면·위젯. 상태를 읽고 사용자 입력을 컨트롤러로 전달만. 비즈니스 로직 금지.
- **application**: Riverpod `Notifier`/`AsyncNotifier` 컨트롤러. 화면 상태 조립, use-case 호출, 낙관적 업데이트.
- **domain**: 순수 Dart 엔티티(freezed) + use-case + **표시용 점수 로직**(서버 권위와 별개, 오직 즉시 피드백/미리보기용). Flutter 의존성 없음 → 테스트 100% 커버 가능.
- **data**: repository 구현 + remote(dio/retrofit) + local(Drift) 데이터소스. DTO↔엔티티 매핑.

### 13.2.2 폴더구조 (feature-first)

```
lib/
  main_dev.dart / main_stg.dart / main_prod.dart   # flavor 진입점
  bootstrap.dart                                    # 공통 초기화(runZonedGuarded)
  app/
    app.dart              # MaterialApp.router + textScaler 오버라이드
    router/               # go_router 설정, 라우트, redirect 가드
    theme/                # 타이포·색·큰글씨 스케일·라이트/다크
    di/                   # ProviderScope overrides, 앱 부트 provider
  core/
    network/              # dio, 인터셉터(auth/serve_token/재시도/ETag), 에러 매퍼
    storage/              # drift db, secure_storage, prefs
    error/                # Failure 타입, 사용자 메시지 매핑(중장년 카피)
    analytics/            # 이벤트 택소노미 래퍼(스키마 강제, church_id GA4 차단)
    accessibility/        # 텍스트스케일 컨트롤러, Semantics 헬퍼, 햅틱
    integrity/            # serve_token 반환, Play Integrity/App Attest, root 탐지
    time/                 # 단조시계(Stopwatch), 서버시간 동기화, 타임존
  features/
    onboarding/  auth/    quiz/   tier/   leaderboard/
    church/      invite/  ads/    attendance/  verse_of_day/
    report/      settings/ subscription/ consent/  account/
  l10n/                   # gen-l10n .arb (v1 ko만, 인프라 선구축)
```

각 feature는 내부에 `data / domain / application / presentation`을 둔다. 예: `features/quiz/domain/scoring_preview.dart`(표시용), `features/quiz/application/quiz_session_controller.dart`.

### 13.2.3 모듈화 판단

- **v1은 단일 패키지**로 간다(멜로스/모노레포 오버엔지니어링 금지). 대신 위 레이어 규칙을 lint(`import_lint`/커스텀 analyzer 규칙)로 강제해 `domain`이 Flutter/데이터 레이어를 import 못 하게 막는다.
- v2.0(골든벨 라이브·B2B 대시보드) 시점에 `packages/design_system`, `packages/quiz_engine`로 분리 검토.

---

## 13.3 라우팅 · 화면구조 (깊이 2 초과 금지)

### 13.3.1 라우트/탭 인벤토리

| 경로 | 화면 | 위치 | 깊이 |
|---|---|---|---|
| `/onboarding/textsize` | 큰 글씨 선택 | 온보딩 | - |
| `/onboarding/login` | 카카오/Apple 로그인 | 온보딩 | - |
| `/onboarding/consent` | 필수 동의(국외이전·연령) — **종교/교회 동의는 게이트 아님, 13.10** | 온보딩 | - |
| `/onboarding/diagnostic` | 난이도 진단 10문제(광고 없음) | 온보딩 | - |
| `/onboarding/tier-intro` | 첫 티어 부여 연출 | 온보딩 | - |
| `/onboarding/church` | 교회 등록 유도(스킵 가능, 종교 동의는 여기서 선택 수집) | 온보딩 | - |
| `/home` | 오늘의 말씀·출석·시작하기·교회 배너 | **탭1** | 1 |
| `/rank` | 개인(전국/시도/우리교회) + 교회 대항 | **탭2** | 1 |
| `/me` | 티어·오답노트·초대·설정·구독 | **탭3** | 1 |
| `/quiz` | 퀴즈 세션(풀스크린, 탭바 숨김) | 푸시 | 2 |
| `/quiz/result` | 20문제 결과 요약(→전면광고) | 푸시 | 2 |
| `/church/:id` | 교회 상세(추이·기여자·응원) | 푸시 | 2 |
| `/invite` | 초대 코드·현황 | 푸시 | 2 |
| `/report/:questionId` | 오류 신고(원탭 사유) | 모달 | 2 |
| `/settings/*` | 설정 하위(알림·글씨·계정·탈퇴) | 예외 | 2~3 |

- **하단탭 3개**(홈·순위·내정보)는 `StatefulShellRoute.indexedStack`으로 각 탭 상태 보존.
- 퀴즈는 몰입을 위해 탭바를 숨긴 풀스크린(`/quiz`)으로 push. 종료 시 홈으로 pop.
- **깊이 규칙**: 탭(1) → 상세(2)까지만. 설정 하위 페이지만 예외로 허용(중장년이 자주 안 가는 영역). 이 규칙을 라우터 리뷰 체크리스트로 강제.

### 13.3.2 redirect 가드 (선언형)

```
로그인 안 됨            → /onboarding/login
필수 동의 미완료        → /onboarding/consent   (국외이전·연령만. 종교 동의는 게이트에서 제외)
난이도 진단 미완료      → /onboarding/diagnostic
강제 업데이트 필요      → /force-update  (Remote Config min_supported_version)
그 외                   → 요청 경로
```

딥링크/푸시로 진입해도 위 가드가 온보딩 미완료 사용자를 안전하게 유도하고, 완료 후 원래 목적지(`/church/:id`, `/invite`)로 이어준다(`go_router`의 `redirect` + 목적지 보존). **종교(민감정보)·교회소속 동의는 진입 필수 게이트로 두지 않는다**(무동의로 개인 퀴즈 이용 가능, 13.10).

---

## 13.4 퀴즈 엔진 클라이언트 로직 (핵심)

### 13.4.1 채점 권위 결정 — 서버 권위, 클라는 표시, 정답키 미전송 (갭: 보안/안티치트)

**결정: 포인트·콤보·티어의 최종 계산은 100% 서버가 한다. 클라이언트는 절대 포인트를 확정하지 않는다.** 교회 대항전은 "우리 교회를 위해" 조작할 사회적 유인이 강하므로, 클라 계산 점수를 신뢰하면 유일 차별점인 명예 리더보드가 붕괴한다.

즉시 피드백(중장년 UX)과 오프라인(P2 지하철) 요구를 서버 권위·안티치트 불변식(**정답키 사전 미전송**)과 양립시키기 위해, **정답키는 어떤 경우에도 기기로 내려보내지 않는** 단일 모델을 쓴다(server 14.7.1·ux 12.7과 정합).

| 상황 | 기본값 | 정답키 위치 | 채점 / 정오 표시 | 포인트 확정 |
|---|---|---|---|---|
| **온라인 왕복** | ✅ 기본 | 서버만 보유 | `POST /quiz/answer` 왕복(p95 300ms 목표), **정오는 서버 응답 후 표시** | 서버 응답값 즉시 반영 |
| **오프라인·약전파** | 자동 폴백 | 서버만(기기 미보유) | attempt를 로컬 **outbox 큐잉**, 오프라인 중 **정오·포인트 미표시**("제출됨/동기화 대기"만) | 재연결 시 서버 채점 후 확정 |

- 온라인은 정답키를 클라에 내려보내지 않으므로 위조 클라이언트로도 정답을 미리 알 수 없다. 탭 즉시 **중립 프레스 상태**만 주고, 마이크로 스피너(≤300ms)로 "채점 중"을 흡수한 뒤 **서버 응답이 온 다음** 정오 색·햅틱·근거구절을 표시한다(design/ux 정오 피드백 사양과 공동 정정: 탭 즉시 정오 표시 아님).
- 오프라인은 정답키 없는 문제를 프리페치하고 사용자의 답안(attempt)만 로컬 outbox에 큐잉한다. 재연결 시 outbox를 flush하면 서버가 타이밍·중복·매크로·재출제 할인을 검증해 **권위 포인트 델타**를 돌려준다. 약전파에서는 정오 표시가 지연되고 오프라인 구간에서는 정오가 표시되지 않는 UX 저하를 **명시 수용**한다(안티치트 우선, ux 12.7·server 14.9.1과 동일 모델).
- **낙관적 UI는 리더보드·포인트 표시 갱신에만 한정**하고, 퀴즈 정오(정답/오답)에는 적용하지 않는다(정오는 항상 서버 응답 후).

> 결과: 서버 권위·안티치트(정답키 미전송)를 지키면서 온라인 즉시성과 오프라인 제출 큐를 모두 지원한다. 로컬 정답키를 기기로 내려받아 즉시 채점하는 '오프라인팩'은 서버 불변식(14.7.1)과 정면 충돌하므로 **채택하지 않는다**. 오프라인 즉시 정오 피드백이 향후 필수가 되면, 서버가 provisional 정답키 다운로드를 허용하는 별도 계약·상한·재검증·회수 규칙을 server 스펙에 명문화한 뒤에만 도입한다(현재 v1 스코프 밖).

### 13.4.2 문제 로딩 · 프리페치 · serve_token 캡처

- 세션 시작 시 `GET /quiz/next?category=&buffer=8`로 **정답키 없는** 문제 8개 버퍼를 채우고, 잔여가 3개 이하로 떨어지면 백그라운드로 다음 배치 프리페치(끊김 없는 무제한 풀이).
- **각 문항에 딸린 `serve_token`(서버 발급 HMAC)을 함께 저장**하고, 해당 문항 제출 시 그대로 반환한다(안티치트 문항 바인딩, 13.5.3).
- 문제 본문·선택지·근거구절 메타(카테고리/난이도/재출제 플래그)는 ETag 캐시. 이미지가 있는 문제(인물/지명)는 `cached_network_image`로 프리캐시.
- 오답노트·과거 이력은 로컬(Drift) 우선 표시 후 서버와 대사.

### 13.4.3 채점 표시 · 콤보 · 타이머

- **콤보**: 연속 정답 5→+10%, 10→+25%. 클라는 즉시 배율을 **표시용**으로 계산해 애니메이션(예: "5연속! 보너스")하지만, 확정 포인트는 서버 응답의 `comboMultiplier`로 덮어쓴다.
- **정오 표시 타이밍**: 정답/오답 색·햅틱·근거구절은 **서버 응답 수신 이후**에만 노출한다(13.4.1). 즉시 응답 방식(별도 확인 스텝 없음)이므로 latency는 **문제 표시→탭까지**를 단조시계로 측정해 안티치트 1.5초 룰의 기준으로 삼는다.
- **타이머**: `Stopwatch`(단조시계, 벽시계·서버시간 아님)로 문제 표시→응답까지 `elapsedMs`를 측정해 이벤트에 첨부. 서버도 serve→submit 델타를 독립 측정(이중 검증). 벽시계를 쓰면 기기 시계 조작에 취약하므로 금지.
- **재출제 표시(파밍 방지 가시화)**: 서버가 `isReserve=true`로 내려준 복습 문제는 화면에 조용한 "복습" 뱃지 + "복습 문제는 포인트 20%"를 안내해, 사용자가 파밍이 무의미함을 인지하게 한다(신뢰·기대관리).

### 13.4.4 비정상 속도 감지 UX (갭: 오탐 소명)

PRD 규칙(문제당 1.5초 미만 연타 반복 → 세션 포인트 무효)은 지식이 뛰어난 권사님의 정당한 빠른 응답을 오탐할 수 있다. 클라이언트 처리 원칙:

1. **클라는 무효화하지 않는다.** `elapsedMs`만 전송하고 무효 판정은 서버가 한다(클라 조작 방지).
2. 세션 중 과속 패턴이 감지되면(로컬 힌트) **비처벌적 넛지**만: "천천히 풀어도 괜찮아요 🙂"(작은 토스트, 진행 차단 없음).
3. 서버가 세션을 무효 처리하면 결과 화면에 명확한 안내 + **"이의 신청" 버튼** → ops 검토 큐로 전송(`POST /reports`와 유사한 소명 엔드포인트). 임계값(1500ms)은 Remote Config로 조정 가능하게 해 오탐률을 실측 튜닝한다.
4. 정직한 사용자의 포인트가 소리 없이 사라지는 경험은 이탈로 직결되므로, "왜 무효인지 + 어떻게 소명하는지"를 항상 노출한다.

### 13.4.5 광고 삽입 지점

- 20문제 결과 요약 화면(`/quiz/result`) **직후** 전면광고 1회(문제 도중 절대 금지). 광고 카운터는 클라가 문제 수로 관리하되 빈도(기본 20)는 Remote Config로 서버 원격 조정.
- 광고 로드 실패 시 **진행을 절대 막지 않는다**(13.9.4). 다음 20문제로 즉시 이어간다.

---

## 13.5 클라-서버 API 계약 · 안티치트 클라 책임

### 13.5.1 주요 엔드포인트 (클라 관점)

> 아래는 클라이언트가 요구하는 **계약 초안**이며, 최종 경로·명칭(예: `quiz/answer` vs `quiz/attempts`, `invite/attribute` vs `invites/accept`·`invites/me`)과 **`push/token`·batch 엔드포인트 존재 여부**는 착수 전 **OpenAPI를 단일 소스로 server와 공동 확정**한다(14.5와 정합화).

| 메서드 · 경로 | 용도 | 특이사항 |
|---|---|---|
| `POST /auth/kakao`·`/auth/apple` | 소셜 토큰 → 앱 JWT 교환 | body에 기기 무결성 토큰 포함, `isNew` 반환 |
| `POST /auth/refresh` | JWT 갱신 | 단일 비행(single-flight) 갱신 |
| `DELETE /me` | 회원 탈퇴 | 포인트/기여/초대귀속 처리 규칙은 서버 소관, 클라는 안내+호출 |
| `GET /quiz/next` | 다음 문제 배치(정답키 없음) | ETag 캐시, buffer 파라미터, **문항별 `serve_token` 반환** |
| `POST /quiz/answer` | 온라인 채점(권위) | `Idempotency-Key`, **문항 `serve_token` 반환**. 응답: `{correct, correctIndex, earnedPoints, comboCount, comboMultiplier, verse, isReserve}` |
| `POST /quiz/answers/batch` | **오프라인 outbox flush(정답키 없음, 서버가 각 attempt 채점)** | 이벤트별 권위 결과 + `voided` 플래그. **server 계약에 신설 필요(OpenAPI 공동 확정)** |
| `GET /leaderboard/personal` | 개인 랭킹 | scope=nation\|region\|church, period=weekly\|cumulative, cursor |
| `GET /leaderboard/church` | 교회 대항 | league=개척\|중형\|대형, cursor |
| `GET /church/search`·`POST /church/register`·`POST /me/church` | 교회 검색/등록/변경(월1회) | 변경 쿨다운은 서버 판정 |
| `POST /invite/attribute`·`GET /invite/status` | 초대 귀속/현황 | 유효초대 3조건은 서버 판정. server 명칭(`invites/accept`·`invites/me`)과 OpenAPI 정합 |
| `POST /attendance/checkin` | 출석 체크 | **서버시간 권위**(기기 시계 조작 무력화), streak 반환 |
| `GET /verse/today` | 오늘의 말씀 | ETag, 하루 캐시 |
| `POST /reports` | 오류 신고/소명 | 원탭 사유 코드 |
| `POST /subscription/verify` | 구독 영수증 서버검증 | 가짜 영수증 차단 |
| `POST /push/token` | FCM 토큰 등록/갱신 | 기기별. server 계약에 존재 확인 필요 |

> `GET /quiz/offline-pack`(암호화 정답키 다운로드)은 13.4.1 결정에 따라 **제거**했다.

### 13.5.2 횡단 규약 (dio 인터셉터에서 일괄 처리)

- `Authorization: Bearer <appJwt>` / 401 시 자동 갱신 후 1회 재시도.
- `Idempotency-Key`(UUID): 답안·출석·초대 귀속 등 중복 방지(약전파 재전송 대비).
- **`serve_token` 반환**: `/quiz/next`의 문항별 `serve_token`(서버 발급 HMAC)을 해당 attempt 제출 시 그대로 되돌려준다 — 서버가 문항 바인딩·재전송/위조를 검증(13.5.3). **세션키 기반 전면 요청서명(X-Signature)은 채택하지 않는다**(서버 serve_token 바인딩으로 충분, 과설계 제거).
- `X-Client-Version`, `X-Platform`: 강제 업데이트·분기 처리.
- `If-None-Match`(ETag): 문제·오늘의말씀·리더보드 캐시로 트래픽·배터리 절감.
- **표준 에러 모델** `{code, message, retryable}` → `core/error`에서 중장년용 큰 글씨·짧은 한국어 메시지로 매핑(예: "인터넷 연결을 확인해 주세요"). 스택/영문 노출 금지.

### 13.5.3 안티치트 — 클라이언트 책임 (갭 해소, 서버가 최종 권위)

| 방어 | 클라 구현 | 비고 |
|---|---|---|
| 문항 바인딩(요청 서명 대체) | `/quiz/next`에서 받은 **문항별 serve_token**을 저장 → 해당 attempt 제출 시 nonce와 함께 반환 | 서버가 serve→submit 바인딩·nonce 캐시로 재전송 차단. 세션키 전면 서명은 제거(server 권고: MVP 과설계) |
| 기기 무결성 | **Play Integrity API**(Android) / **App Attest·DeviceCheck**(iOS) 토큰을 세션 시작 시 첨부 | 서버가 Google/Apple로 검증. 위조 클라 판별 |
| 루팅/후킹 탐지 | **freerasp**로 root·jailbreak·debugger·emulator·hooking 탐지 → 서버에 **소프트 시그널** 전송 | 하드블록은 중장년 오탐 우려로 지양, 서버가 점수 가중치 하향(권고) |
| 시간 조작 방지 | 답안 타이밍은 단조시계, 출석은 서버시간 | 벽시계 미신뢰 |
| 점수 무권위 | 클라는 표시용만 계산, 확정은 서버, 정답키 미보유 | 13.4.1 |

> 이 방어들로 "클라이언트 계산 점수 위조"와 "정답 사전 파밍"을 봉쇄한다. 다만 앱 시크릿 보관의 근본 한계상 **최종 판정은 서버 이상탐지**가 맡고, 클라는 위조 비용을 크게 올리는 역할이다. qa 인터셉트 테스트(20.6.1)는 serve_token 바인딩 모델을 기준으로 작성한다.

---

## 13.6 인증 · 토큰 · 계정 복구

### 13.6.1 토큰 플로우

1. `kakao_flutter_sdk_user`로 로그인 → `kakaoAccessToken` 획득.
2. `POST /auth/kakao {kakaoAccessToken, integrityToken}` → 서버가 카카오로 검증 → `{appAccessJwt(만료 15분), appRefreshToken(장기), userId, isNew}` 반환.
3. JWT는 **flutter_secure_storage**(Keychain/Keystore)에 저장. 절대 SharedPreferences/평문 금지.
4. dio 인터셉터가 자동 첨부, 401 시 refresh 토큰으로 **단일 비행 갱신**(동시 요청이 갱신 1회만 트리거) 후 재시도.
5. Apple: `sign_in_with_apple` → `identityToken` → `POST /auth/apple`(iOS 심사요건 충족).

> 클라는 카카오 토큰의 진위를 신뢰하지 않는다. 반드시 서버가 카카오 API로 재검증한 뒤 앱 JWT를 발급한다(신원 위조 방지).

### 13.6.2 계정 이전 · 기기변경 · 복구 (갭 해소)

중장년은 계정 복구 난이도가 높다. 카카오 단일 로그인의 장점(같은 카카오 = 같은 계정)을 활용한다.

- **기기 변경/재설치**: 동일 카카오로 로그인 → 서버가 기존 userId 반환(`isNew=false`) → 포인트·티어·연속출석 전량 복원. 별도 절차 없음(무마찰).
- **카카오 계정 변경/분실**: 내정보 → "로그인 문제 도움" 진입점(전화/카톡 채널 CS 연동, ops 파트). 서버 본인확인 후 병합.
- **연속출석 연속성**: 출석 판정이 서버시간·서버 저장이므로 기기 변경에도 streak 유지.
- 로그아웃 시 secure_storage 토큰·민감 로컬 캐시(미제출 outbox 포함) 즉시 정리.

---

## 13.7 딥링크 · 설치 어트리뷰션 (초대 자동귀속)

### 13.7.1 기술 선택 — FDL 종료 대응, MMP 공동 확정

Firebase Dynamic Links는 종료되어 **사용 금지**. 초대 자동귀속(코드 입력 없이 설치→귀속)은 **deferred deep link**가 필요하며, **이는 F8 성장엔진의 v1 필수 기능**이다. 따라서 v1 착수 전 **MMP/딥링크 SDK를 단일 벤더로 확정**해야 한다.

- **후보**: AppsFlyer OneLink(client 선호) / Airbridge(marketing 1순위) / Adjust. **선정 필수 기준**: 카카오 딥링크 자동귀속, iOS SKAN 전환값, KR/원화 지원, 비용.
- **조정 오너 = data.** data(17.5.1)의 'UA 월 ₩10M+까지 MMP 보류' 방침은 **F8 자동귀속(v1)과 충돌**하므로, 자동귀속에 한해 철회하거나 — 대안으로 — **v1은 6자리 코드 수동귀속만 제공하고 자동귀속을 v1.1로 내리는 스코프 조정**을 명시적으로 택한다(둘 중 하나를 W3까지 확정).
- 확정된 스택 위에서 client 딥링크·data SKAN 전환값 스키마·marketing 카카오 귀속·org SaaS 예산을 동시 정렬한다.

### 13.7.2 초대 자동귀속 플로우 (자동귀속 채택 시)

```
초대자: /invite → MMP OneLink형 URL 생성(초대코드 포함) → 카톡 공유 1탭
피초대자(미설치): 링크 탭 → 스토어 → 설치 → 첫 실행
  → MMP conversion 콜백으로 초대코드 회수(deferred)
  → POST /invite/attribute {inviteCode, install_id}
  → 서버가 유효초대 3조건(가입+교회등록+20문제) 판정
피초대자(설치됨): app_links 가 URI 수신 → go_router 로 /church/:id 또는 /invite 라우팅
폴백: 딥링크 유실 시 가입화면 "초대 코드가 있나요?" 6자리 수동 입력
```

- 모든 공유는 **1탭**(승급 카드·순위 변동·주간 결산 → Kakao Link with 딥링크). 중장년 공유 마찰 최소화가 성장 핵심.
- 동일 기기 반복 가입 차단·일일 상한은 서버 판정, 클라는 install_id/기기 시그널만 제공.

---

## 13.8 푸시 (FCM · 권한 · 야간 동의 · 라우팅)

- `firebase_messaging`로 토큰 획득 → `POST /push/token`(기기별). 포그라운드는 `flutter_local_notifications`로 표시.
- **권한 요청 타이밍**: 첫 실행 즉시 금지. **첫 티어 부여 직후**(가치 전달 후) 맥락 카피와 함께 요청. Android 13+는 `POST_NOTIFICATIONS` 런타임 권한.
- **야간(21:00~08:00) 발송 동의 (갭: 정보통신망법)**: 광고성 야간 푸시는 별도 수신 동의 필요. 설정에 "야간(21시~8시) 알림 받기" **별도 opt-in** + 법정 고지 문구(legal 제공). 새벽기도 리마인더는 사용자가 시간을 직접 설정하는 **정보성 알림**으로 분류하되, 이 분류의 적법성은 legal 확정 대기(openQuestion). 발송 시간·빈도(일 1회 상한)는 서버 정책, 클라는 동의·선호시간만 캡처.
- **딥링크 라우팅**: 페이로드 `{type, targetId}` → 탭 시 cold/warm/background 3상태 모두에서 go_router로 목적지(`/church/:id`, `/quiz`, `/rank`) 이동. 온보딩 미완료면 13.3.2 가드가 목적지 보존.

---

## 13.9 광고 (AdMob · 프리로드 · 동의 · 폴백)

### 13.9.1 광고 유형·배치 (중장년 오터치 방지)

| 유형 | 배치 | 규칙 |
|---|---|---|
| 전면(Interstitial) | 20문제 결과 화면 직후 | 프리로드 필수, 실패 시 스킵 |
| 보상형(Rewarded) | "광고 보고 다음 20문제 2배"(v1.1, 배선은 v1에) | **선택형. 명예 공정성 가드레일 확정 전 배포 금지(아래)** |
| 배너(Adaptive Banner) | **리더보드·통계 화면 하단만** | 퀴즈 화면 절대 금지(오터치) |

> **보상형 2배 포인트 · 명예 공정성 (갭: 수익화 15.2.6 정합).** '다음 20문제 2배'가 명예 포인트를 광고 시청량으로 부풀리면 **교회 대항 주간합산(상위20)을 오염**시켜 명예 불가침 원칙과 충돌한다. 따라서 "명예 전용이라 pay-to-win 아님"으로 단정하지 않는다. **가드레일: 보상형 배율분은 (a)개인 티어에는 반영되되 (b)교회 대항 주간합산에서는 제외**한다(server가 `point_ledger`에 `rewarded_bonus` 엔트리 유형 신설 + `church_weekly_scores` 집계 시 제외하는 데이터모델을 확정). **이 서버 가드레일이 확정되기 전에는 v1.1 보상형 광고를 배포하지 않는다**(킬스위치 `kill_rewarded` 기본 off로 배선만 유지).

### 13.9.2 프리로드 전략

- 세션 시작 시 전면광고를 미리 로드(`InterstitialAd.load`), 20문제 도달 전 준비 완료 상태 유지.
- 노출 후 즉시 다음 광고 재로드. 로드 실패는 지수백오프로 재시도하되 **진행을 막지 않음**.
- 배너는 화면 진입 시 로드, 이탈 시 dispose(메모리·배터리).

### 13.9.3 동의 — UMP + ATT (갭: 국외이전/ATT)

- **Google UMP SDK**로 개인화 광고 동의폼 표시(국외이전 고지 포함, legal 문구).
- **iOS ATT**: `AppTrackingTransparency` 프롬프트를 **첫 티어 이후·첫 광고 이전**에 노출. 거부 시 비개인화 광고(`npa=1`)로 폴백(eCPM 하락 감수, 매출 추정에 반영 필요 → data/monetization).
- 국외 SDK(AdMob·Firebase·MMP) 국외이전 동의는 온보딩 필수 동의 화면(13.10)에 포함.

### 13.9.4 로드 실패 폴백 (갭: 약전파)

- 전면광고 로드/표시 실패 → **다음 20문제로 즉시 진행**(차단 없음). 실패율은 분석 이벤트로 수집.
- 광고 SDK 초기화는 첫 프레임 이후로 지연(콜드스타트 보호, 13.12).
- 미디에이션은 MVP에 AdMob 직접 연동으로 리스크를 낮추고, AppLovin MAX/Meta 등 어댑터는 fast-follow로 추가(monetization 협의).

---

## 13.10 개인정보 · 동의 UI (갭: 민감정보·연령·탈퇴·국외이전)

클라이언트가 화면으로 책임지는 동의·권리 표면. 문구·법적 근거는 legal, 저장·처리 규칙은 server.

| 항목 | 클라 구현 | 근거 |
|---|---|---|
| **민감정보(종교) 동의** | **교회 등록 직전** 별도 체크박스(선택): "종교·교회 소속 정보 수집 및 전국 리더보드 공개에 동의". **온보딩 진입 게이트 아님** | PIPA §23, 명시적 별도 동의·강요/번들 금지 |
| **국외이전 동의** | 온보딩 필수 동의에 AdMob/Firebase/MMP 국외이전 고지·동의 | PIPA 국외이전 |
| **광고식별자·ATT** | iOS ATT 프롬프트 + UMP 동의(13.9.3) | ATT, 개인화 광고 |
| **연령 게이트** | 가입 시 생년/만14세 이상 확인. **만14세 미만 v1 가입 차단**(잠정) + 안내 카피 | 아동 무동의 수집 위법 회피 |
| **미성년 실명 미노출** | 리더보드·프로필은 **닉네임만**(실명 전국 노출 금지, 전 연령 공통) | 미성년 실명 노출 리스크 |
| **회원 탈퇴 플로우** | 내정보 → 탈퇴 → 데이터 처리 안내(포인트·기여·초대귀속 소멸/익명화) → `DELETE /me` | 정보주체 권리, 앱 심사 |
| **권리 행사 메뉴** | 열람·정정·삭제·처리정지 요청 진입점(설정) | PIPA 정보주체 권리 |

> **종교(민감정보)·교회소속 동의는 진입 필수 게이트가 아니라 '교회 기능 이용 시점(교회 등록 직전)의 선택 동의'다.** 미동의 시 교회 기능만 미제공되고 **개인 퀴즈는 무동의로 이용 가능**하다(legal 19.3·data 17.11.1 정합, 교회등록 스킵 가능). 만14세 미만 완전 차단 vs 법정대리인 동의 플로우, 야간 푸시 분류는 legal 확정 대기(openQuestions). 클라는 두 시나리오 모두 수용 가능하게 동의 화면을 데이터 기반(서버가 필요한 동의 목록을 내려주는 구조)으로 설계한다.

---

## 13.11 접근성 구현 (갭 해소, 중장년 기본값)

### 13.11.1 전역 큰 글씨 · 텍스트 스케일 (design 단일 배율 테이블 참조)

- 앱 설정 "글씨 크기": **보통(1.0) / 큼(1.15) / 아주 큼(1.3)**. Riverpod 컨트롤러가 값 보관, `MaterialApp` 상위에서 `MediaQuery`의 `textScaler`를 오버라이드. **이 3단계 값은 design(11.3.3)·ux(12.2.1)와 동일한 단일 수치**를 쓴다.
- OS 동적 폰트도 존중하되 레이아웃 붕괴 방지를 위해 **OS×앱 곱연산 상한(클램프)을 1.3으로** 확정한다(design 단일 토큰 테이블). 이전의 [1.0, 1.6] 클램프·1.4 단계값은 폐기.
- **최소 치수**: 본문 ≥18pt, 선택지 버튼 높이 ≥56dp·글자 ≥20sp, 모든 탭 타깃 ≥48dp. **본문 18pt·선택지 56dp 하한은 전 배율에서 유지**한다. 스케일 상승 시 텍스트 잘림 방지 → 모든 화면 스크롤 안전(`SingleChildScrollView`/유연 레이아웃).

> 곱연산 상한을 **1.3 단일값**으로 못박아 qa 골든/회귀 합격선(기존 2.0)과의 간극을 제거한다. qa(20.3.3)의 골든 배율 세트도 확정된 상한(앱 3단계 + 클램프 1.3)에 정렬하도록 요청한다.

### 13.11.2 색·시맨틱·모드

| 항목 | 구현 |
|---|---|
| **색약 대응** | 정답=녹/오답=적 **단독 신호 금지**. O/X 아이콘 + "정답입니다"/"오답입니다" 텍스트 병행. 색약 안전 팔레트(design 제공), WCAG **AA 대비 ≥4.5:1** |
| **스크린리더** | TalkBack/VoiceOver: 모든 버튼 `Semantics` 라벨, 채점 결과는 `liveRegion`으로 자동 낭독, 포커스 순서 지정, 장식 요소 `excludeSemantics` |
| **다크모드** | 새벽 사용 맥락 → 라이트/다크 완전 지원 + 수동 토글. 순색 대비로 저조도 가독성 확보 |
| **오탭 방지·햅틱** | 선택지 간 간격 확보, 선택 시 중립 프레스 → **서버 응답 후** 정답/오답 `HapticFeedback`(경/중), 광고·이탈 버튼은 실수 방지 위치 |

### 13.11.3 접근성 검증

- 골든 테스트를 **텍스트 스케일 3종(1.0/1.15/1.3) × 라이트/다크 × 정답/오답 상태**로 촬영(13.16).
- 실기기 스크린리더 스모크 테스트를 릴리스 체크리스트에 포함.

---

## 13.12 성능 · 기기 지원 (갭: 저사양/약전파)

### 13.12.1 최소 지원 OS

- **결정: Android 8.0(API 26) / iOS 14.0**. 근거: 최신 광고·무결성 SDK 요구, 커버리지·개발비 균형. 중장년 구형기기 비중이 실측으로 높게 나오면 Android 7(API 24)까지 하향 검토(openQuestion, data 실측 필요).

### 13.12.2 성능 예산 (정량, 저사양 기준)

| 지표 | 목표 | 방법 |
|---|---|---|
| 콜드스타트 | 중급기기 ≤2.5s | 첫 프레임 이후로 광고/분석/무결성 SDK 초기화 지연, 경량 스플래시 |
| 문제 전환 | ≤100ms(로컬 버퍼) | 프리페치 버퍼(13.4.2), const 위젯 |
| 온라인 채점 피드백 | p95 ≤300ms | 서버 왕복 예산(server 협의), 마이크로 스피너로 흡수 |
| 프레임 | 60fps(저사양 30fps 하한) | `ListView.builder`, `RepaintBoundary`, `select`로 리빌드 최소화 |
| 앱 다운로드 크기 | ≤40MB | AAB + ABI 분리, webp/벡터 티어 에셋, 아이콘 트리셰이킹, 미사용 로케일 제거 |
| 메모리 | 저사양 OOM 없음 | `cached_network_image` memCacheWidth, 화면 이탈 시 광고/이미지 dispose |

- 리더보드는 수천 명 → 커서 페이지네이션 + 무한스크롤, 내 순위 상단 고정은 별도 경량 API.
- 무거운 JSON 파싱은 필요 시 `compute`(isolate)로 오프로드해 메인 스레드 잼 방지.
- **약전파**: 오프라인 배너 표시, 답안은 outbox 재전송, 광고 실패는 스킵(13.9.4).

---

## 13.13 크래시 · 에러 리포팅 · 관측

- **Firebase Crashlytics**: `FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`로 전역 캡처. 핸들된 에러는 non-fatal 로깅.
- 커스텀 키: `flavor`, 현재 화면, `quizSessionId`, 광고 로드 상태. 사용자 식별자는 **해시된 userId**(실명·카카오ID 원문 금지).
- 네트워크 에러 UX: 재시도 버튼 + 오프라인 배너(중장년 카피). 스택/코드 노출 금지.
- **분석 이벤트 택소노미**: **data 파트의 `taxonomy.yaml`이 유일 진실원(single source)이며 클라 발행 이벤트명은 이를 정확히 따른다**(명명 규칙 `object_action` 과거형).
  - **클라 발행(C)**: `quiz_question_answered`, `quiz_session_completed`, `ad_impression`/`ad_load_failed`, `invite_shared`, `report_submitted`, `attendance_checked_in`.
  - **서버 발행(S, 권위 상태 변화)**: `tier_promoted`, `subscription_started`, `church_registered`, `invite_validated`. 클라는 이들을 GA4로 **중복 발행하지 않는다**.
  - **민감정보 분리(PIPA §23·국외이전)**: `church_id` 등 종교 파생 속성은 **GA4(미국)로 전송 금지**. `core/analytics` 래퍼(`AnalyticsService`)가 이벤트 파라미터에서 `church_id`·종교 파생 속성을 차단하고, 해당 데이터는 **server→BigQuery(서울) 경로로만** 흐르게 한다(legal 국외이전 정합).
  - `core/analytics` 래퍼로 스키마를 강제(자유 문자열 금지)해 봇 제외·MAU/DAU·K-factor·수익 집계를 데이터 파트가 일관 집계하게 한다. 이벤트명 매핑표는 client·server(부록 A)·marketing이 `taxonomy.yaml`에 정렬한다.

---

## 13.14 i18n · 타임존 준비 (갭: 재외한인/타임존)

- **v1 한국어 단일**이지만 **첫날부터 하드코딩 금지**: 모든 문자열을 gen-l10n `.arb` 키로. 미래 다국어·재외한인 확장 비용 제거.
- `intl`로 숫자·날짜 포맷.
- **타임존**: 주간 리셋 경계는 **서버가 UTC 타임스탬프로 내려주는 값**이 유일 권위. 클라는 "마감까지 D-1"을 서버 시각 기준으로 표시. 재외한인은 로컬 시간으로 렌더하되 랭킹 경계는 서버 정의(KST)임을 명시 → 글로벌 확장 시 공정성 문제를 표시 레이어에서만 처리하도록 미리 분리(v1은 KST 단일, 확장은 future).

---

## 13.15 빌드 · CI/CD · 피처플래그 · 릴리스

### 13.15.1 Flavor

- **dev / staging / prod** 3종. 각각 별도 Firebase 프로젝트, AdMob 테스트/운영 앱ID, API base URL, 딥링크 도메인. 진입점 `main_dev.dart` 등 + `--dart-define`.

### 13.15.2 코드 사이닝 · 배포

| 플랫폼 | 서명 | 배포 |
|---|---|---|
| Android | Play App Signing + 업로드 키(CI 시크릿) | AAB → Play internal → 단계적 출시(staged rollout) |
| iOS | fastlane **match**(인증서/프로비저닝 Git 암호화) | TestFlight → App Store |

- **GitHub Actions**: PR에서 `flutter analyze` + 단위/위젯/골든 테스트. 태그 푸시 시 빌드·서명·베타 트랙 업로드(fastlane).

### 13.15.3 피처플래그 (Firebase Remote Config)

| 키 | 기본값 | 용도 |
|---|---|---|
| `ad_interstitial_every` | 20 | 광고 빈도 원격 조정 |
| `speed_void_threshold_ms` | 1500 | 속도 감지 임계(오탐 튜닝) |
| `church_top_n` | 20 | 교회 점수 상위N 실험(10/20/30) |
| `invite_label` | "초대왕" | **초대왕 vs 이달의 초대(중립) 파일럿** (branding 10.10: '전도왕'은 신학 리스크로 배제) |
| `min_supported_version` | - | **강제 업데이트** 게이트 |
| `kill_ads` / `kill_offline` / `kill_rewarded` | false | 사고 시 킬스위치(광고 / 오프라인 큐 / 보상형) |

- **강제 업데이트**: 앱 버전 < `min_supported_version`이면 차단 다이얼로그 → 스토어 이동(치명 버그·서명 규약 변경 대응).
- **초대 리더보드 명칭**: branding·legal의 신학 수용성 판단을 우선한다. '전도왕'은 branding(10.10)이 배제 권고하므로, client 원격 플래그·data 실험 셋업의 A/B 대상을 **'초대왕' vs '이달의 초대'**로 정렬한다('전도왕' 유지 시에는 파일럿 전 legal·branding 검토 완료가 전제).

---

## 13.16 테스트 전략

| 종류 | 대상 | 목표 |
|---|---|---|
| **단위** | 표시용 채점/콤보/재출제 할인 표시, outbox 대사·flush, 토큰 갱신(single-flight), 동의 게이팅, serve_token 캡처/반환, 타이머 | quiz domain 커버리지 ~80% |
| **위젯** | 퀴즈 화면 상태(로딩/채점중/정답/오답/무효), 온보딩, 선택지 버튼 a11y | 핵심 화면 |
| **골든** | 선택지 버튼·결과 화면을 **텍스트스케일 3종(1.0/1.15/1.3) × 라이트/다크 × 정답/오답**로 촬영(색약 검증) | 접근성 회귀 방지 |
| **통합**(`integration_test`) | 온보딩→진단→첫티어 / 코어루프 20문제→광고→결과 / 오프라인 플레이(제출 큐잉)→재연결 서버 채점 동기화 / 초대 딥링크 귀속(목킹) | 릴리스 게이트 |

- dev 플레이버는 AdMob **테스트 광고 단위** 강제(실광고 클릭 정책 위반 방지).
- 서버 API는 계약(OpenAPI) 기반 목/픽스처로 클라 단독 테스트 가능하게 유지.

---

## 13.17 구현 순서 (v1.0 10주 매핑) · 리스크

### 13.17.1 주차별 (제안)

| 주 | 산출물 |
|---|---|
| W1 | 프로젝트 스캐폴딩(flavor·라우터·테마·큰글씨 스케일·CI 뼈대), 디자인시스템 기초 |
| W2 | 인증(카카오+Apple)·JWT·동의 화면·연령게이트·온보딩 골격 |
| W3-4 | 퀴즈 엔진(프리페치·온라인 채점·serve_token·콤보·타이머·재출제 표시)·오답노트 로컬 |
| W5 | 리더보드(개인 3탭 + 교회 대항·규모리그)·교회 검색/등록 |
| W6 | 광고(전면 프리로드·UMP·ATT·폴백)·구독(IAP+영수증 검증) |
| W7 | 초대(MMP 딥링크 자동귀속·코드 폴백)·푸시(FCM·야간 동의·라우팅)·출석 |
| W8 | 오류 신고·오탐 소명 UX·안티치트 클라(serve_token·무결성·root 탐지)·오프라인 제출 큐 |
| W9 | 접근성 마감(스크린리더·색약·다크)·성능 튜닝·골든/통합 테스트 |
| W10 | 파일럿 빌드·강제업데이트·크래시 대시보드·스토어 심사 제출 |

### 13.17.2 클라이언트 리스크 톱

1. **온라인 채점 왕복 지연**이 300ms를 초과하면 즉시 피드백 UX가 깨진다 → 서버 지연 예산 협의(정오는 서버 응답 후 표시가 원칙이므로 스피너/스켈레톤 흡수 방식·server p95 예산을 명문화).
2. **MMP/딥링크 SDK 미확정**으로 초대 자동귀속·설치 어트리뷰션 착수 지연 → **data를 조정 오너로 W3까지 단일 벤더 확정**(카카오 딥링크·iOS SKAN·KR/원화 필수). data의 'MMP 보류'와 client/marketing의 'v1 필수'가 충돌하므로, 확정 실패 시 v1은 6자리 코드 수동귀속만·자동귀속 v1.1 연기의 스코프 조정을 명시 선택.
3. **앱 시크릿 보관 한계**로 클라 방어가 근본이 못 됨 → 서버 이상탐지가 최종 권위(server), serve_token 바인딩으로 위조 비용 상향. 무결성 실패 하드블록 여부는 오탐 우려로 신중.
4. **접근성 회귀**: 텍스트스케일·색약을 골든으로 상시 방어하지 않으면 중장년 이탈 직결. 배율 상한(1.3)·qa 골든 세트 정합 확정이 선행되어야 회귀 기준이 성립.

---

## 13.18 의존성 · 인터페이스 요약

- **server**: API 계약(OpenAPI 단일 확정)·표준 에러모델, 점수/콤보/재출제 할인/유효초대 서버 권위 계산, **보상형 배율분 교회 집계 제외(`rewarded_bonus`)**, 문항별 serve_token 발급·검증, 출석 서버시간, 무결성 토큰 검증, 영수증 검증, 리셋 타임스탬프(UTC), Remote Config 원천, 오프라인 batch flush 채점.
- **design**: 색약 안전 팔레트·WCAG AA 대비·**단일 큰글씨 배율 테이블(3단계 1.0/1.15/1.3 + 곱연산 상한 1.3)**·다크 토큰·티어/배지 에셋·광고 자리·오탭 간격/햅틱·**정오 피드백은 서버 응답 후 표시**.
- **ux**: 온보딩 순서(종교 동의는 비게이트)·동의/탈퇴/오탐 소명 카피·에러 메시지·초대 팝업 트리거 문구·오프라인 프리페치+제출 큐 모델·**즉시 채점(확인 스텝 없음) 정합**.
- **content**: 문제 스키마(근거구절·카테고리·난이도)·오늘의말씀 데이터·개역개정 표기.
- **monetization**: AdMob 앱/단위ID·미디에이션 구성·구독 상품ID·UMP 폼·**보상형 명예 가드레일**.
- **marketing**: MMP 선택(공동)·딥링크 설정·초대 명칭 A/B·종교 타깃 광고 정책 제약.
- **data**: **`taxonomy.yaml` 단일 진실원(이벤트명·S/C 소스·church_id GA4 차단)**·MMP 조정 오너·A/B 프레임워크·MAU/DAU·봇 제외 정의·SKAN 전환값.
- **legal**: 민감정보(종교, 교회등록 시점 선택 동의)·국외이전·ATT·연령·야간푸시·탈퇴/권리·저작권 문구·초대 명칭 신학 수용성.
- **qa**: 디바이스 매트릭스·골든/통합 케이스(배율 상한 1.3 정합)·serve_token 인터셉트 테스트·접근성 검증.
- **ops**: 피처플래그 운영·강제 업데이트 기준·CS 채널 연동·스토어 배포.
- **branding**: 앱 이름·딥링크 스킴·번들ID·초대 리더보드 명칭 확정.
- **org**: 파일럿 디바이스·베타 트랙 관리·MMP SaaS 예산.
