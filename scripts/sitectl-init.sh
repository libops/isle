#!/usr/bin/env bash

set -euo pipefail

if [ ! -f .env ]; then
  cp sample.env .env
fi
if ! grep -q '^DRUPAL_HEALTHCHECK_START_PERIOD=' .env; then
  printf '\nDRUPAL_HEALTHCHECK_START_PERIOD=5m\n' >>.env
fi

mkdir -p ./certs ./secrets

attempt=1
until docker compose run --rm \
  -e HOST_UID="$(id -u)" \
  -e HOST_GID="$(id -g)" \
  init; do
  if [ "${attempt}" -ge 3 ]; then
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 5
done
