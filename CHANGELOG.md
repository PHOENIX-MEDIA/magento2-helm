# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.8.0-rc4
### Changed
- Switched to aws-images in sub-chart "mariadb", "rabbitmq" and "redis".

### Fixed
- Fixed a typo in ingress-annotation in magento ingress

## 2.8.0-rc3
### Changed
- Updated beta-api version of external-secrets.io resources to v1
- Use static WAF service name to simplify Varnish probe
- Ensure Magento error pages are not replaced by standard error pages of the Apache reverse proxy