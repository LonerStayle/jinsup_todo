# Solo Todo — 자주 쓰는 명령 모음
#
# 사용법: `make <target>` 또는 그냥 `make` (= help).
# .env.local 이 있을 때만 --dart-define-from-file 자동 주입 (없으면 local-only 모드).

ENV_FILE := .env.local
DART_DEFINE := $(if $(wildcard $(ENV_FILE)),--dart-define-from-file=$(ENV_FILE),)

# ────────────────────────────────────────────────────────────────────────────
# Help (default)
# ────────────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo "Solo Todo — Makefile"
	@echo ""
	@echo "  make setup        deps 받기 + (macOS) pod install"
	@echo "  make codegen      freezed / json / drift codegen"
	@echo ""
	@echo "  make run          macOS 데스크탑 실행 (env 자동)"
	@echo "  make run-android  Android 첫 device 자동 선택 실행"
	@echo ""
	@echo "  make build-macos  release .app 산출 (build/macos/.../solo_todo.app)"
	@echo "  make build-apk    release .apk 산출 (build/app/outputs/flutter-apk/)"
	@echo ""
	@echo "  make test         flutter test (전체)"
	@echo "  make check        analyze + format check + test"
	@echo "  make format       dart format ."
	@echo "  make analyze      dart analyze"
	@echo ""
	@echo "  make clean        flutter clean + pub get"
	@echo ""
	@echo "  현재 env 파일: $(if $(wildcard $(ENV_FILE)),found ✓,없음 — local-only 모드)"

# ────────────────────────────────────────────────────────────────────────────
# Setup / Codegen
# ────────────────────────────────────────────────────────────────────────────
.PHONY: setup
setup:
	flutter pub get
	@if [ "$(shell uname)" = "Darwin" ] && [ -d macos ]; then \
		echo "→ pod install --project-directory=macos"; \
		pod install --project-directory=macos || echo "⚠️  CocoaPods 미설치. sudo gem install cocoapods 후 재시도"; \
	fi

.PHONY: codegen
codegen:
	dart run build_runner build

.PHONY: codegen-watch
codegen-watch:
	dart run build_runner watch --delete-conflicting-outputs

# ────────────────────────────────────────────────────────────────────────────
# Run
# ────────────────────────────────────────────────────────────────────────────
.PHONY: run
run:
	flutter run -d macos $(DART_DEFINE)

.PHONY: run-android
run-android:
	@DEV=$$(flutter devices --machine 2>/dev/null | grep -oE '"id":"[^"]+(emulator|android)[^"]*"' | head -1 | sed 's/"id":"//; s/"//'); \
	if [ -z "$$DEV" ]; then \
		echo "❌ 연결된 Android 기기 없음. flutter devices 로 확인"; \
		exit 1; \
	fi; \
	echo "→ device: $$DEV"; \
	flutter run -d $$DEV $(DART_DEFINE)

# ────────────────────────────────────────────────────────────────────────────
# Build (release)
# ────────────────────────────────────────────────────────────────────────────
.PHONY: build-macos
build-macos:
	flutter build macos --release $(DART_DEFINE)
	@echo "✓ build/macos/Build/Products/Release/solo_todo.app"

.PHONY: build-apk
build-apk:
	flutter build apk --release $(DART_DEFINE)
	@echo "✓ build/app/outputs/flutter-apk/app-release.apk"

# ────────────────────────────────────────────────────────────────────────────
# Quality gates
# ────────────────────────────────────────────────────────────────────────────
.PHONY: analyze
analyze:
	dart analyze

.PHONY: format
format:
	dart format .

.PHONY: format-check
format-check:
	dart format --output=none --set-exit-if-changed .

.PHONY: test
test:
	flutter test

.PHONY: check
check: analyze format-check test
	@echo "✓ analyze + format + test 모두 PASS"

# ────────────────────────────────────────────────────────────────────────────
# Housekeeping
# ────────────────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	flutter clean
	flutter pub get
