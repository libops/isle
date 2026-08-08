#!/usr/bin/env bash

set -euo pipefail

generate-certs.sh
generate-compose-secrets.sh
