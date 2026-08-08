#!/usr/bin/env bash

set -euo pipefail

generate-certs.sh
bash /usr/local/lib/sitectl/ensure-islandora-jwt-keypair.sh
generate-compose-secrets.sh
