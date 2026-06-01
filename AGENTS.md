# Repository Guidelines

## Project Structure & Module Organization

Type4Me is a Swift Package Manager macOS menu bar app; there is no Xcode project. Main code lives in `Type4Me/`: `ASR/` and `LLM/` contain provider abstractions and clients, `Audio/` records input, `Session/` coordinates recognition and injection, `Services/` handles persistence/process lifecycle, and `UI/` contains SwiftUI screens. Tests live in `Type4MeTests/`. Release scripts are in `scripts/`; local ASR services are in `qwen3-asr-server/` and `sensevoice-server/`. Do not commit local binaries such as `Frameworks/sherpa-onnx.xcframework`.

## Build, Test, and Development Commands

```bash
swift build                              # Debug build
swift build -c release                   # Release binary
swift test                               # Run XCTest
bash scripts/deploy.sh                   # Build, install, launch
VARIANT=pure bash scripts/build-dmg.sh   # Cloud/BYOK DMG
VARIANT=local bash scripts/build-dmg.sh  # Local ASR DMG
bash scripts/build-sherpa.sh             # Optional punctuation framework
```

For optional Qwen3-ASR, create a Python 3.12 virtualenv in `qwen3-asr-server/` and install `requirements.txt`. When switching variants manually, clear SwiftPM caches with `rm -rf .build ~/Library/Caches/org.swift.swiftpm`.

## Build Variants & Architecture Rules

`Package.swift` enables `HAS_SHERPA_ONNX` from `Frameworks/sherpa-onnx.xcframework/Info.plist` and `HAS_CLOUD_SUBSCRIPTION` from `Type4Me/CloudSubscription/marker`. Public releases ship `pure` and `local`; the `official` subscription path is archived, so do not restore the marker unless explicitly asked.

ASR providers plug into `ASRProvider`, `ASRProviderConfig`, `SpeechRecognizer`, and `ASRProviderRegistry`. Keep streaming final text separate from partial text. Preserve the initial-audio skip that avoids start-sound bleed. `ModelManager` downloads must use delegate-based `URLSession.downloadTask` so progress, resume, retry, and cancellation keep working.

## Coding Style & Naming Conventions

Use 4-space indentation and idiomatic Swift names: `UpperCamelCase` for types and `lowerCamelCase` for methods, properties, and enum cases. Keep provider payload logic near `Type4Me/ASR`, `Type4Me/LLM`, or `Type4Me/Protocol`; UI in `Type4Me/UI`; storage/process orchestration in `Type4Me/Services`. Use existing feature flags for variant-specific behavior.

## Testing Guidelines

Use XCTest under `Type4MeTests/`. Name files after the unit under test, for example `VolcProtocolTests.swift`, and start test methods with `test`. Cover parsing, state transitions, credentials, and provider edge cases. Run `swift test` before PRs; for packaging or UI changes, also run the relevant deploy or DMG command.

## UI & App Behavior Rules

Dangerous actions need two-step confirmation. Undownloaded model rows should show download actions, not selection controls. Keep destructive actions separated from test/action buttons. Download progress must update through `@Published` state on `@MainActor`. Bundled sounds belong in `Type4Me/Resources/Sounds/`.

## Commit & Pull Request Guidelines

Recent history uses concise conventional-style subjects such as `chore(release): prepare v1.9.4` and `polish(settings): align thinking mode control`. Use an imperative subject with optional scope. PRs should include user-facing change, affected build variant, tests run, linked issue if relevant, and screenshots or recordings for visible UI changes.

## Security & Configuration Tips

Do not commit API keys, downloaded models, local frameworks, or user data. Secure credentials belong in macOS Keychain; non-secure settings live under `~/Library/Application Support/Type4Me/`. GUI-launched apps cannot reliably read shell environment credentials. The app requires Microphone and Accessibility permissions. Preserve `~/Library/Application Support/Type4Me` during app-bundle cleanup.
