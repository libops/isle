#!/usr/bin/env bash

set -euo pipefail

docker compose config --quiet
docker compose pull --ignore-buildable --ignore-pull-failures
docker compose build --pull drupal
docker compose run --rm -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" init
docker compose up --remove-orphans --wait --wait-timeout "${COMPOSE_WAIT_TIMEOUT:-900}" -d
sitectl healthcheck --persist --timeout "${SITECTL_HEALTHCHECK_TIMEOUT:-10m}"
sitectl verify --strict
