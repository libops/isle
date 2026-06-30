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

site_url() {
    sitectl stats --path . --format json | jq -er '.ingress.public_url'
}

container_network_for_url() {
    local url traefik_container
    url="$1"
    if [[ "${url}" =~ ^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?(/.*)?$ ]]; then
        traefik_container="$(docker compose ps -q traefik)"
        if [ -z "${traefik_container}" ]; then
            echo "Unable to find the running Traefik container for ${url}" >&2
            return 1
        fi
        printf 'container:%s\n' "${traefik_container}"
        return
    fi
    printf '%s_default\n' "${COMPOSE_PROJECT_NAME}"
}
