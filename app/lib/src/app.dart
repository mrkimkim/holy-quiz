import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

/// 앱 루트. 라우팅은 #E3부터 go_router(core/router)로 교체.
class MalssumQuizApp extends StatelessWidget {
  const MalssumQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '말씀퀴즈',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: const _ScaffoldPlaceholder(),
    );
  }
}

class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('말씀퀴즈', style: text.displaySmall),
              const SizedBox(height: 8),
              Text('교회 대항 성경 퀴즈', style: text.titleLarge),
              const SizedBox(height: 32),
              const Text('스캐폴드 — 홈 화면은 온보딩/퀴즈 티켓에서 구현'),
            ],
          ),
        ),
      ),
    );
  }
}
