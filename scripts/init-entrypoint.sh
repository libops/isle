#!/usr/bin/env bash

set -eou pipefail

pushd /

./scripts/generate-certs.sh
./scripts/generate-secrets.sh

if [ -n "${HOST_UID:-}" ]; then
  chown -R "${HOST_UID}:${HOST_GID:-${HOST_UID}}" /certs /secrets || \
    echo "Could not change certs/secrets ownership; continuing with generated files." >&2
fi
