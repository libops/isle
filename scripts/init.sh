#!/usr/bin/env bash

set -eou pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/profile.sh"

if is_dev_mode && is_docker_rootless; then
  echo "Development mode is not supported on rootless docker."
  echo "Set DEVELOPMENT_ENVIRONMENT=false in the compose service environment."
  exit 1
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
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
      sudo chown -R "${host_uid}:${host_gid}" ./certs ./secrets
    else
      echo "Could not change certs/secrets ownership without sudo; continuing after container-side ownership fix." >&2
    fi
  fi
fi

mkdir -p ./certs
id -u > ./certs/UID
if [ -d drupal/rootfs ]; then
  find drupal/rootfs -type d -exec chmod 755 {} \;
fi
