#!/usr/bin/env bash

set -eou pipefail

echo "Updating from islandora-starter-site..."

# Track the release tag used by the buildkit Islandora image.
STARTER_SITE_VERSION="${STARTER_SITE_VERSION:-v1.11.0}"
STARTER_SITE_OWNER="${STARTER_SITE_OWNER:-Islandora}"

repo="https://github.com/${STARTER_SITE_OWNER}/islandora-starter-site"
ref="${STARTER_SITE_VERSION}"

DRUPAL_ROOT="drupal"
temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT

# Confirmation prompt if not in GitHub Actions
if [ "${GITHUB_ACTIONS:-}" == "" ]; then
  echo "This will refresh starter-site managed files in '${DRUPAL_ROOT}'."
  read -p "Do you want to continue? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled by user."
    exit 1
  fi
fi

echo "Initializing from starter site..."
curl -sL "${repo}/archive/${ref}.tar.gz" \
  | tar --strip-components=1 -C "${temp_dir}" -xz

mkdir -p "${DRUPAL_ROOT}"

for path in composer.json composer.lock assets config web/modules/custom/sample_core; do
  rm -rf "${DRUPAL_ROOT:?}/${path}"
  if [ -e "${temp_dir}/${path}" ]; then
    mkdir -p "$(dirname "${DRUPAL_ROOT}/${path}")"
    cp -a "${temp_dir}/${path}" "${DRUPAL_ROOT}/${path}"
  fi
done

mkdir -p "${DRUPAL_ROOT}/web/modules/custom" "${DRUPAL_ROOT}/web/themes/custom"
touch "${DRUPAL_ROOT}/web/modules/custom/.gitkeep" "${DRUPAL_ROOT}/web/themes/custom/.gitkeep"

echo "Update from islandora-starter-site complete."
