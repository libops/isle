#!/usr/bin/env bash

set -euo pipefail

require_regular_file() {
  local path="$1"

  if [ ! -f "${path}" ] || [ -L "${path}" ]; then
    echo "This checkout is missing a required ISLE template file (${path}); migrate it to template v1.3.0 or newer before deploying" >&2
    exit 1
  fi
}

require_regular_file "${BASH_SOURCE[0]}"
require_regular_file compose.yaml
require_regular_file certs/rootCA.pem
require_regular_file conf/triplet/config.yaml
require_regular_file scripts/drupal-media-storage-state.php
require_regular_file scripts/drupal-wait-installed.sh
require_regular_file scripts/ensure-islandora-jwt-keypair.sh
require_regular_file scripts/initialize-compose.sh
