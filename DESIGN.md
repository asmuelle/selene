# DESIGN.md — Selene

## Thesis

Reproductive-health data in any cloud is now a legal liability (Flo/Google/Flurry $59.5M
settlement, Meta CIPA verdict), so the only credible AI cycle tracker is one whose intelligence
runs entirely on-device — a claim Selene makes verifiable, not rhetorical, via airplane-mode
operation and reproducible network audits. Zero marginal inference cost enables a lifetime SKU
that cloud incumbents structurally cannot match. The defensible wedge is perimenopause depth plus
proof-grade privacy, not "private" as a marketing adjective.

## Architecture

### Data flow (capture → on-device inference → store → surface)

```text
CAPTURE                 ON-DEVICE INFERENCE            STORE                 DERIVE & SURFACE
tap-log UI ───────────────────────────────────────┐
free text ──► AFM @Generable extraction ──────────┤
voice ──► SpeechAnalyzer ASR ──► AFM extraction ──┼──► GRDB (encrypted, ──► CycleEngine (Bayesian,
strip photo ──► Vision detect ──► strip CNN ──────┘    backup-excluded)      deterministic) ──► Forecast
                                                                                  │
                                                       ContentPack (pinned  ◄────┘
                                                       citations + local    InsightKit narrates
                                                       embeddings, RAG)  ──► engine output ──► SwiftUI
```

One-way dependencies: capture writes to the store; `CycleEngine` reads the store and writes
`Forecast`s; `InsightKit` reads forecasts + logs + `ContentPack` and writes `Insight`s. Nothing in
this graph touches the network. `Paywall/` (StoreKit 2) sits beside it as the sole networked
module and gates which derived surfaces render.

### Compute placement (cost discipline)

| Layer | Used for | Why |
|---|---|---|
| Deterministic Swift | Cycle/ovulation/perimenopause forecasting (hierarchical Bayesian), cycle stats, phase math, PDF assembly | Correctness, reproducibility, testability. The headline feature is math, not an LLM. |
| Small custom model (Core ML CNN) | LH/hCG strip line detection + classification | Calibration-sensitive CV; a general VLM is unreliable on faint lines and the AFM image-capable tier has too high a device floor. |
| On-device 3B (AFM Core, `@Generable`) | Free-text/voice → structured entries; narrating engine output; grounded Q&A over `ContentPack` | Squarely within 3B competence (structured extraction, summarization). ~4K context respected by feeding pre-aggregated engine output, never raw 6-month logs. |
| Frontier / cloud model | **Never.** | Zero egress is the product. There is no "just this once" exception. |

### Module map

```text
project.yml          — XcodeGen spec (committed); Selene.xcodeproj is generated, never committed
App/                 — SwiftUI app shell, composition root, dynamic mode profiles (logging /
                       cycle-forecast / fertility-Q&A / perimenopause)
Packages/
  SeleneCore/        — entities, symptom taxonomy, units, shared protocols. Zero dependencies.
  CycleEngine/       — hierarchical Bayesian forecaster. Pure functions, seeded RNG, no LLM/UI/IO.
  Persistence/       — GRDB store, NSFileProtectionComplete, backup exclusion, migrations, export/delete.
  InsightKit/        — FoundationModels sessions: @Generable extraction, narration, Q&A with citations.
  StripVision/       — Vision rectangle/strip detection + custom CNN classifier + confidence policy.
  ContentPack/       — versioned ACOG/NICE-derived chunks, pinned citations, embedding index (local RAG).
  Paywall/           — StoreKit 2 entitlements, trial, lifetime SKU. Only module with network access.
  SeleneUI/          — design tokens, cycle wheel, charts, components (both themes).
```

Swift 6 strict concurrency everywhere; `CycleEngine` and `SeleneCore` are platform-agnostic by
design so they can later be mirrored into the Kotlin Multiplatform core for Android phase 2
(Gemini Nano Prompt API on flagships, Gemma 3n E2B via LiteRT-LM mid-range, logging-first launch).

## Data model sketch

- **UserProfile** — local only: birth year band, mode (cycle / TTC / perimenopause), typical cycle
  length prior, onboarding flags, ADP-guidance-shown. No name, no email, no account id.
- **Cycle** — start date, end date (nullable while open), computed length, phase boundaries,
  source (logged / inferred), anomaly flags.
- **DailyLog** — date, flow level, basal temp, sleep/mood scales, free-text note (encrypted at
  rest like everything else), entry source (tap / text / voice / strip).
- **SymptomEvent** — log date, taxonomy code (fixed vocabulary incl. perimenopause set: hot
  flashes, night sweats, brain fog, cycle irregularity), severity 1–4, extraction confidence,
  user-confirmed flag.
