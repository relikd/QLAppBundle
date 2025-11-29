# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project does adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [1.4.0] – 2025-11-29
Added:
- Support for `.apk` files
- Support for `.apkm` files


## [1.3.0] – 2025-11-06
Added:
- Show macOS apps in `.xcarchive`
- Show `.xcarchive` developer notes

Fixed:
- Cancel preview (and allow other plugins to run) if there is no `Info.plist` in `.xcarchive`

Changed:
- Hide Transport Security and Entitlements if they are empty


## [1.2.0] – 2025-11-04
Added:
- Customizable HTML template

Fixed:
- Properly handle `Assets.car` files by abstracting relevant code into `.framework`

Changed:
- Updated HTML template


## [1.1.0] – 2025-10-30
Added:
- Support for `.tipa` files


## [1.0.0] – 2025-10-30
Initial release


[1.4.0]: https://github.com/relikd/QLAppBundle/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/relikd/QLAppBundle/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/relikd/QLAppBundle/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/relikd/QLAppBundle/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/relikd/QLAppBundle/compare/9b0761318c85090d1ef22f12d3eab67a9a194882...v1.0.0
