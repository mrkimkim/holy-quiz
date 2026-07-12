# functions — 말씀퀴즈 Cloud Functions (TypeScript)

서버 권위 로직을 담는 Firebase Cloud Functions(2nd gen). 점수·포인트 원장·리더보드·초대 귀속 등 **모든 신뢰가 필요한 쓰기는 여기서만** 수행합니다.

- 리전: `asia-northeast3`(서울)
- 런타임: Node.js 22

## 개발

```bash
npm install
npm run build        # tsc 컴파일 (lib/ 생성)
npm run lint
npm run serve        # 로컬 에뮬레이터 (firebase-tools 필요)
```

## 구조(예정)

```
src/
├── index.ts                # 엔트리 — 함수 export
├── auth/kakao.ts           # #24 카카오 → Firebase 커스텀 토큰
├── quiz/                   # #E4 문제 서브/채점(서버 권위)
├── points/                 # #E5 포인트 원장·티어
├── leaderboard/            # #E6 주간 집계 스케줄러
├── invite/                 # #E8 초대 귀속·유효초대
└── report/                 # #E9 신고·자동 격리
```

각 모듈은 해당 GitHub 티켓에서 구현합니다.
