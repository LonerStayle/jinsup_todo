# AGENTS.md — 빌드/검증 명령

> ralph 가 매 iteration 검증에 사용하는 단일 출처.
> 60줄 이하 유지. 명령만. 도메인 설명은 specs/, 환경 컨텍스트는 CLAUDE.md.

---

## 환경 사전조건

- 운영체제: macOS 26.2 (Apple Silicon)
- 런타임 버전: Flutter 3.41.9 (stable) / Dart 3.11.5
- 패키지 매니저: pub (flutter pub) / Gradle (Android) / CocoaPods (macOS)

---

## 셋업 (1회)

```bash
flutter pub get
# macOS desktop:  pod install --project-directory=macos  (CocoaPods 필요)
# Android:        Android Studio + JDK 17 권장. 첫 빌드 시 SDK 자동 동기화.
```

---

## 필수 검증 명령 (ralph 가 매 iteration commit 직전 실행)

모든 명령이 exit 0 이어야 commit 한다.

```bash
# 1) lint (Dart analyzer)
dart analyze

# 2) format check (자동 포맷 적용된 상태 유지 확인)
dart format --output=none --set-exit-if-changed .

# 3) tests (단위 + 위젯 + integration)
flutter test
```

---

## 선택 검증 (품질 게이트 — 시간 소요)

```bash
# release 빌드 smoke
flutter build macos --release
flutter build apk --release
```

---

## 실행 (로컬 확인용)

```bash
# macOS desktop
flutter run -d macos --dart-define-from-file=.env.local

# Android (실기기/에뮬레이터)
flutter devices
flutter run -d <device_id> --dart-define-from-file=.env.local
```