- **Forecast** — generated-at, engine version, predicted period window + ovulation window as
  credible intervals (50/80/95%), posterior parameters snapshot, input-data range. Written only
  by `CycleEngine`.
- **StripReading** — capture date, test type (LH / hCG), classifier result, line-intensity score,
  confidence, user-confirmation state (pending / confirmed / rejected), photo deleted-after-read flag.
- **Insight** — kind (pattern report / symptom cluster / cycle narrative / Q&A answer), generated
  text, citation ids (must resolve into ContentPack), source-data range, model id + guardrail
  fallback flag, paywall tier.
- **ContentChunk** — stable citation id, source (ACOG / NICE / pack editorial), passage text,
  embedding vector, pack version.
- **DoctorVisitSummary** — date range, included cycles/symptoms/forecasts, rendered PDF blob,
  created-at. Deterministic assembly; LLM contributes prose sections only, each citation-tagged.
- **Entitlement** — product id (annual / lifetime), state, trial window, last StoreKit
  verification. The only entity whose lifecycle touches the network.

## Key flows

### 1. Voice/free-text symptom log (the daily habit)

1. User dictates "barely slept, night sweats again, spotting this morning"; SpeechAnalyzer
   transcribes on-device.
2. `InsightKit` runs `@Generable` extraction → candidate `SymptomEvent`s + `DailyLog` fields with
   per-field confidence.
3. UI shows a confirm sheet (chips, editable) — extraction is suggestive, the user's tap is the
   commit. On model refusal/unavailability, fall through to the manual tap-log UI silently.
4. Confirmed entries persist via `Persistence`; `CycleEngine` recomputes affected forecasts.

### 2. Cycle forecast (deterministic core)

1. On new data or app foreground, `CycleEngine` loads cycle history + relevant signals.
2. Hierarchical Bayesian update: population-shaped priors (shipped constants, not server data)
   blended with the user's history; perimenopause mode widens variance instead of pretending
   precision.
3. Emits `Forecast` with credible intervals; UI renders the cycle wheel with an uncertainty band —
   never a single overconfident date.
4. Paywalled narrative ("your luteal phase shortened ~2 days over 3 cycles") is `InsightKit`
   narrating engine numbers; it cannot alter them.

### 3. Test-strip photo read

1. User photographs an LH/hCG strip; Vision locates the strip region; photo is processed in memory
   and discarded by default.
2. Custom CNN classifies line presence/intensity → result + confidence.
3. Confidence below threshold → "unclear — retest in good light", no guess stored. Above
   threshold → result shown as *advisory* with explicit user confirm before a `StripReading`
   commits.
4. Confirmed LH surges feed `CycleEngine` as an observation (likelihood term), tightening the
   ovulation posterior.

### 4. Grounded fertility/perimenopause Q&A

1. User asks "is a 24-day cycle normal at 44?"; embedding lookup retrieves top `ContentChunk`s.
2. `InsightKit` answers with AFM constrained to retrieved chunks + the user's engine-derived stats;
   every claim carries a citation chip resolving to the pinned source.
3. Retrieval miss or guardrail refusal → curated fallback card for the topic, or honest "Selene
   can't answer this — bring it to your clinician" with the relevant summary export offered.

### 5. Doctor-visit summary → conversion moment

1. User (perimenopause wedge especially) taps "Prepare for my appointment", picks a date range.
2. Deterministic assembly: cycle table, symptom frequency/severity trends, forecast history;
   `InsightKit` adds a one-page citation-tagged prose summary.
3. Rendered to PDF locally; share sheet only — nothing uploaded anywhere.
4. Feature sits behind the hard paywall (7-day trial): `Paywall/` checks `Entitlement`; the
   preview-then-paywall presentation is the primary conversion surface.

## Product & visual design direction: Lunar Almanac

One direction, committed: a **night-sky observatory almanac** — calm, grown-up, and precise, named
for the moon goddess and built around the cycle-as-orbit metaphor. Explicitly not the category's
infantilizing pink-petal idiom, and not generic health-app mint.

- **Palette:** deep ink indigo surfaces (`oklch(22% 0.04 280)` family) with warm moonlight ivory
  text; single lunar-gold accent (`oklch(80% 0.12 85)`) reserved for *today* and confirmed events;
  semantic dusty-rose only for flow data, sage for fertile-window bands. Light theme is "daylight
  almanac": warm paper ivory with the same indigo as ink. Both themes are first-class.
- **Typography:** New York (serif) for display numerals and headings — almanac authority without
  novelty fonts — paired with SF Pro for body/UI; generous numeric tabular figures for dates.
