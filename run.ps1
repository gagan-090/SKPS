# Run the app with the Supabase keys from .env (Windows / PowerShell).
#
#   .\run.ps1                  # debug run on the connected device
#   .\run.ps1 --release        # release run
#
# .env is git-ignored. Copy .env.example to .env first.

param([Parameter(ValueFromRemainingArguments = $true)] $Args)

Set-Location -Path $PSScriptRoot

if (-not (Test-Path .env)) {
    Write-Error "Missing .env - copy .env.example to .env and fill in your keys."
    exit 1
}

# --dart-define-from-file reads KEY=VALUE lines directly, so no secret ever
# appears on the command line or in a committed file.
flutter run --dart-define-from-file=.env @Args

# The equivalent explicit form, if you prefer passing values by hand:
#
#   flutter run `
#     --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co `
#     --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
