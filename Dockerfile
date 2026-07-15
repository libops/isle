ARG BASE_IMAGE=libops/islandora:nginx-1.30.3-php84@sha256:e9235dc3789d6ba8885849c80888b755d9e60c316e5de8d88bcd5e9d214ecd42
FROM ${BASE_IMAGE}

ARG TARGETARCH

WORKDIR /var/www/drupal

COPY --link composer.json composer.lock /var/www/drupal/
COPY --link assets/ /var/www/drupal/assets/

RUN cp /usr/share/drupal/default_settings.txt /var/www/drupal/assets/default_settings.txt && \
    cat /var/www/drupal/assets/libops_settings.txt >> /var/www/drupal/assets/default_settings.txt

RUN --mount=type=cache,id=custom-drupal-composer-${TARGETARCH},sharing=locked,target=/root/.composer/cache \
    composer install -d /var/www/drupal --no-interaction --no-progress --prefer-dist --no-dev --optimize-autoloader && \
    cleanup.sh

COPY --link config/ /var/www/drupal/config/
COPY --link recipes/ /var/www/drupal/recipes/
COPY --link web/modules/custom/ /var/www/drupal/web/modules/custom/
COPY --link web/themes/custom/ /var/www/drupal/web/themes/custom/
COPY --link drupal/rootfs/opt/ /opt/

RUN chown -R nginx:nginx /var/www/drupal && \
    cleanup.sh
