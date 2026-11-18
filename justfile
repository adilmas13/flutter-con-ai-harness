# Day Planner: every project command is a recipe. Run `just` to list them.

set dotenv-load := false

# List the recipes
default:
    @just --list --unsorted

# Fetch packages
deps:
    flutter pub get

# Regenerate MobX code after changing a store
gen:
    dart run build_runner build --delete-conflicting-outputs

# Static analysis
analyze:
    flutter analyze

# Unit and widget tests
test:
    flutter test

# Analyze and test: run before every commit
check: analyze test

# Run the app on macOS with the key from .env (live calls, recordings saved here)
run *args:
    tool/run.sh {{args}}

# Build the macOS app (debug) without running it
build:
    flutter build macos --debug --dart-define-from-file=.env --dart-define=PROJECT_DIR="{{justfile_directory()}}"

# Release build for the stage: run after the final recordings, then open it with `just open-release`
release:
    flutter build macos --release --dart-define-from-file=.env --dart-define=PROJECT_DIR="{{justfile_directory()}}"

# Launch the release build
open-release:
    open build/macos/Build/Products/Release/day_planner.app

# Launch the last debug build without the debugger
open:
    open build/macos/Build/Products/Debug/day_planner.app

# Format the Dart code
fmt:
    dart format lib test

# Show which recordings are saved
recordings:
    @python3 -c "import json;d=json.load(open('recordings/recordings.json'))['recordings'];print('\n'.join(sorted(d)) or 'No recordings yet.');print(f'{len(d)} saved')"

# Remove build output
clean:
    flutter clean

# Commit all changes with a Conventional Commit message, e.g. "feat(agent): add retry" (never includes .env)
commit message:
    @printf '%s' "{{message}}" | grep -qE '^(feat|fix|docs|test|refactor|chore|build|ci|perf|style)(\([a-z0-9-]+\))?!?: [^ ].{0,70}$' || { echo 'Not a Conventional Commit. Use: type(scope): summary (see .agents/skills/phase-complete)'; exit 1; }
    git add -A
    @git diff --cached --name-only | grep -qxE '(.*/)?\.env' && { echo ".env is staged, aborting"; exit 1; } || true
    git commit -m "{{message}}"

# Push the current branch to origin
push:
    git push -u origin HEAD
