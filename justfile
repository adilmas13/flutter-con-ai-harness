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

# Live smoke test against Claude (uses the key in .env; costs a few cents)
live-smoke:
    flutter test test/live --run-skipped --dart-define-from-file=.env --reporter expanded

# Scrape the agenda from india.fluttercon.dev's data feed and regenerate the schedule files
scrape:
    python3 -I tool/scrape_agenda.py

# Copy the compact schedule (titles, times, rooms, speakers) to the clipboard, for pasting at levels 1–2
paste-schedule:
    pbcopy < assets/schedule_paste.txt
    @echo "Schedule copied to the clipboard ($(wc -l < assets/schedule_paste.txt | tr -d ' ') lines)."

# Run experiments live and write each run to build/live_runs/ for review (filter: just run-live L3/vague)
run-live filter="":
    flutter test test/live/run_experiments_test.dart --run-skipped --dart-define-from-file=.env --dart-define=ONLY="{{filter}}" --reporter expanded

# The whole talk live as one accumulating conversation; transcript in build/live_flow.md
live-flow:
    flutter test test/live/flow_test.dart --run-skipped --dart-define-from-file=.env --reporter expanded

# Save reviewed live runs into recordings/recordings.json (e.g. just promote L2/follow-up/with, or all)
promote +runs:
    python3 -I tool/promote_runs.py {{runs}}

# Replay every recorded experiment offline and confirm it matches the live run
verify-replay:
    flutter test test/replay_test.dart --reporter expanded

# Replay every recorded experiment in the real window and screenshot each to build/screens/
screens:
    rm -rf build/screens
    flutter build macos --debug --dart-define-from-file=.env --dart-define=PROJECT_DIR="{{justfile_directory()}}" --dart-define=AUTOPILOT=true
    build/macos/Build/Products/Debug/day_planner.app/Contents/MacOS/day_planner
    @ls build/screens | wc -l | xargs echo "screenshots:"
    flutter build macos --debug --dart-define-from-file=.env --dart-define=PROJECT_DIR="{{justfile_directory()}}"

# The whole talk live in the real window, driven like a presenter; screenshots and transcript in build/stage/ (until=3 stops after level 3)
stage-run until="0":
    flutter build macos --debug --dart-define-from-file=.env --dart-define=PROJECT_DIR="{{justfile_directory()}}" --dart-define=AUTOPILOT=true --dart-define=AUTOPILOT_LIVE=true --dart-define=AUTOPILOT_UNTIL={{until}}
    build/macos/Build/Products/Debug/day_planner.app/Contents/MacOS/day_planner
    @ls build/stage | wc -l | xargs echo "files in build/stage:"

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