- **Signature element:** the cycle wheel as a moon-phase ring — current day as a glowing marker,
  forecast windows as soft luminous arcs whose *width is the credible interval*, making honest
  uncertainty the aesthetic instead of hiding it.
- **Tone:** quiet confidence; privacy proof points (airplane-mode badge, "0 network calls" audit
  link) rendered as part of the UI chrome, because the proof *is* the brand.

## Milestones

### M0 — Bootstrap (make `just ci` green)

Create `project.yml` (app target `Selene`, iOS 26 deployment, Swift 6 strict concurrency), the
eight SPM packages with placeholder public APIs, one real Swift Testing test per package, lint/
format configs. **Accept:** `just bootstrap && just ci` green locally and in GitHub Actions;
`.xcodeproj` untracked; CI guard now takes the bootstrapped path.

### M1 — Thin vertical slice (log → forecast → wheel, fully offline)

Manual tap-logging of flow + the core symptom taxonomy → encrypted GRDB store → `CycleEngine`
Bayesian forecast → cycle wheel with credible-interval arcs. No LLM, no paywall, no voice yet.
**Accept:** complete flow works in airplane mode (UI test); engine reproduces golden fixtures
(regular / irregular / perimenopausal synthetic histories) bit-identically under a fixed seed;
≥ 90% coverage on `CycleEngine`, ≥ 80% on `Persistence`; backup-exclusion and file-protection
attributes asserted by integration tests.

### M2 — Trust layer (the proof, plus grounded intelligence)

Egress test harness: CI dependency allowlist + network-import grep; documented reproducible
mitmproxy capture procedure + App Privacy Report walkthrough published in-repo; in-app privacy
proof screen (airplane-mode demo, audit link). `InsightKit` extraction + narration with citation
pinning and refusal fallbacks; `ContentPack` v1 (perimenopause-weighted); voice logging.
**Accept:** automated check fails the build on any networking symbol outside `Paywall/`; every
shipped `Insight` resolves all citation ids; forced-refusal test path renders template fallback;
extraction eval ≥ agreed precision on the labeled corpus.

#### Egress audit layers (implemented in M2)

The zero-egress claim is enforced at three layers, each independently testable:

1. **Static source scan** (`Tests/RepoGuards`): every `swift test` run greps `Packages/`,
   `App/`, and `Tests/` for networking primitives (`URLSession`, `import Network`, sockets,
   `NSURLConnection`, …) outside `Paywall/`, asserts the `Package.resolved` dependency
   allowlist (GRDB only), and scans for tracking-SDK imports. Any hit fails the suite.
2. **Runtime URLProtocol harness** (`Tests/EgressGuard`): `EgressInterceptor` is a
   `URLProtocol` registered in-process that claims every URL-loading request, records it,
   and fails the load before it can reach the network. `NoEgressFlowTests` runs the complete
   core flow — tap-log → encrypted store → `CycleEngine` forecast → narration → grounded
   Q&A → wheel/interval/privacy presentation — under the armed tripwire and fails on any
   recorded attempt. A positive control inside `PaywallTests` (the only module allowed to
   touch networking APIs) attempts a real `URLSession` load and asserts the harness records
   and blocks it, proving the tripwire actually trips. **This harness is the local,
   in-process substitute for a mitmproxy capture: mitmproxy is not part of the dev
   toolchain, so the reproducible proxy-capture procedure remains a release-audit artifact
   (see below) rather than a per-commit gate.**
3. **User-facing proof** (`PrivacyProofView` / `PrivacyProofViewModel` in `SeleneUI`): the
   in-app airplane-mode privacy-proof screen shows the zero-egress status, the complete
   inventory of what data exists, where it lives (encrypted, backup-excluded, on-device —
   or honestly "in-memory" in test sessions), and the verification steps a skeptical user
   can reproduce (airplane-mode demo, iOS App Privacy Report).

Still open from the M2 definition: the published mitmproxy release-audit walkthrough (needs
mitmproxy, deliberately not in the dev harness), voice logging, and the AFM `@Generable`
extraction eval against a labeled corpus (the extraction surface stays behind
`LanguageModelProviding` with deterministic mocks until then).

### M3 — Monetization wiring

StoreKit 2: $39.99/yr with 7-day trial + $89.99 lifetime; hard paywall gating insights, voice,
strip reading, doctor-visit summary; doctor-visit PDF shipped (the perimenopause conversion
artifact); perimenopause-specific onboarding funnel variant. **Accept:** entitlement state machine
unit-tested incl. trial expiry/restore/refund; sandbox purchase E2E on simulator; free tier
(logging, history, export) verified fully functional with zero entitlements; paywall copy contains
no medical-claim language (1.4.1 review pass).

