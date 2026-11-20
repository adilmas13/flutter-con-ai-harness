#!/usr/bin/env bash
# Runs the demo on macOS with the API key from .env. The key stays in .env, which git ignores.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || printf 'ANTHROPIC_API_KEY=\n' > .env
exec flutter run -d macos \
  --dart-define-from-file=.env \
  --dart-define=PROJECT_DIR="$PWD" "$@"
