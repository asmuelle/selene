# Selene

> A cycle, fertility, and perimenopause tracker whose AI insight engine runs entirely on-device — no server to subpoena, breach, or sell data from, verifiable in airplane mode.

## Concept

A cycle, fertility, and perimenopause tracker whose AI insight engine runs entirely on-device — no server to subpoena, breach, or sell data from, verifiable in airplane mode.

## Target User

Women 18-45 who churned from Flo/Clue after the $59.5M settlements and post-Dobbs subpoena fears; secondary wedge: perimenopausal women 35-55 ignored by fertility-focused incumbents.

## Why Edge AI Is Structural (not decoration)

iOS: AFM 3 Core (3B) with @Generable guided generation turns free-text/voice symptom logs into structured entries; Dynamic Profiles swap between logging, cycle-forecast, and fertility-Q&A modes; AFM 3 Core Advanced image input (iPhone 15 Pro+) reads ovulation/pregnancy test strips from photos. Android: Gemini Nano Prompt API on flagships, bundled Gemma 3n E2B via LiteRT-LM on mid-range. Structural, not decorative: reproductive data in any cloud is now a legal liability (Meta CIPA verdict, discovery requests), so the core promise — 'we cannot hand over what we never have' — is only true with zero data egress, proven via airplane-mode operation and published network audits.

## Why Now (2026 timing)

Trust in cloud period trackers collapsed in 2025-26 while the category remains a proven mass market; WWDC26's AFM 3 image input just made on-device test-strip reading possible; Guideline 5.1.2(i) consent friction now actively penalizes cloud-AI competitors at App Review.

## Tech Stack

iOS (iOS 26+, iPhone 15 Pro+ floor): SwiftUI; FoundationModels framework — SystemLanguageModel with @Generable guided generation for free-text/voice symptom → structured entry, Tool calling into a local stats engine; deterministic hierarchical Bayesian cycle/ovulation model in Swift (no LLM) for forecasts; SpeechAnalyzer/SpeechTranscriber (iOS 26) for on-device ASR instead of Whisper; test strips via a dedicated compact Core ML vision model (Vision framework strip detection + custom CNN classifier trained on LH/hCG strip datasets) — do NOT depend on AFM 3 Core Advanced image input given its high-end-only device floor; local RAG over a curated, citation-pinned ACOG/NICE-derived content pack using a small on-device embedding model (EmbeddingGemma-class via Core ML) to ground fertility/perimenopause Q&A and cap hallucination; GRDB/SQLite with NSFileProtectionComplete, backup exclusion by default + Advanced Data Protection guidance; StoreKit 2 only network surface; zero third-party SDKs; publish reproducible network audits (mitmproxy capture + App Privacy Report). Android: Kotlin + Jetpack Compose; ML Kit GenAI Prompt API (Gemini Nano) on supported flagships; fallback Gemma 3n E2B / Gemma 4-class via MediaPipe LLM Inference API on LiteRT-LM, weights delivered through Play Feature Delivery (on-demand, not in base APK); whisper.cpp small or offline SpeechRecognizer for ASR; same strip-reading model exported to LiteRT; Room + SQLCipher. Shared: Kotlin Multiplatform core for cycle math, Bayesian forecaster, schema, and content pack so insight logic is identical across platforms; ship Android as logging-first with AI tier gated to Nano-capable devices at launch.
