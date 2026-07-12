import 'package:flutter/material.dart';

/// 디자인 토큰 — 결정 C3(딥블루 + 웜골드 + 크림). 상세 확정은 티켓 #25.
class AppColors {
  AppColors._();

  static const Color deepBlue = Color(0xFF1D4E89); // primary — 신뢰
  static const Color warmGold = Color(0xFFE0A82E); // secondary — 명예
  static const Color cream = Color(0xFFF7F3E9); // surface — 따뜻함
  static const Color correct = Color(0xFF2E7D5B);
  static const Color wrong = Color(0xFFC0392B);
}

class AppTheme {
  AppTheme._();

  /// 중장년 기본값: 본문 18 / 지문 22 / 큰 터치타깃(≥56dp).
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.deepBlue,
      primary: AppColors.deepBlue,
      secondary: AppColors.warmGold,
      surface: AppColors.cream,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 18),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56), // 오터치 방지 큰 버튼
          textStyle: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
