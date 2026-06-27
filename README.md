# LibOps ISLE Template

LibOps Docker Compose template for running [Islandora](https://www.islandora.ca/) with Drupal, Traefik, MariaDB, Solr, ActiveMQ, Alpaca, and LibOps derivative services.

## Requirements

- `sitectl` installed on the host that will run the site.
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

The site is served through Traefik at `http://islandora.io` unless you change `DOMAIN`.

## Basic operations with sitectl

Run these from the generated checkout, or add `--context <name>` when operating from elsewhere.

```bash
# Start or update the Compose stack
sitectl compose up --remove-orphans -d

# Check the site and context configuration
sitectl healthcheck
sitectl validate

# Update image tags or pin a full image reference
sitectl image set --tag drupal=nginx-1.30.3-php84 --tag solr=9 --tag alpaca=main
sitectl image set --image drupal=libops/islandora:nginx-1.30.3-php84@sha256:...

# Enable local development bind mounts
sitectl set dev-mode enabled
sitectl converge

# Switch TLS modes
sitectl traefik tls mkcert --domain islandora.localhost
sitectl traefik tls letsencrypt --email ops@example.org

# Trust an upstream load balancer or reverse proxy
sitectl set reverse-proxy enabled --trusted-ip 203.0.113.10/32
sitectl converge

# Raise upload limits for larger media
sitectl set upload-limits enabled --max-upload-size 2G --upload-timeout 10m
sitectl converge

# Enable ISLE bot mitigation
sitectl set bot-mitigation on
sitectl converge
```

See the [ISLE sitectl plugin docs](https://github.com/libops/sitectl-docs/blob/main/plugins/isle.mdx) for Fedora, Blazegraph, IIIF, derivative microservices, cache, sync, migration, TLS, and bot mitigation details.

## Makefile

The Makefile is intentionally small. It only keeps ISLE-specific targets that are not core sitectl operations:

```bash
make demo-objects
make sync-solr-conf
make overwrite-starter-site
make create-starter-site-pr
make clean
```

Use `sitectl compose ...`, `sitectl traefik ...`, and `sitectl set ...` directly for normal stack operations.

## Template notes

This template starts from the upstream Islandora site template and applies LibOps defaults:

- Drupal codebase at the repository root.
- Fedora replaced with Drupal private files by default.
- Blazegraph removed by default.
- Cantaloupe replaced with Triplet.
- LibOps images for the application services.

## License

[GPLv2](http://www.gnu.org/licenses/gpl-2.0.txt)

## Attribution

Forked from https://github.com/Islandora-Devops/isle-site-template
