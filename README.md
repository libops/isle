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

The `drupal` service builds this checkout on top of the LibOps Islandora base image. The Dockerfile copies Composer lockfiles and assets before local recipes, modules, themes, config, and rootfs additions so Docker can reuse dependency layers when only site customizations change. Local builds use the platform selected by the Docker CLI and do not push images.

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

Update image tags or pin a full image reference with [`sitectl image`](https://sitectl.libops.io/commands/image):

```bash
sitectl image set --tag drupal=nginx-1.30.3-php84 --tag solr=9 --tag alpaca=main
sitectl image set --image drupal=libops/islandora:nginx-1.30.3-php84@sha256:...
```

Enable local development bind mounts with [`sitectl set`](https://sitectl.libops.io/commands/set), then apply the component change with [`sitectl converge`](https://sitectl.libops.io/commands/converge):

```bash
sitectl set dev-mode enabled
sitectl converge
```

Publish a domain, switch HTTP/TLS mode, configure Let's Encrypt, trust upstream proxies, or tune upload limits with the `ingress` component:

```bash
sitectl set ingress enabled --mode https-default --domain islandora.localhost
sitectl set ingress enabled --mode https-letsencrypt --domain islandora.example.org --acme-email ops@example.org
sitectl set ingress enabled --trusted-ip 203.0.113.10/32 --max-upload-size 2G --upload-timeout 10m
sitectl converge
```

Enable ISLE bot mitigation with [`sitectl set`](https://sitectl.libops.io/commands/set), then apply it with [`sitectl converge`](https://sitectl.libops.io/commands/converge):

```bash
sitectl set bot-mitigation on
sitectl converge
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

## License

The Docker Compose template and LibOps-specific setup in this repository are licensed under the MIT License. The upstream Islandora starter site is licensed separately under the GNU General Public License v2; see `LICENSE.islandora-starter-site`.

## Attribution

Forked from https://github.com/Islandora-Devops/isle-site-template
