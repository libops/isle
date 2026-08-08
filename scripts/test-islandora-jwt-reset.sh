#!/usr/bin/env bash

set -euo pipefail

private_key="secrets/JWT_PRIVATE_KEY"
public_key="secrets/JWT_PUBLIC_KEY"
derived_public=""

cleanup() {
  if [ -n "${derived_public}" ]; then
    rm -f -- "${derived_public}"
  fi
}
trap cleanup EXIT

run_init() {
  docker compose run --rm \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    init
}

verify_keypair() {
  local modulus

  [ "$(stat -c '%a' "${private_key}")" = "600" ]
  [ "$(stat -c '%a' "${public_key}")" = "600" ]
  openssl rsa -in "${private_key}" -check -noout >/dev/null 2>&1
  modulus="$(openssl rsa -in "${private_key}" -modulus -noout 2>/dev/null)"
  modulus="${modulus#Modulus=}"
  if [ "${#modulus}" -eq 512 ]; then
    case "${modulus:0:1}" in
      8|9|a|A|b|B|c|C|d|D|e|E|f|F) ;;
      *) return 1 ;;
    esac
  else
    [ "${#modulus}" -gt 512 ]
  fi

  derived_public="$(mktemp)"
  openssl pkey -in "${private_key}" -pubout -out "${derived_public}" >/dev/null 2>&1
  cmp -s -- "${derived_public}" "${public_key}"
  rm -f -- "${derived_public}"
  derived_public=""
}

run_init
verify_keypair
read -r original_private_checksum _ < <(sha256sum "${private_key}")

printf 'invalid public key\n' >"${public_key}"
run_init
verify_keypair
read -r repaired_public_private_checksum _ < <(sha256sum "${private_key}")
[ "${repaired_public_private_checksum}" = "${original_private_checksum}" ]

printf 'invalid private key\n' >"${private_key}"
run_init
verify_keypair
read -r repaired_private_checksum _ < <(sha256sum "${private_key}")
[ "${repaired_private_checksum}" != "${original_private_checksum}" ]

rm -f -- "${public_key}"
mkdir -- "${public_key}"
if run_init; then
  echo "JWT initialization accepted a public-key directory" >&2
  exit 1
fi
rmdir -- "${public_key}"
run_init
verify_keypair

rm -f -- "${private_key}"
mkdir -- "${private_key}"
if run_init; then
  echo "JWT initialization accepted a private-key directory" >&2
  exit 1
fi
rmdir -- "${private_key}"
run_init
verify_keypair
