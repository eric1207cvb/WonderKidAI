# Repository Guidelines

## Project Structure & Module Organization
WonderKidAI is an iOS SwiftUI app. Key paths:
- `WonderKidAI/`: app source (SwiftUI views, managers, services, `Info.plist`).
- `WonderKidAI/Assets.xcassets`: images and asset catalogs.
- `WonderKidAITests/`: unit tests (XCTest).
- `WonderKidAIUITests/`: UI tests (XCTest UI).
- Root `*.md` files: feature notes and testing guides.
- `WonderKidAI.xcodeproj`: Xcode project entry point.

## Build, Test, and Development Commands
Use Xcode or `xcodebuild`:
- `open WonderKidAI.xcodeproj` opens the project in Xcode.
- `xcodebuild -scheme WonderKidAI -destination 'platform=iOS Simulator,name=iPhone 15' build` builds the app.
- `xcodebuild -scheme WonderKidAI -destination 'platform=iOS Simulator,name=iPhone 15' test` runs unit + UI tests.
If your simulator differs, update the `-destination` name.

## Coding Style & Naming Conventions
- Swift standard style: 4-space indentation, braces on the same line.
- Naming: `PascalCase` for types, `camelCase` for variables/functions, `lowercase` file names matching primary types.
- Keep SwiftUI views small and focused; prefer reusable subviews.
- No repository-wide formatter config is present; format consistently with existing files.

## Testing Guidelines
- Frameworks: XCTest (unit + UI).
- Test files live in `WonderKidAITests/` and `WonderKidAIUITests/`.
- Name tests descriptively (e.g., `testSubtitleSyncAdvancesIndex`).
- Manual verification for subtitle/TTS behavior is documented in `TESTING_GUIDE.md` and `TTS_SYNC_TEST_GUIDE.md`.

## Commit & Pull Request Guidelines
- Commit messages in history are short, imperative, and bilingual; examples include `Fix: ...` and concise Chinese summaries.
- Prefer one change per commit; include context when the change is subtle.
- PRs should describe the user-facing impact, testing performed, and include screenshots for UI changes.

## Configuration & Privacy Notes
- App configuration lives in `WonderKidAI/Info.plist`.
- Review `PRIVACY.md` before changes that affect data collection or user-facing disclosures.
