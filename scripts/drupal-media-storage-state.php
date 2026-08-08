<?php

declare(strict_types=1);

$scheme = \Drupal::config('field.storage.media.field_media_image')->get('settings.uri_scheme');
$wrappers = \Drupal::service('stream_wrapper_manager')->getWrappers();
$flysystem = \Drupal\Core\Site\Settings::get('flysystem', []);
$private = \Drupal\Core\Site\Settings::get('file_private_path', '');

print json_encode([
    'scheme' => $scheme,
    'registered' => isset($wrappers[$scheme]),
    'fedora_configured' => isset($flysystem['fedora']),
    'private_path_exists' => is_string($private) && is_dir($private),
    'private_path_writable' => is_string($private) && is_writable($private),
], JSON_THROW_ON_ERROR);
