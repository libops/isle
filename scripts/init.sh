#!/usr/bin/env bash

set -eou pipefail

extend_healthcheck=false
if [ ! -f .env ]; then
  cp sample.env .env
  extend_healthcheck=true
fi

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/profile.sh"

if $extend_healthcheck; then
  # we've detected an initial install
  # so extend the default start period for drupal's healthcheck to 1m
  # so it has time to come online before docker compose marks it unhealthy
  update_env DRUPAL_HEALTHCHECK_RETRIES 10
  update_env DRUPAL_HEALTHCHECK_START_PERIOD 1m
fi

if is_dev_mode && is_docker_rootless; then
  echo "Development mode is not supported on rootless docker."
  echo "You must set DEVELOPMENT_ENVIRONMENT=false in .env"
  exit 0
fi

# For SELinux if applicable.
if command -v "sestatus" >/dev/null; then
  if sestatus | grep -q "SELinux status: *enabled"; then
    if command -v "chcon" >/dev/null; then
      PROGDIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd | xargs dirname)"
      sudo chcon -R -t container_file_t "${PROGDIR}/secrets" || true
      sudo chcon -R -t container_file_t "${PROGDIR}/certs" || true
    fi
  fi
fi

host_uid="$(id -u)"
host_gid="$(id -g)"

docker compose run --rm \
  -e HOST_UID="${host_uid}" \
  -e HOST_GID="${host_gid}" \
  init

if [ "${host_uid}" -eq 0 ]; then
  chown -R "${host_uid}:${host_gid}" ./certs ./secrets
else
  unowned_path="$(find ./certs ./secrets ! -user "${host_uid}" -print -quit)"
  if [ -n "${unowned_path}" ]; then
    if command -v sudo > /dev/null 2>&1 && sudo -n true 2> /dev/null; then
      sudo chown -R "${host_uid}:${host_gid}" ./certs ./secrets
    else
      echo "Could not change certs/secrets ownership without sudo; continuing after container-side ownership fix." >&2
    fi
  fi
fi

make build
