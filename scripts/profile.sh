#!/usr/bin/env bash

set -euf -o pipefail

RESET=$(tput sgr0)
RED=$(tput setaf 9)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 6)
YELLOW=$(tput setaf 3)
readonly RESET RED GREEN BLUE YELLOW
# Export color codes for use by sourcing scripts
export RESET RED GREEN BLUE YELLOW

# Alias for echo -e to avoid shellcheck warnings about printf format strings
# shellcheck disable=SC2039,SC3044
echo_e() {
    echo -e "$@"
}

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null || false
}

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-isle-site-template}"
DEVELOPMENT_ENVIRONMENT="${DEVELOPMENT_ENVIRONMENT:-false}"
export COMPOSE_PROJECT_NAME DEVELOPMENT_ENVIRONMENT

status_dev() {
    [ "${STATUS_DEV:-false}" = "true" ]
}

is_docker_rootless() {
    status_dev || docker info -f "{{println .SecurityOptions}}" | grep -qi rootless
}

is_dev_mode() {
    status_dev || [ "${DEVELOPMENT_ENVIRONMENT:-}" = "true" ]
}

compose_env_value() {
    local service="$1"
    local key="$2"

    docker compose config 2>/dev/null | awk -v service="${service}:" -v key="${key}:" '
        $1 == service { in_service=1; in_env=0; next }
        in_service && /^[[:space:]]{2}[[:alnum:]_-]+:/ && $1 != service { in_service=0; in_env=0 }
        in_service && $1 == "environment:" { in_env=1; next }
        in_service && in_env && $1 == key {
            sub("^[[:space:]]*" key "[[:space:]]*", "")
            gsub(/^"|"$/, "")
            print
            exit
        }
    '
}

site_url() {
    local configured="${SITE_URL:-}"

    if [ -z "$configured" ]; then
        configured="$(compose_env_value drupal DRUPAL_DEFAULT_SITE_URL || true)"
    fi

    printf '%s\n' "${configured:-http://localhost}"
}
