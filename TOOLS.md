# TOOLS.md — Selene

The complete tool surface for this repo. If a command isn't here, it shouldn't be run.

## just recipes

| Recipe | What it does | When to run it |
|---|---|---|
| `just` | Lists recipes. | Orientation. |
| `just bootstrap` | Runs `xcodegen generate` from `project.yml`, then resolves SPM packages. | Once at M0, and whenever `project.yml` or package manifests change. |
| `just build` | `xcodebuild build` for the `Selene` scheme, iOS Simulator destination, code signing off. | Sanity check during development. |
| `just test` | `swift test` (full core suite on macOS), then `xcodebuild test` on the simulator (iPhone 16 preferred, falls back to iPhone 17 Pro or the first available iPhone). | After every change; part of TDD loop. |
| `just lint` | `swiftlint` over the repo; skips with a notice when swiftlint is not installed. | Before committing; CI runs it too. |
| `just format` | `swiftformat .` in place. | Hooks format on edit; run manually after bulk changes. |
| `just ci` | `lint` + `build` + `test`. | The gate. Green before every commit. |

All recipes detect a non-bootstrapped repo (`project.yml` / `Selene.xcodeproj` missing) and fail
with guidance instead of raw xcodebuild errors. Tooling prerequisites: Xcode 26+,
`brew install just xcodegen swiftformat swiftlint`.

## External data sources & APIs

By design, the runtime app has **no external API surface**. "We cannot hand over what we never
have" only holds with zero egress, so the dependency list is the product:

| Surface | Type | Network? | Notes |
|---|---|---|---|
| FoundationModels (`SystemLanguageModel`, `@Generable`) | On-device Apple framework | No | Structured extraction + narration. Handle `.unavailable` and guardrail refusals with deterministic fallbacks. No auth, no cost, no rate limits. |
| SpeechAnalyzer / SpeechTranscriber (iOS 26) | On-device Apple framework | No | Voice symptom logging ASR. Replaces Whisper; nothing to download or key. |
| Vision + Core ML (custom strip CNN) | On-device model | No | LH/hCG strip classifier trained offline (see asset pipeline below); shipped in the app bundle. |
| StoreKit 2 | Apple commerce API | **Yes — the only one** | Entitlements, $39.99/yr + lifetime SKU, 7-day trial. Confined to `Paywall/`. |
| GRDB (SQLite) | SPM dependency | No | The single third-party package on the allowlist. |
| ACOG/NICE-derived content pack | Editorial asset, not an API | No | Curated, citation-pinned at build time into `ContentPack/`; updates ship via app updates, never fetched at runtime. |

Offline asset pipelines (dev-side, never in-app): strip-classifier training on labeled LH/hCG
strip imagery (Core ML export), embedding generation for the content pack. Both produce versioned
artifacts committed via the release process, with eval reports.

## Required env vars

The shipping app requires **zero** env vars and contains zero secrets — that's invariant #1 and #2
in `AGENTS.md`. Dev/release tooling only:

| Var | Purpose | Needed when |
|---|---|---|
| `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_P8` | App Store Connect API auth for future release automation (TestFlight/upload). | M3+, release lanes only. Never required for `just ci`. |

## Local services

None. No docker compose, no database server, no mock backend — SQLite lives in the simulator's
sandbox. This is a feature: if you find yourself wanting a local server, re-read the invariants.

## CI overview (`.github/workflows/ci.yml`)

- Runs on `macos-26` (Xcode 26 / iOS 26 SDK), triggered by every push and pull request.
- Steps: checkout → `extractions/setup-just@v3` → `brew install swiftformat swiftlint` → guard step.
- **Bootstrapped guard:** if `project.yml` is absent, CI emits a notice and skips lint/build/test so
  the docs-only scaffold stays green. Once `project.yml` exists, CI installs XcodeGen, runs
  `just bootstrap`, then `just ci`. Don't add steps that bypass `just`.

## AI harness notes

`.claude/settings.json` (copied verbatim from the iOS scaffold template) configures:

- **PostToolUse hooks on Write|Edit:** edited `.swift` files are auto-formatted with swiftformat,
  then swiftlint prints the first 10 findings. Don't manually reformat; fix lint findings instead.
- **Permission allowlist:** `just`, `xcodebuild`, `xcrun`, `swift`, `swiftformat`, `swiftlint`,
  `xcodegen`, plus read-only git. Stay inside it.

Most useful subagents for this repo:

- **tdd-guide** — before any new feature; the forecast engine and migrations live or die by tests.
- **code-reviewer** — immediately after writing/modifying code, every time.
- **security-reviewer** — mandatory for changes in `Persistence/`, `Paywall/`, anything parsing
  user text/photos, and anything that adds an import of a networking API.
- **planner** — for milestone-sized work (each of M0–M3 deserves a plan before code).
