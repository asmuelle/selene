# Selene — on-device cycle & perimenopause tracker (iOS-first).
# Single source of truth for commands; agents and humans use these, never raw xcodebuild.

app := "Selene"
preferred_simulator := "iPhone 16"

# List available recipes
default:
    @just --list

# Resolve the simulator to use: the preferred device, else iPhone 17 Pro, else
# the first available iPhone on this machine.
[private]
_sim:
    @list=$(xcrun simctl list devices available | sed -n 's/^ *\(iPhone[^(]*\)(.*$/\1/p' | sed 's/ *$//' | sort -u); \
    for name in "{{ preferred_simulator }}" "iPhone 17 Pro"; do \
        if printf '%s\n' "$list" | grep -qx "$name"; then printf '%s\n' "$name"; exit 0; fi; \
    done; \
    fallback=$(printf '%s\n' "$list" | head -n 1); \
    if [ -z "$fallback" ]; then echo "error: no available iPhone simulator found" >&2; exit 1; fi; \
    printf '%s\n' "$fallback"

# Generate the Xcode project via XcodeGen and resolve SPM dependencies
bootstrap:
    @command -v xcodegen >/dev/null 2>&1 || { echo "error: xcodegen not installed — brew install xcodegen"; exit 1; }
    @if [ ! -f project.yml ]; then \
        echo "error: project.yml not found — the app shell has not been scaffolded yet (milestone M0)."; \
        echo "Create project.yml (XcodeGen spec, app target '{{ app }}') and the SPM packages from DESIGN.md,"; \
        echo "then re-run 'just bootstrap'."; \
        exit 1; \
    fi
    xcodegen generate
    xcodebuild -resolvePackageDependencies -project {{ app }}.xcodeproj -scheme {{ app }}

# Build the app for the iOS Simulator
build:
    @if [ ! -d {{ app }}.xcodeproj ]; then \
        echo "error: {{ app }}.xcodeproj missing — run 'just bootstrap' first (needs project.yml; see DESIGN.md M0)."; \
        exit 1; \
    fi
    @sim="$(just _sim)"; set -x; xcodebuild build -project {{ app }}.xcodeproj -scheme {{ app }} \
        -destination "platform=iOS Simulator,name=$sim" \
        CODE_SIGNING_ALLOWED=NO

# Run the test suite: SPM core suite on macOS, then the app suite on the simulator.
# StoreKit's SKTestSession does not load products on headless CI runners, so the
# StoreKitSandboxTests E2E suite is skipped on CI (GITHUB_ACTIONS) and runs locally only.
test:
    swift test
    @if [ ! -d {{ app }}.xcodeproj ]; then \
        echo "error: {{ app }}.xcodeproj missing — run 'just bootstrap' first (needs project.yml; see DESIGN.md M0)."; \
        exit 1; \
    fi
    @sim="$(just _sim)"; \
        skip=""; [ -n "${GITHUB_ACTIONS:-}" ] && skip="-skip-testing:PaywallStoreKitTests/StoreKitSandboxTests"; \
        set -x; xcodebuild test -project {{ app }}.xcodeproj -scheme {{ app }} \
        -destination "platform=iOS Simulator,name=$sim" \
        $skip \
        CODE_SIGNING_ALLOWED=NO

# Lint Swift sources with SwiftLint (skips with a notice when swiftlint is absent)
lint:
    @if [ ! -f project.yml ]; then \
        echo "error: project not bootstrapped (no project.yml) — nothing to lint yet; see DESIGN.md M0."; \
        exit 1; \
    fi
    @if command -v swiftlint >/dev/null 2>&1; then \
        swiftlint; \
    else \
        echo "notice: swiftlint not installed — skipping lint (brew install swiftlint to enable)."; \
    fi

# Format Swift sources in place with swiftformat
format:
    @command -v swiftformat >/dev/null 2>&1 || { echo "error: swiftformat not installed — brew install swiftformat"; exit 1; }
    swiftformat .

# verify formatting (swiftformat --lint); CI gate
format-check:
    swiftformat --lint .

# Full local gate: lint + build + test (same as CI)
ci: lint build test format-check
