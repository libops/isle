# libops ISLE Template

A starting Docker setup and Drupal configuration for Islandora sites. 

## License

[GPLv2](http://www.gnu.org/licenses/gpl-2.0.txt)

## Attribution

Forked from https://github.com/Islandora-Devops/isle-site-template

- moved drupal codebase into the root of the repo: `sitectl component set isle/codebase git-root`
- swapped fcrepo with drupal’s private: `sitectl component set isle/fcrepo superceded --isle-file-system-uri private`
- removed blazegraph: `sitectl component set isle/blazegraph disabled`
- swapped cantaloupe with triplet: `sitectl component set isle/iiif triplet`
