#!/usr/bin/env bash

set -euo pipefail

if [ -d drupal/rootfs ]; then
  find drupal/rootfs -type d -exec chmod 755 {} +
fi

docker compose pull --ignore-buildable --ignore-pull-failures
docker compose build
