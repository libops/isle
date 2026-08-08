#!/usr/bin/env bash

set -euo pipefail

secrets_root="${SECRETS_ROOT:-./secrets}"
private_key="${secrets_root%/}/JWT_PRIVATE_KEY"
public_key="${secrets_root%/}/JWT_PUBLIC_KEY"
temporary_private=""
temporary_public=""

cleanup() {
  if [ -n "${temporary_private}" ]; then
    rm -f -- "${temporary_private}"
  fi
  if [ -n "${temporary_public}" ]; then
    rm -f -- "${temporary_public}"
  fi
}
interrupt() {
  exit 130
}
terminate() {
  exit 143
}
trap cleanup EXIT
trap interrupt INT
trap terminate HUP TERM

if [ -L "${secrets_root}" ] || [ -L "${private_key}" ] || [ -L "${public_key}" ]; then
  echo "Refusing to manage an Islandora JWT key through a symbolic link" >&2
  exit 1
fi
if { [ -e "${secrets_root}" ] && [ ! -d "${secrets_root}" ]; } ||
  { [ -e "${private_key}" ] && [ ! -f "${private_key}" ]; } ||
  { [ -e "${public_key}" ] && [ ! -f "${public_key}" ]; }; then
  echo "Islandora JWT key paths must be regular files inside a directory" >&2
  exit 1
fi

install -d -m 0700 -- "${secrets_root}"
umask 077

valid_private_key() {
  local modulus

  [ -s "${private_key}" ] || return 1
  openssl rsa -in "${private_key}" -check -noout >/dev/null 2>&1 || return 1
  modulus="$(openssl rsa -in "${private_key}" -modulus -noout 2>/dev/null)"
  modulus="${modulus#Modulus=}"
  if [ "${#modulus}" -gt 512 ]; then
    return 0
  fi
  [ "${#modulus}" -eq 512 ] || return 1
  case "${modulus:0:1}" in
    8|9|a|A|b|B|c|C|d|D|e|E|f|F) return 0 ;;
    *) return 1 ;;
  esac
}

if ! valid_private_key; then
  temporary_private="$(mktemp "${private_key}.tmp.XXXXXX")"
  openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:2048 \
    -out "${temporary_private}" \
    >/dev/null 2>&1
  chmod 0600 "${temporary_private}"
  mv -f -- "${temporary_private}" "${private_key}"
  temporary_private=""
fi
chmod 0600 "${private_key}"

temporary_public="$(mktemp "${public_key}.tmp.XXXXXX")"
openssl pkey \
  -in "${private_key}" \
  -pubout \
  -out "${temporary_public}" \
  >/dev/null 2>&1
chmod 0600 "${temporary_public}"

if [ -s "${public_key}" ] && cmp -s -- "${temporary_public}" "${public_key}"; then
  rm -f -- "${temporary_public}"
else
  mv -f -- "${temporary_public}" "${public_key}"
fi
temporary_public=""
chmod 0600 "${public_key}"
