#!/usr/bin/env bash

set -euo pipefail

require_regular_file() {
  local path="$1"

  if [ ! -f "${path}" ] || [ -L "${path}" ]; then
    echo "Required ISLE template file is missing or unsafe: ${path}" >&2
    exit 1
  fi
}

require_regular_file "${BASH_SOURCE[0]}"
require_regular_file compose.yaml
require_regular_file scripts/ensure-islandora-jwt-keypair.sh
require_regular_file scripts/initialize-compose.sh

if [ -L .env ] || { [ -e .env ] && [ ! -f .env ]; }; then
  echo "ISLE environment path must be a regular file, not a directory or symbolic link: .env" >&2
  exit 1
fi
if [ ! -e .env ]; then
  install -m 0600 /dev/null .env
fi
if ! grep -q '^DRUPAL_HEALTHCHECK_START_PERIOD=' .env; then
  printf '\nDRUPAL_HEALTHCHECK_START_PERIOD=5m\n' >>.env
fi

mkdir -p ./certs ./secrets
