# 말씀퀴즈 (holy-quiz)

교회 대항 성경 퀴즈 앱 — 중장년 기독교인 대상 모바일 퀴즈 게임.

> 개인의 명예 티어와 "우리 교회"의 리더보드 순위를 위해 매일 성경 퀴즈를 겨룹니다.
> 서비스 개요는 [`docs/00-service-overview.md`](docs/00-service-overview.md), 전체 로드맵은 [`docs/40-roadmap.md`](docs/40-roadmap.md).

## 아키텍처

- **클라이언트:** Flutter + Riverpod 2.x + go_router (`/app`)
- **백엔드:** GCP + Firebase 서버리스 — Cloud Functions(TypeScript) · Firestore · FCM · Remote Config · Analytics(+BigQuery) · App Check (`/functions`)
- 결정 근거: [`docs/adr/ADR-001-gcp-firebase.md`](docs/adr/ADR-001-gcp-firebase.md)
- **서버 권위 원칙:** 점수·포인트 원장·리더보드·문제 정답은 클라이언트가 직접 쓰지 못하며, 오직 Cloud Functions를 통해서만 변경됩니다(Firestore 보안 규칙으로 강제). 교회 대항전 조작 방어의 핵심입니다.

## 모노레포 구조

```
holy-quiz/
├── app/                       # Flutter 앱 (Riverpod + go_router)
│   └── lib/src/
│       ├── core/              # theme(디자인 토큰), router, config
│       └── features/          # 기능별 레이어(data/domain/application/presentation)
├── functions/                 # Cloud Functions (TypeScript) — 서버 권위 로직
│   └── src/index.ts
├── docs/                      # 기획·설계 문서 (PRD, 파트 문서, 로드맵, ADR, 결정 로그)
├── tools/                     # 콘텐츠 파이프라인 등 운영 도구
├── firebase.json              # Firebase 설정 (CLI 관례상 리포 루트에 위치)
├── firestore.rules            # Firestore 보안 규칙 (서버 권위)
├── firestore.indexes.json     # 복합 인덱스
├── storage.rules              # Storage 규칙
├── remoteconfig.template.json # Remote Config 파라미터 (상위N·리셋요일·광고주기 등)
└── .firebaserc.example        # 프로젝트 매핑 예시 (복사해서 .firebaserc 생성)
```

> ℹ️ Firebase 설정 파일은 티켓 #16의 `/infra` 제안 대신 **리포 루트**에 두었습니다 — Firebase CLI가 `firebase.json`을 프로젝트 루트에서 찾는 관례를 따르기 위함입니다.

## 사전 요구사항

- Flutter SDK `>=3.24`, Dart `>=3.5`
- Node.js `22`, npm
- Firebase CLI (`npm i -g firebase-tools`)

## 시작하기

### 1) 앱 (`/app`)

```bash
cd app
flutter create .          # 플랫폼 폴더(android/ios) 생성 — lib/·pubspec은 유지됨
flutter pub get
flutter run
```

### 2) 함수 (`/functions`)

```bash
cd functions
npm install
npm run build             # tsc 컴파일
npm run serve             # 로컬 에뮬레이터 (firebase-tools 필요)
```

### 3) Firebase 연결

```bash
cp .firebaserc.example .firebaserc   # 프로젝트 ID 채우기
firebase emulators:start             # firestore/functions/auth 에뮬레이터
```

## 작업 관리 (트래커)

- 전체 작업은 GitHub Issues로 관리합니다: [트래커 인덱스 #1](https://github.com/mrkimkim/holy-quiz/issues/1)
- Epic = `epic`+트랙 라벨 / Ticket = sub-issue(`task`+`M0..M6`+`P0..P2`)
- 현재 마일스톤: **M0(기반)** — 스캐폴드·스키마·디자인·콘텐츠 파이프라인·교회 시딩

## 개발 브랜치

현재 작업 브랜치: `claude/service-planning-review-2ow992`
