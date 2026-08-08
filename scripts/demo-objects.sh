#!/usr/bin/env bash

set -eou pipefail

site_url() {
  sitectl stats --path . --format json | jq -er '.ingress.public_url'
}

fcrepo_enabled() {
  docker compose config --services 2>/dev/null | grep -qx 'fcrepo'
}

container_url_for_url() {
  local url="$1"
  if fcrepo_enabled && [[ "${url}" =~ ^(https?)://(localhost|127\.0\.0\.1)(:[0-9]+)?(/.*)?$ ]]; then
    printf '%s://drupal.internal%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[4]}"
    return
  fi
  printf '%s\n' "${url}"
}

container_network_for_url() {
  local url="${1:?url is required}"
  local compose_project_name
  local traefik_container
  if [[ "${url}" =~ ^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?(/.*)?$ ]]; then
    traefik_container="$(docker compose ps -q traefik)"
    if [ -n "${traefik_container}" ]; then
      printf 'container:%s\n' "${traefik_container}"
      return
    fi
  fi
  compose_project_name="$(docker compose config --format json | jq -er '.name')"
  printf '%s_default\n' "${compose_project_name}"
}

if [ ! -d "islandora_workbench" ]; then
  git clone https://github.com/mjordan/islandora_workbench
fi

if [ ! -d "islandora_demo_objects" ]; then
  git clone https://github.com/Islandora-Devops/islandora_demo_objects islandora_demo_objects
fi

URL="${SITECTL_DEMO_OBJECTS_URL:-$(site_url)}"
WORKBENCH_URL="$(container_url_for_url "${URL}")"
NETWORK="$(container_network_for_url "${WORKBENCH_URL}")"

sed -i.bak \
  -e "s#^host.*#host: ${WORKBENCH_URL}/#g" \
  -e "s#^input_csv.*#input_csv: /islandora_demo_objects/create_islandora_objects.csv#g" \
  -e "s#^input_dir.*#input_dir: /islandora_demo_objects/#g" \
  -e '/password:/d' \
  islandora_demo_objects/create_islandora_objects.yml

docker build \
  --build-arg USER_ID="$(id -u)" \
  --build-arg GROUP_ID="$(id -u)" \
  -t workbench-docker:latest \
  islandora_workbench

# see if we should pass -i or -it to docker
# based on pseudo tty
tty_flag=( -i )
[ -t 0 ] && tty_flag=( -it )

set +e
docker run \
  "${tty_flag[@]}" \
  --rm \
  --env ISLANDORA_WORKBENCH_PASSWORD="$(cat secrets/DRUPAL_DEFAULT_ACCOUNT_PASSWORD)" \
  --network="${NETWORK}" \
  -v "$(pwd)/islandora_workbench":/workbench:z \
  -v "$(pwd)/islandora_demo_objects":/islandora_demo_objects:z \
  --name my-running-workbench \
  workbench-docker:latest \
  bash -lc "./workbench --config /islandora_demo_objects/create_islandora_objects.yml"
workbench_status=$?
set -e

if [ "${workbench_status}" -ne 0 ]; then
  printf 'Drupal media storage state:\n' >&2
  docker compose exec -T drupal /var/www/drupal/vendor/bin/drush php:eval '$scheme = \Drupal::config("field.storage.media.field_media_image")->get("settings.uri_scheme"); $wrappers = \Drupal::service("stream_wrapper_manager")->getWrappers(); $flysystem = \Drupal\Core\Site\Settings::get("flysystem", []); $private = \Drupal\Core\Site\Settings::get("file_private_path", ""); print json_encode(["scheme" => $scheme, "registered" => isset($wrappers[$scheme]), "fedora_configured" => isset($flysystem["fedora"]), "private_path_exists" => is_string($private) && is_dir($private), "private_path_writable" => is_string($private) && is_writable($private)]);' >&2 || true
  workbench_log="islandora_workbench/workbench.log"
  if [ -f "${workbench_log}" ]; then
    printf 'Workbench failed; last 80 log lines:\n' >&2
    tail -n 80 -- "${workbench_log}" >&2 || true
  fi
  exit "${workbench_status}"
fi
