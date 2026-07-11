#!/usr/bin/env bash

set -eou pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/profile.sh"

docker compose up --remove-orphans --wait --wait-timeout "${COMPOSE_WAIT_TIMEOUT:-900}"

URL="$(site_url)"

MAX_RETRIES="${POST_INSTALL_MAX_RETRIES:-12}" ./scripts/ping.sh > /dev/null 2>&1

echo "---------------------------------------------------"
echo "🚀 Site available at: $URL"
echo "---------------------------------------------------"

# don't open the URL if we're in GHA
if [ "${GITHUB_ACTIONS:-}" != "" ]; then
  exit 0
fi

# don't open the URL if we're in an SSH session
if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ]; then
  exit 0
fi

# 6. Open in Browser (Cross-Platform)
case "$(uname -s)" in
    Darwin*)    open "$URL" ;;
    Linux*)     if grep -qi microsoft /proc/version; then
                    powershell.exe Start-Process "$URL" # WSL
                else
                    xdg-open "$URL" # Standard Linux
                fi ;;
    CYGWIN*|MINGW*|MSYS*) start "$URL" ;; # Windows Native
    *)          echo "You can open $URL in your browser." ;;
esac
