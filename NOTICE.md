# NOTICE — third-party components and attributions

This package (`twofauthdocker`, TOS 7 Docker application) is an independent packaging by
Moechz of the upstream **2FAuth** project.

## 1. Upstream application — 2FAuth

- Project: <https://github.com/Bubka/2FAuth>
- Upstream author: Bubka — <https://github.com/Bubka>
- Licence: **AGPL-3.0** (verify the current text in the upstream repository; the app is
  distributed under AGPL-3.0)
- Relationship: the upstream application is used **unmodified**, inside the container image.
  No upstream source code is redistributed in this package; the image is pulled from Docker
  Hub at install time.

2FAuth is a web app to manage Two-Factor Authentication (2FA) accounts and generate their
security codes. It stores TOTP, HOTP and Steam accounts and supports groups, import/export and
optional account sharing between local users.

## 2. Container image — `2fauth/2fauth:9.0.2`

- Registry: Docker Hub (`2fauth/2fauth:9.0.2`)
- Maintainer: the 2FAuth project (Bubka)
- Multi-arch OCI index digest:
  `sha256:6774efa7c612e424eb17a54e2373524d9a04af6cad7e38d85d76fed87f6a48bd`
  (platforms: `linux/amd64`, `linux/arm64`, `linux/386`, `linux/arm/v6`, `linux/arm/v7`)
- The image is pulled from Docker Hub at install/update time and is **not redistributed** in
  this package. The TOS package contains only the four metadata/compose files listed in
  `README.md`.

## 3. Components inside the image

The image is built by its maintainer on top of a Debian/PHP base and bundles the
application's own PHP/JS dependencies (Laravel, Vue, Passport, WebAuthn libraries, etc.).
Their licences are documented in the image's package metadata and in the upstream
`composer.lock` / `package.json` files. They are shipped inside the image only and are not
redistributed as separate files by this package.

## 4. This packaging

The files authored for this package — `docker-compose.yml`, `config.ini`,
`twofauthdocker.lang`, `twofauthdocker.svg`, `src/entrypoint.sh`, the build scripts and this
documentation — are released under the **MIT licence** (see `LICENSE`). The wrapper script and
the compose file are original work; they do not copy upstream source code. The upstream
application itself remains AGPL-3.0 and is used unmodified inside the image.

## 5. Trademarks

“2FAuth”, “TerraMaster” and “TOS” are trademarks or registered trademarks of their respective
owners. Their use here is descriptive only (to identify the upstream project and the target
platform). This package is **not affiliated with, sponsored or endorsed by** the upstream
project or TerraMaster.

## 6. Icon

The application icon in `src/twofauthdocker.svg` is a mark drawn or assembled for this package
for identification purposes. If it incorporates an upstream logo, that logo remains the
property of its owner and is used only to identify the 2FAuth project.

## 7. Contact

Moechz — moechz@163.com — <https://www.moechz.com/>
Issues: <https://github.com/Moechz/2fauth/issues>
