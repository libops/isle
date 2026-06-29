#!/usr/bin/env bash

set -eou pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/profile.sh"

if is_dev_mode && is_docker_rootless; then
  echo "Development mode is not supported on rootless docker."
  echo "Set DEVELOPMENT_ENVIRONMENT=false in the compose service environment."
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

docker compose run --rm init

chown -R "$(whoami)" ./certs ./secrets > /dev/null 2>&1 || sudo chown -R "$(whoami)" ./certs ./secrets > /dev/null 2>&1 || true

mkdir -p ./certs
id -u > ./certs/UID
if [ -d drupal/rootfs ]; then
  find drupal/rootfs -type d -exec chmod 755 {} \;
fi
docker compose pull --ignore-buildable --ignore-pull-failures
docker compose build
