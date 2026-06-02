## ISLE: Site Template

[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](./LICENSE)

- [Introduction](#introduction)
  - [Assumptions](#assumptions)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [Configuration](#configuration)
  - [Environment Variables](#environment-variables)
  - [HTTPS & Certificates](#https--certificates)
- [Docker Compose](#docker-compose)
  - [Override](#docker-compose-overrides)
  - [Pushing Docker Images](#pushing-docker-images)
    - [Local Registry](#local-registry)
    - [Remote Registry](#remote-registry)
- [Development](#development)
  - [Drupal Development](#drupal-development)
    - [Adding a composer dependency](#adding-a-composer-dependency)
- [Production](#production)
  - [Automated Certificate Generation](#automated-certificate-generation)
  - [Setup as a systemd Service](#setup-as-a-systemd-service)
- [Troubleshooting](#troubleshooting)

## Introduction

Template for building and customizing your institution's Islandora installation,
for use as both a development and production environment.

This repository is intended to be used as a template. You can click the "Use this template" button on GitHub to create a new repository with the same directory structure and files.

### Assumptions

This template assumes you'll be running your site in Docker on a **single server**.

This template is set up for a single site installation and isn't configured for a
[Drupal multisite](https://www.drupal.org/docs/multisite-drupal).

While Islandora can be setup to use a wide variety of databases, tools and
configurations this template is set up for the following:

 - `blazegraph` is included by default.
 - `scyllaridae` services are included by default.
 - `fcrepo` is included by default.
 - `fits` is included by default.
 - `mariadb` is used for the backend database.
 - `solr` is included by default.

## Requirements

- [Docker 24.0+](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/linux/) **Already included in OSX with Docker**
- `Make` (Standard on Linux/OSX, use WSL on Windows)
- `cURL` and `git`
- [mkcert](https://github.com/FiloSottile/mkcert) (optional, for local development certificates)

## Quick Start

1. In GitHub click the green `Use this template` button to create this same repository in your GitHub Organization
2. Clone your new repository:
    ```bash
    git clone https://github.com/INSTITUTION/SITE_NAME.git
    cd SITE_NAME
    ```

3. Start the services:
    ```bash
    make up
    ```
    This command prepares your host machine, creates the `.env` file from `sample.env` if it doesn't exist, generates necessary secrets and certificates, and builds the Docker images.

    Then brings up the ISLE stack using smart port allocation. The URL for your site will be displayed in the output and automatically opened in your browser if possible.

    Default URL: [http://islandora.io](http://islandora.io) (maps to 127.0.0.1)

    *Note: The first start will take several minutes as Drupal installs.*

## Commands

This project uses a `Makefile` to simplify common tasks.

```
$ make help
Usage: make [target]

Available targets:
  help                 Show this help message
  status               Show the current status of the development environment
  traefik-http         Switch to HTTP mode (default)
  traefik-https-mkcert Switch to HTTPS mode using mkcert self-signed certificates
  traefik-https-letsencrypt Switch to HTTPS mode using Let's Encrypt ACME
  build                Build the drupal container
  init                 Get the host machine configured to run ISLE
  up                   Start docker compose project with smart port allocation
  down                 Stop/remove the docker compose project's containers and network.
  clean                Delete all stateful data.
  ping                 Ensure site is available.
  overwrite-starter-site Keep site template's drupal install in sync with islandora-starter-site
  create-starter-site-pr Create a PR for islandora-starter-site updates
```

## Configuration

### Environment Variables

The `.env` file contains environment variables for configuring the Docker Compose project.
Edit this file to customize your setup.

Key variables:
- `COMPOSE_PROJECT_NAME`: Unique name for your project.
- Per-service `*_IMAGE` values: Optional overrides for the `libops/*` buildkit images consumed by the stack.
- `DOMAIN`: The domain name for your site (default: `islandora.io`).
- `REPOSITORY`: Docker registry for pushing/pulling images.

### HTTPS & Certificates

By default, the environment runs over **HTTP** to simplify local development.

To switch to **HTTPS** for local development (macOS and Linux only **WSL** is not supported for local TLS certificates):
1.  Ensure you have [mkcert](https://github.com/FiloSottile/mkcert) installed and trusted on your host.
2.  Run:
```bash
make traefik-https-mkcert
make down-traefik up
```

To switch back to **HTTP**:
```bash
make traefik-http
make down-traefik up
```

## Docker Compose

There are a number of `docker-compose.yml` files provided by this repository:

| File                                                                       | Description                                                                                                      |
| :------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------- |
| [docker-compose.yml](docker-compose.yml)                                   | Defines all services.                                                                                            |
| [docker-compose.override-example.yaml](docker-compose.override-example.yaml) | Example local development bind mounts. Copy to `docker-compose.override.yaml` to take effect.                    |

### Docker Compose Overrides

This git repository does not track `docker-compose.override.yaml`. If that file exists, its service overrides will
be merged into the main definitions in `docker-compose.yml`. See [https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/](https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/) for more information.

Any changes that are for your local / development environment can
be added to `docker-compose.override.yaml` because that file is not under version control.

A sample override is provided at [docker-compose.override-example.yaml](docker-compose.override-example.yaml):

```bash
cp docker-compose.override-example.yaml docker-compose.override.yaml
```

### Settings

| Credentials | Value    |
| :---------- | :------- |
| Username    | admin    |
| Password    | `cat ./secrets/DRUPAL_DEFAULT_ACCOUNT_PASSWORD` |

If you have these default values in your `.env` file

```
URI_SCHEME=http
DOMAIN=islandora.io
DEVELOPMENT_ENVIRONMENT=true
```
you can access all the services at the following URLs.

| Service    | URL                                       |
| :--------- | :---------------------------------------- |
| Drupal     | http://islandora.io                     |
| ActiveMQ   | http://activemq.islandora.io            |
| Blazegraph | http://blazegraph.islandora.io/bigdata/ |
| Cantaloupe | http://islandora.io/cantaloupe          |
| Fedora     | http://fcrepo.islandora.io/fcrepo/rest/ |
| Solr       | http://solr.islandora.io                |
| Traefik    | http://traefik.islandora.io             |

> [!IMPORTANT]
> DEVELOPMENT_ENVIRONMENT should never be set to `true` for sites available on the public internet

### Pushing Docker Images

Pushing requires setting up either a [Local Registry](#local-registry), or a
[Remote Registry](#remote-registry). Though you may want to use both concurrently.

Additionally the command to build & push changes if you need multi-platform
support, i.e. if you need to be able to run on ARM (Apple M1, etc) as well as
x86 (Intel / AMD) CPUs.

#### Local Registry

To test multi-platform builds locally requires setting up a local registry.

This can be done with the assistance of [isle-builder] repository.

> N.B. Alternatively you can push directly to a remote registry like
> [DockerHub], though that can be slow as it needs to upload your image over the
> network.

Now you can perform the build locally with the Compose build definition:

```bash
docker compose build --pull drupal
```

The template image extends pinned LibOps runtime images. Keep app-specific
Composer files, Drupal config, modules, and themes in this repository; the
build bakes those local changes into the resulting image.

#### Remote Registry

First you must choose a Docker image registry provider such as [DockerHub].

Assuming your are logged into your remote repository, i.e. you've done
`docker login` with the appropriate arguments and credentials for your chosen
remote Docker image repository.

If you do not need to build multi-platform images, you can then push to the
remote repository using `docker compose`:

```bash
docker compose push drupal
```

If you do need produce multi-platform images, you'll need to setup a builder
which is covered under the [Local Registry](#local-registry) section.

```bash
docker buildx bake --pull --builder isle-builder --push
```

> N.B. In this example `REPOSITORY` **is not** overridden, so the value provided
> by [.env] is used.

## Development

### Drupal Development

For local development, app-specific Drupal extension paths are bind-mounted into the drupal container if [your local install has a docker-compose.override.yaml](#docker-compose-overrides) set.
Changes made in the following directories will persist in your Git repository:

- `./drupal/composer.json`
- `./drupal/composer.lock`
- `./drupal/config/`
- `./drupal/web/modules/custom/`
- `./drupal/web/themes/custom/`

Composer changes are applied when the local Drupal image is rebuilt. Other changes, such as those in `vendor/` or installed modules, are managed during the image build.

#### Adding a composer dependency

To add a composer dependency to your running instance you can

```bash
docker compose exec drupal composer require drupal/module
```

## Production

### Automated Certificate Generation

For production, Traefik can automatically generate valid TLS certificates using Let's Encrypt.

1.  Update `DOMAIN` in `.env` to your production domain (e.g., `my-islandora.org`).
2.  Update `ACME_EMAIL` in `.env` for Let's Encrypt notifications.
3.  Ensure your DNS records (A Records) for `${DOMAIN}` and `fcrepo.${DOMAIN}` point to your server's IP.
4.  Switch to ACME mode:
```bash
make traefik-https-letsencrypt
```
3.  Restart traefik:
```bash
make down-traefik up
```

### Setup as a systemd Service

For production process management, you can use a `systemd` unit file.

```ini
[Unit]
Description=Islandora
PartOf=docker.service
After=docker.service

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/SITE_NAME
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
```


## Add Custom Makefile Commands

To add custom Makefile commands without adding upstream git conflict complexity, just create a new `custom.Makefile` and the Makefile will automatically include it. This can be a completely empty file that needs no header information. Just add a function in the following format.
```makefile
.PHONY: lowercasename
.SILENT: lowercasename
## This is the help description that comes up when using the 'make help` command. This needs to be placed with 2 # characters, after .PHONY & .SILENT but before the function call. And only take up a single line.
lowercasename:
	echo "first line in command needs to be indented. There are exceptions to this, review functions in the Makefile for examples of these exceptions."
```

NOTE: A target you add in the custom.Makefile will not override an existing target with the same label in this repository's defautl Makefile.

Running the new `custom.Makefile` commands are exactly the same as running any other Makefile command. Just run `make` and the function's name.
```bash
make lowercasename
```

## Troubleshooting

**Windows Users:**
It is highly recommended to use **WSL 2** (Windows Subsystem for Linux) for running this stack. The `Makefile` and shell scripts are designed for a Unix-like environment.

**Status Check:**
Run `make status` to check for common misconfigurations or issues.

[Islandora Slack]: https://islandora.slack.com/
