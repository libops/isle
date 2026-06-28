ARG REPOSITORY=libops
ARG TAG=1.30.3-php84
FROM ${REPOSITORY}/islandora:${TAG}

ARG TARGETARCH

ENV \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1
WORKDIR /var/www/drupal

COPY --link composer.json composer.lock /var/www/drupal/
COPY --link assets/ /var/www/drupal/assets/

RUN --mount=type=cache,id=custom-drupal-composer-${TARGETARCH},sharing=locked,target=/root/.composer/cache \
    composer install -d /var/www/drupal --no-interaction --no-progress --prefer-dist --no-dev --optimize-autoloader && \
    cleanup.sh

COPY --link config/ /var/www/drupal/config/
COPY --link recipes/ /var/www/drupal/recipes/
COPY --link web/modules/custom/ /var/www/drupal/web/modules/custom/
COPY --link web/themes/custom/ /var/www/drupal/web/themes/custom/
COPY --link drupal/rootfs/etc/ /etc/
COPY --link drupal/rootfs/opt/ /opt/

RUN chown -R nginx:nginx /var/www/drupal && \
    cleanup.sh
