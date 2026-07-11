#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

PROGDIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
readonly PROGDIR

CERT_DIR="${PROGDIR}/certs"
CA_KEY="${CERT_DIR}/rootCA-key.pem"
CA_CERT="${CERT_DIR}/rootCA.pem"
LEAF_KEY="${CERT_DIR}/privkey.pem"
LEAF_CERT="${CERT_DIR}/cert.pem"
readonly CERT_DIR CA_KEY CA_CERT LEAF_KEY LEAF_CERT

readonly CA_SUBJECT='/CN=LibOps ISLE Local Development CA'
readonly LEAF_SUBJECT='/CN=localhost'
readonly SUBJECT_ALT_NAMES='DNS:*.islandora.io,DNS:islandora.io,DNS:*.islandora.info,DNS:islandora.info,DNS:localhost,IP:127.0.0.1,IP:::1'

install -d -m 0700 "${CERT_DIR}"

if [ -s "${CA_CERT}" ] && [ ! -s "${CA_KEY}" ]; then
  echo "Certificate authority key is missing for existing ${CA_CERT}" >&2
  exit 1
fi

if [ ! -s "${CA_KEY}" ]; then
  echo "Creating: ${CA_KEY}" >&2
  umask 077
  openssl genrsa -out "${CA_KEY}" 4096
fi
chmod 0600 "${CA_KEY}"

if [ ! -s "${CA_CERT}" ]; then
  echo "Creating: ${CA_CERT}" >&2
  openssl req -x509 -new -sha256 \
    -key "${CA_KEY}" \
    -out "${CA_CERT}" \
    -days 3650 \
    -subj "${CA_SUBJECT}" \
    -addext 'subjectKeyIdentifier=hash' \
    -addext 'authorityKeyIdentifier=keyid:always,issuer' \
    -addext 'basicConstraints=critical,CA:TRUE' \
    -addext 'keyUsage=critical,keyCertSign,cRLSign'
fi
chmod 0644 "${CA_CERT}"

if [ -s "${LEAF_CERT}" ] && [ ! -s "${LEAF_KEY}" ]; then
  echo "Private key is missing for existing ${LEAF_CERT}" >&2
  exit 1
fi

if [ ! -s "${LEAF_KEY}" ]; then
  echo "Creating: ${LEAF_KEY}" >&2
  umask 077
  openssl genrsa -out "${LEAF_KEY}" 2048
fi
chmod 0600 "${LEAF_KEY}"

if [ ! -s "${LEAF_CERT}" ]; then
  echo "Creating: ${LEAF_CERT}" >&2
  workdir="$(mktemp -d)"
  trap 'rm -rf "${workdir}"' EXIT

  openssl req -new -sha256 \
    -key "${LEAF_KEY}" \
    -out "${workdir}/leaf.csr" \
    -subj "${LEAF_SUBJECT}"

  cat >"${workdir}/leaf.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=${SUBJECT_ALT_NAMES}
EOF

  openssl x509 -req -sha256 \
    -in "${workdir}/leaf.csr" \
    -CA "${CA_CERT}" \
    -CAkey "${CA_KEY}" \
    -set_serial "0x$(openssl rand -hex 16)" \
    -out "${LEAF_CERT}" \
    -days 825 \
    -extfile "${workdir}/leaf.ext"
fi
chmod 0644 "${LEAF_CERT}"

echo "Development certificates are ready in ${CERT_DIR}."