(Strip reading via `StripVision` ships when its held-out eval — including faint-line cases —
clears the accuracy gate; it is feature-flagged independent of M3.)

#### M3 implementation notes (monetization wiring, first slice)

What ships in this slice, all behind tests:

1. **Entitlement core** (`Paywall/`): `PurchaseProviding` is the commerce seam;
   `EntitlementReducer` is the pure state machine (never-trialed / in-trial / expired /
   subscribed / lifetime, restore and refund landing via snapshots); `EntitlementStore` wires
   provider + injected `DayClock` + `FeatureGate`. No entitlement logic reads the system clock —
   trial expiry is tested by advancing a fixed clock. The deterministic `MockPurchaseProvider`
   carries every test and every non-StoreKit run of the app.
2. **StoreKit 2 adapter** (`StoreKitPurchaseProvider`): real `Product.products`, `purchase()`,
   `Transaction.currentEntitlements`, and a `Transaction.updates` listener behind the protocol.
   Config-gated via `PaywallConfiguration`: the mock is the default everywhere; StoreKit
   activates only on explicit opt-in (`SELENE_COMMERCE=storekit` / `-commerce-storekit`).
   `App/Selene.storekit` defines both SKUs ($39.99/yr with 7-day free intro, $89.99 lifetime
   non-consumable) and is contract-tested against `ProductID` in `PaywallTests`. A
   StoreKitTest-backed sandbox E2E (`Packages/Paywall/StoreKitTests`, xcodebuild-only) buys both
   SKUs against the local config on the simulator.
3. **Gated insight surface** (closes the M2 surface gap): `GroundedAnswerService` is wired into
   the app — ask flow with suggestion chips, grounded answer cards, and citation chips resolving
   to exact pack sections (`CitationPresenter`). The surface renders ONLY when `FeatureGate`
   allows `.groundedQA`; free users get the Lunar Almanac paywall screen whose entire copy lives
   in `PaywallCopy` and passes a banned-medical-language scan (1.4.1). UI tests cover free →
   locked → mock trial purchase → unlocked, lifetime → ask → citation detail, and expired →
   locked again with the free tier untouched.
4. **Egress invariant extended**: `import StoreKit` joined the repo-guard banned tokens outside
   `Paywall/`; the no-egress flow suite now also runs the full mock commerce lifecycle (free →
   trial → gated Q&A → chips) under the armed URLProtocol tripwire.

Still open from the full M3 definition: the doctor-visit PDF artifact, the
perimenopause-specific onboarding funnel variant, and voice logging — each gates on surfaces
that don't exist yet, while their `Feature` gates (`.doctorVisitSummary`, `.voiceLogging`) are
already enforced and tested.

## Risks & mitigations (from the adversarial review)

1. **The privacy claim outruns reality** (iCloud backups Apple can decrypt, OS network paths,
   "airplane-mode demos don't prove future non-egress"). → Backup exclusion *by default*, ADP
   guidance in onboarding, zero third-party SDKs, CI-enforced no-network-outside-Paywall, and
   *published reproducible* audit procedure — make the skeptical user's own verification the
   marketing channel. One bad audit headline kills the company, so the audit runs on every release.
2. **3B model quality is weakest exactly where the paywall is**, incl. documented guardrail
   refusals on reproductive content. → The LLM never carries the headline feature: forecasts are
   deterministic Bayesian; insights are narration over engine numbers; Q&A is RAG-constrained to
   the pinned pack; every LLM surface has a deterministic template fallback so refusals degrade
   gracefully instead of erroring mid-fertility-question.
3. **Strip reading is calibration-sensitive and edges toward SaMD**; a wrong hCG read is
   catastrophic. → Dedicated trained CNN (not VLM), confidence-thresholded "unclear — retest"
   honesty, mandatory user confirmation, advisory-only framing with zero diagnosis language, and
   an eval gate that keeps the feature flagged off until accuracy clears the bar.
4. **Apple Sherlock risk + free substitutes** (Apple Cycle Tracking, Euki/Drip) compress the
   wedge. → Lead with what Apple won't build soon: perimenopause depth (symptom clusters,
   doctor-visit summary — the highest-value artifact for the 35–55 buyer), conversational grounded
   Q&A, and the lifetime SKU economics; keep `CycleEngine`/`SeleneCore` portable for the Android
   phase-2 market Apple can't touch.
5. **Distribution is the killer constraint** (reproductive-health ad targeting restricted, Flo
   owns ASO, privacy earns one press cycle). → Time launch PR to the Oct 29, 2026 final settlement
   hearing and claim-payout news cycle; run perimenopause as a separate ASO/landing funnel into the
   same SKU; keep manual logging free forever for rating volume; make the reproducible audit a
   recurring press artifact, not a one-off.
