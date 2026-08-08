# LibOps ISLE Template

The LibOps ISLE Template is a fork of [ISLE Site Template](https://github.com/Islandora-Devops/isle-site-template) that's been customized using [`sitectl-isle`](https://github.com/libops/sitectl-isle) components. It includes Drupal, Traefik, MariaDB, Solr, ActiveMQ, Alpaca, and LibOps derivative services.

Docs:

- [Managed application architecture](https://sitectl.libops.io/apps)
- [ISLE sitectl plugin](https://sitectl.libops.io/plugins/isle)

## Requirements

- [sitectl](https://sitectl.libops.io/install) installed on the host that will run the site.
- [`sitectl-isle`](https://github.com/libops/sitectl-isle) installed for ISLE create, validation, healthcheck, and helper commands.
- [`sitectl-drupal`](https://github.com/libops/sitectl-drupal) installed because ISLE includes the Drupal plugin surface.
- Docker with the Compose v2 plugin installed on the same host.

## Quick start

Create a new ISLE site from this template:

```bash
sitectl create isle/default \
  --template-repo https://github.com/libops/isle \
  --path ./my-isle-site \
  --type local \
  --checkout-source template \
  --default-context
```

The site is served through Traefik at `http://localhost` by default.

## Local image build

The `drupal` service builds this checkout on top of the LibOps Islandora base image. The Dockerfile copies Composer lockfiles and assets before local recipes, modules, themes, config, and rootfs additions so Docker can reuse dependency layers when only site customizations change. During `sitectl create`, initialization prepares secrets, certificates, ownership, and rootfs permissions; the normal create build phase then builds the image once. Local builds use the platform selected by the Docker CLI and do not push images.

The lifecycle programs in `scripts/` are part of the versioned template contract with `sitectl-isle`. They keep build, initialization, readiness, and container-side diagnostics reviewable as files and are mounted read-only when a container needs them. Preserve their paths when maintaining an institution-specific fork.

Docker Compose derives the project name from the checkout directory, so independent forks do not share containers, networks, or named volumes by default. Set `COMPOSE_PROJECT_NAME` explicitly when a stable name is required. If an existing checkout previously relied on this template's fixed `isle-site-template` project name, set `COMPOSE_PROJECT_NAME=isle-site-template` before starting it to keep using its existing named volumes, or migrate those volumes deliberately.

## Basic Operations

Run these from the generated checkout, or add `--context <name>` when operating from elsewhere.

Start or update the stack with [`sitectl compose`](https://sitectl.libops.io/commands/compose):

```bash
sitectl compose up --remove-orphans -d
```

Check the site and context configuration with [`sitectl healthcheck`](https://sitectl.libops.io/commands/healthcheck) and [`sitectl validate`](https://sitectl.libops.io/commands/validate):

```bash
sitectl healthcheck
sitectl validate
```

Update the application base tag or pin that base by digest with [`sitectl image`](https://sitectl.libops.io/commands/image):

```bash
sitectl image set --tag drupal=nginx-1.30.4-php84 --tag solr=9 --tag alpaca=2.4
sitectl image set --build-arg drupal.BASE_IMAGE=libops/islandora:nginx-1.30.4-php84@sha256:0320df015cab9951ff0ba1e5f30c0a18641398706c3af6fe9d27c29f02b21d2e
```

Enable local development bind mounts with [`sitectl set`](https://sitectl.libops.io/commands/set):

```bash
sitectl set dev-mode enabled
```

Publish a domain, switch HTTP/TLS mode, configure Let's Encrypt, trust upstream proxies, or tune upload limits with the `ingress` component:

```bash
sitectl set ingress enabled --mode https-custom --domain islandora.localhost
sitectl set ingress enabled --mode https-letsencrypt --domain islandora.example.org --acme-email ops@example.org
sitectl set ingress enabled --trusted-ip 203.0.113.10/32 --max-upload-size 2G --upload-timeout 10m
```

`sitectl set` applies the requested component change immediately. Use `sitectl converge` when you want an interactive review of the complete component state.

The ingress component writes `INGRESS_HOSTNAMES` as comma-separated hostnames and `INGRESS_SCHEME` as `http` or `https` into the app container. Runtime config is rendered from those values during container startup, so generated sites should not carry separate app URL env vars for the same public route.

Enable ISLE bot mitigation with [`sitectl set`](https://sitectl.libops.io/commands/set):

```bash
sitectl set bot-mitigation on
```

See the [ISLE sitectl plugin docs](https://sitectl.libops.io/plugins/isle) for Fedora, Blazegraph, IIIF, derivative microservices, cache, sync, migration, ingress, and bot mitigation details.

## Makefile

The Makefile is intentionally small. It only keeps ISLE-specific targets that are not core sitectl operations:

```bash
make demo-objects
make sync-solr-conf
make create-starter-site-pr
make clean
```

Use `sitectl compose ...` and `sitectl set ...` directly for normal stack operations.

## Template notes

This template starts from the upstream [ISLE Site Template](https://github.com/Islandora-Devops/isle-site-template) and applies LibOps defaults:

- Drupal codebase at the repository root.
- Fedora replaced with Drupal private files by default.
- Blazegraph removed by default.
- Cantaloupe replaced with Triplet.
- LibOps images for the application services.

Only MariaDB and the one-shot `database-init` service receive `DB_ROOT_PASSWORD`. The initializer idempotently creates the Drupal database and scoped user before the app starts; the long-running Drupal service receives only `DRUPAL_DEFAULT_DB_PASSWORD` as `DB_PASSWORD`. Optional components that need their own database follow the same scoped-credential boundary. Initialization also generates the dormant `TOMCAT_ADMIN_PASSWORD` credential so enabling Fedora later never falls back to a baked-in default.

ActiveMQ, Alpaca, and Drupal share the generated `ACTIVEMQ_PASSWORD` through service-specific secret targets. Drupal receives it as `DRUPAL_DEFAULT_BROKER_PASSWORD` together with the non-secret `admin` broker username, so the rendered Islandora settings use authenticated STOMP rather than relying on a broker default.

## Full-state recovery

The ISLE plugin exposes the authoritative-versus-rebuildable recovery contract and creates a single checksummed bundle:

```bash
sitectl isle recovery plan
sitectl isle recovery backup --output /var/backups/isle/site-$(date +%F).tar.gz
sitectl isle recovery validate --input /var/backups/isle/site-2026-08-07.tar.gz
```

The bundle contains the Drupal database and public/private files, plus the Fcrepo database and object data when Fcrepo is enabled. It deliberately excludes customer secrets, source-controlled project configuration, Solr and Blazegraph indexes, ActiveMQ queues, IIIF caches, and generated derivatives. Recreate the target from the matching site Git revision and template provenance lock, restore secrets from the organization's Vault backup, and rebuild the excluded derived state after restore. The target and bundle must agree on whether Fedora is enabled.

Copy bundles to encrypted off-host storage with retention that meets the customer's documented RPO. At least quarterly, restore a selected bundle into a disposable context, run `sitectl healthcheck` and `sitectl verify --strict`, rebuild indexes and required derivatives, and record the achieved RPO/RTO. A destructive restore requires confirmation:

```bash
sitectl isle recovery restore --input /var/backups/isle/site-2026-08-07.tar.gz
```

## License

The Docker Compose template and LibOps-specific setup in this repository are licensed under the MIT License. The upstream Islandora starter site is licensed separately under the GNU General Public License v2; see `LICENSE.islandora-starter-site`.

## Attribution

Forked from https://github.com/Islandora-Devops/isle-site-template
