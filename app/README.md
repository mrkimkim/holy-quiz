# app — 말씀퀴즈 Flutter 클라이언트

Flutter + Riverpod 2.x + go_router. 중장년 접근성이 기본값(큰 글씨·큰 터치타깃·얕은 탭 깊이).

## 초기화

`lib/`·`pubspec.yaml`은 이미 있으므로, 플랫폼 폴더만 생성합니다.

```bash
cd app
flutter create .        # android/ios/ 등 플랫폼 폴더 생성 (기존 lib/·pubspec 유지)
flutter pub get
flutter run
```

Firebase 연결(#17) 후 `flutterfire configure`로 `lib/firebase_options.dart`를 생성하고,
`main.dart`의 `Firebase.initializeApp` TODO를 활성화합니다.

## 구조 (feature-first 레이어링)

```
lib/
├── main.dart
└── src/
    ├── app.dart                 # MaterialApp / (예정) go_router
    ├── core/
    │   ├── theme/app_theme.dart # 디자인 토큰 (결정 C3) — 상세 #25
    │   ├── router/              # go_router (#E3~)
    │   └── config/              # Remote Config 바인딩 (#18)
    └── features/                # 기능별: data / domain / application / presentation
        ├── onboarding/  auth/  quiz/  leaderboard/  church/  invite/  profile/
```

각 feature는 해당 GitHub 티켓에서 구현합니다. 상세 아키텍처는 `docs/parts/13-client.md`.
