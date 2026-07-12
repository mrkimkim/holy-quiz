import { setGlobalOptions } from "firebase-functions/v2";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { initializeApp } from "firebase-admin/app";

initializeApp();

// 서울 리전 · cold start 관리를 위한 전역 옵션(지연 민감 함수는 개별 minInstances 지정)
setGlobalOptions({ region: "asia-northeast3", maxInstances: 10 });

/**
 * 헬스체크 — 스캐폴드 검증용. 배포/에뮬레이터 동작 확인 목적.
 * 실제 기능(채점·리더보드·인증 등)은 각 티켓에서 추가한다.
 */
export const health = onRequest((_req, res) => {
  logger.info("health check ok");
  res.json({ ok: true, service: "malssum-quiz-functions" });
});

// TODO(#24):  auth/kakao      — 카카오 로그인 → Firebase 커스텀 토큰
// TODO(#E4):  quiz            — 문제 서브(serve_token)·채점(서버 권위, nonce)
// TODO(#E5):  points          — 포인트 원장·티어 승급
// TODO(#E6):  leaderboard     — 주간 집계 스케줄러(교회 상위 N 합산)
// TODO(#E8):  invite          — 초대 귀속·유효초대 판정
// TODO(#E9):  report          — 오류 신고·자동 격리
