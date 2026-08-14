#!/usr/bin/env bash
# Run the app with the Supabase keys from .env.
#
#   ./run.sh              # debug run on the connected device
#   ./run.sh --release    # release run
#
# .env is git-ignored. Copy .env.example to .env first.

set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Missing .env — copy .env.example to .env and fill in your keys." >&2
  exit 1
fi

# --dart-define-from-file reads KEY=VALUE lines directly, so no secret ever
# appears on the command line or in a committed file.
exec flutter run --dart-define-from-file=.env "$@"

# The equivalent explicit form, if you prefer passing values by hand:
#
#   flutter run \
#     --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
#     --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
