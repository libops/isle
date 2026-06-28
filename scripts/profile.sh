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

# update .env variables
update_env() {
    local var="$1"
    local val="$2"
    if grep -Eq "^${var}=" .env; then
        sed -i "s/^$var=.*/$var=$val/" .env
    else
        echo "${var}=${val}" | tee -a .env
    fi
}

# --- Configuration Warnings ---
WARNINGS_FOUND=false
print_warning_header() {
    if [ "$WARNINGS_FOUND" = "false" ]; then
        echo_e "${RED}--- Configuration Warnings ---${RESET}"
        WARNINGS_FOUND=true
    fi
}

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null || false
}

# --- Environment Check ---
if [ -f .env ]; then
    # Use || true to prevent set -e from exiting if grep finds nothing
    DEVELOPMENT_ENVIRONMENT=$(grep '^DEVELOPMENT_ENVIRONMENT=' .env | cut -d'=' -f2 | tr -d '"' || echo "true")
    TLS_PROVIDER=$(grep '^TLS_PROVIDER=' .env | cut -d'=' -f2 | tr -d '"' || echo "self-managed")
    URI_SCHEME=$(grep '^URI_SCHEME=' .env | cut -d'=' -f2 | tr -d '"' || echo "http")
    ENABLE_ACME="false"
    if [ "${TLS_PROVIDER}" = "letsencrypt" ]; then
        ENABLE_ACME="true"
    fi
    ENABLE_HTTPS="false"
    if [ "${URI_SCHEME}" = "https" ]; then
        ENABLE_HTTPS="true"
    fi

    ACME_EMAIL=$(grep '^ACME_EMAIL=' .env | cut -d'=' -f2 | tr -d '"' || echo "postmaster@example.com")
    ACME_URL=$(grep '^ACME_URL=' .env | cut -d'=' -f2 | tr -d '"' || echo "https://acme-v02.api.letsencrypt.org/directory")
    DOMAIN=$(grep '^DOMAIN=' .env | cut -d'=' -f2 | tr -d '"' || echo "islandora.io")
    ISLANDORA_TAG=$(grep '^ISLANDORA_TAG=' .env | cut -d'=' -f2 | tr -d '"' || echo "main")
    TAG=$(grep '^TAG=' .env | cut -d'=' -f2 | tr -d '"' || echo "local")
    REPOSITORY=$(grep '^REPOSITORY=' .env | cut -d'=' -f2 | tr -d '"' || echo "islandora.io")
    COMPOSE_PROJECT_NAME=$(grep '^COMPOSE_PROJECT_NAME=' .env | cut -d'=' -f2 | tr -d '"' || echo "isle-site-template")
    # Export variables for use by sourcing scripts
    export DEVELOPMENT_ENVIRONMENT ENABLE_HTTPS URI_SCHEME ENABLE_ACME ACME_EMAIL ACME_URL DOMAIN ISLANDORA_TAG COMPOSE_PROJECT_NAME TAG REPOSITORY
else
  echo_e "  ${RED}.env file not found. Cannot determine configuration.${RESET}"
  echo "You should cp sample.env to .env"
  exit 1
fi

# --- Configuration Helper Functions ---

# Development mode for testing - set STATUS_DEV=true to force all warnings to show
status_dev() {
    [ "${STATUS_DEV:-false}" = "true" ]
}

is_docker_rootless() {
    status_dev || docker info -f "{{println .SecurityOptions}}" | grep -qi rootless
}

is_dev_mode() {
    status_dev || [ "${DEVELOPMENT_ENVIRONMENT:-}" = "true" ]
}

is_prod_mode() {
    status_dev || [ "${DEVELOPMENT_ENVIRONMENT:-}" = "false" ]
}

is_https_enabled() {
    status_dev || [ "${URI_SCHEME:-}" = "https" ]
}

is_acme_enabled() {
    status_dev || [ "${TLS_PROVIDER:-}" = "letsencrypt" ]
}

is_acme_using_default_email() {
    status_dev || [ "${ACME_EMAIL:-}" = "postmaster@example.com" ]
}

is_tls_http_uri_mismatch() {
    status_dev || { is_https_enabled && [ "${URI_SCHEME:-}" = "http" ]; }
}

is_http_tls_uri_mismatch() {
    status_dev || { ! is_https_enabled && [ "${URI_SCHEME:-}" = "https" ]; }
}

has_no_docker_override() {
    status_dev || { [ ! -f docker-compose.override.yml ] && [ ! -L docker-compose.override.yml ] && [ ! -f docker-compose.override.yaml ] && [ ! -L docker-compose.override.yaml ]; }
}

# Set HTTPS with sed
set_https() {
  local enable=$1

  if [ "$enable" = "true" ]; then
    sed -i.bak 's/^DRUPAL_ENABLE_HTTPS:.*/DRUPAL_ENABLE_HTTPS: "true"/' docker-compose.yml && rm -f docker-compose.yml.bak
  else
    sed -i.bak 's/^DRUPAL_ENABLE_HTTPS:.*/DRUPAL_ENABLE_HTTPS: "false"/' docker-compose.yml && rm -f docker-compose.yml.bak
  fi
}

# Function to set Let's Encrypt config
set_letsencrypt_config() {
  local enable=$1

  update_env TLS_PROVIDER '"self-managed"'
  sed -i.bak '/--certificatesresolvers.letsencrypt.acme/d' docker-compose.yml && rm -f docker-compose.yml.bak
  sed -i.bak '/--entrypoints.https.http.tls.certResolver/d' docker-compose.yml && rm -f docker-compose.yml.bak

  if [ "$enable" = "true" ]; then
    update_env TLS_PROVIDER '"letsencrypt"'
    update_env URI_SCHEME '"https"'

    # shellcheck disable=SC2016
    sed -i.bak '/command: >-/a\
      --entrypoints.https.http.tls.certResolver=letsencrypt\
      --certificatesresolvers.letsencrypt.acme.httpchallenge=true\
      --certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=http\
      --certificatesresolvers.letsencrypt.acme.storage=/acme/acme.json\
      --certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}\
      --certificatesresolvers.letsencrypt.acme.caserver=${ACME_URL}
' docker-compose.yml && rm -f docker-compose.yml.bak
  fi
}
