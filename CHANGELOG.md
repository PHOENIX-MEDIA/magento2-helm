# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.6.2
### Changed
- Switched to aws-images in sub-chart "mariadb", "rabbitmq" and "redis".
### Fixed
- Adjust elasticsearch java ram usage to resource limit to fix OOMKilled issues.

## 2.6.1
### Added
- Added Support for stringData credentials
### Changed
- Changed "secrets.credentials" structure

## 2.6.0
### Added
- Added Support for External Secrets Operator