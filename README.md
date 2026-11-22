# 2fauth-for-tos

> TerraMaster TOS 7 App Center — **Docker application** package for
> [2fauth](https://github.com/Bubka/2FAuth).

This repository is public: the packaging source, the build scripts and the privacy policy are
all readable here. The installable package is attached to each GitHub Release.

## What this is

A four-file TOS Docker application archive (`twofauthdocker.tar.gz`) that installs 2fauth on
TOS 7 through the App Center:

- `config.ini` — TOS application metadata (`application_type: docker`, id `twofauthdocker`)
- `twofauthdocker.lang` — 23-language superset (TOS requires 14)
- `twofauthdocker.svg` — application icon
- `docker-compose.yml` — one service, image `2fauth/2fauth:9.0.2`

The upstream application is used unmodified inside the official Docker Hub image. This
package only adds a small wrapper that prepares the mounted storage volume, creates a
persistent `APP_KEY`, initialises the OAuth keys quietly on first start, and forwards the
container stop signal so the service stops cleanly.

## Repository layout

```text
.
├── CHANGELOG.md                     release history and review-code mapping
├── LICENSE                          licence of this packaging (MIT)
├── NOTICE.md                        upstream licence, image digest, trademarks
├── PRIVACY.md                       full privacy policy (also shipped in the app help link)
├── README.md                        this file
├── TOSAppSelfTestingTool            official package checker (binary, used by scripts)
├── tosapp.json                      single source of truth for the build (version, image, ports)
├── scripts/
│   ├── build.sh                     build one architecture: out/<appid>.tar.gz
│   └── build-dual.sh                build x86_64 + aarch64 and run the official checker
├── src/
│   ├── config.ini                   TOS metadata (version/platform substituted at build)
│   ├── twofauthdocker.lang          UI strings (23 languages, English fallback)
│   ├── twofauthdocker.svg            application icon
│   ├── docker-compose.yml           service definition (entrypoint embedded at build)
│   └── entrypoint.sh                wrapper: APP_KEY, storage dirs, silent first run, signals
├── test/
│   └── install-and-verify.sh        on-device E2E helper (needs root; not run by CI)
└── tools/
    └── verify.py                    review-standards self-check used by the build
```

Build products (`build/`, `out/`) and the generated compose copy (`test/compose-resolved/`)
are not committed.

## How it works

| | |
|---|---|
| Container image | `2fauth/2fauth:9.0.2` (Docker Hub, multi-arch, used unmodified) |
| Open | `http://<NAS-IP>:8040/` (container port 8000) |
| Runs as | non-root, `user: "1000:1000"` |
| Persistent data | `/2fauth/storage` → `/Volume1/DockerAppData/twofauthdocker/storage` |
| Logs | `docker logs twofauthdocker` (stdout/stderr) and `storage/logs/laravel.log*` |
| Health check | `wget -q -O /dev/null http://127.0.0.1:8000/` |

The image is pinned to a fixed tag (never `:latest`), comes only from Docker Hub, and the
compose file has no `privileged`, no `network_mode: host`, no `cap_add` and no Docker socket.

## Privacy

The developer does **not** collect, receive or have access to your data. There is no
telemetry, analytics or developer account. The app is self-hosted; the data lives in
`/Volume1/DockerAppData/twofauthdocker/` on your NAS.

Because 2FAuth stores the **TOTP/HOTP/Steam seeds** that generate your one-time codes, the
privacy policy explains in detail:

- **Encryption:** `APP_KEY` (32 random bytes, generated on first start, stored at
  `storage/app_key`, mode 600) drives Laravel's AES-256-CBC encryption. **2FAuth's field-level
  database encryption is OFF by default**; enable *Admin → App Setup → “Encrypt sensitive
  data”* after backing up the folder and `app_key`. Without it, TOTP seeds are plain text in
  the SQLite file.
- **WebAuthn:** only the public key, credential ID and counter are stored; the private key and
  biometric data stay on the authenticator. WebAuthn needs HTTPS.
- **Backups / exports:** copying `storage/` (including `app_key`) is a complete backup; UI
  exports contain the readable secrets and must be protected.
- **Logs:** the package sets `LOG_LEVEL=warning`, suppresses the first-run OAuth client
  secrets, and documents what container/nginx logs can contain.
- **Outbound requests:** icon lookup, the weekly release check, Docker Hub and anything you
  configure (SSO, SMTP, remote image links). The full table is in `PRIVACY.md` §8.

**Full privacy policy:** [PRIVACY.md](PRIVACY.md) —
<https://github.com/Moechz/2fauth/blob/main/PRIVACY.md> — and the website copy at
<https://www.moechz.com/privacy.html>.

## Third-party services (API disclosure)

The developer operates no server in this path. The application contacts only the services
below. The icon and release-check requests are made by the NAS, so the NAS's IP is
visible to those services, not your browser's.

| Service | Endpoint | Data sent | Destination / region | Disable |
|---|---|---|---|---|
| Account icons (default on) | `cdn.jsdelivr.net` (`selfhst/icons`, `homarr-labs/dashboard-icons`) | service-name slug + HTTP metadata (IP, user-agent); no secret, e-mail or code | jsDelivr CDN, global (US/EU) | Admin → App Setup → “Get official icons” off, or icon source “none” |
| Icon directory (TFA source only) | `2fa.directory/api/v3/tfa.json`, `raw.githubusercontent.com/2factorauth/twofactorauth` | directory download / icon path derived from service name | 2FA Directory / GitHub, US | choose another icon source |
| Release check (default on, ≤ weekly) | `api.github.com/repos/Bubka/2FAuth/releases/latest` | plain request (IP, user-agent); no app data | GitHub, US | Admin → App Setup → “Check for updates” off |
| Image pull | `registry-1.docker.io` or your mirror | anonymous image pull | Docker Hub, US / your mirror | TOS/Docker settings |
| SSO you enable | your OIDC issuer / GitHub OAuth | authentication data the provider requires | provider you chose | keep SSO disabled |
| SMTP you configure | your mail server | notification/recovery e-mails | your mail provider | keep `MAIL_MAILER=log` (default) |
| Remote image link you paste | the URL you enter | one HTTP GET for that image (SSRF-guarded) | destination you chose | don't use the feature |

No data is sold or shared with advertisers. There is no third-party analytics SDK.

## Data and uninstall

| Action | What happens |
|---|---|
| Where data lives | `/Volume1/DockerAppData/twofauthdocker/storage` (SQLite DB, `app_key`, OAuth keys, icons, logs, sessions/cache) |
| Restart / update | Data survives. The database is migrated automatically on first start of a new image |
| Backup | Stop the container, copy the whole `storage/` folder — especially `database.sqlite` and `app_key` |
| Uninstall | The App Center keeps the folder by default. Uninstall with “delete data” (or stop the container and delete the folder) to remove everything |
| Reinstall | Copy `storage/` back before starting; keep `app_key` with the database |

## Upgrade / migration notes (6.1.3 → 9.0.2)

This release moves the upstream base from **6.1.3 to 9.0.2**, a security release. Before
updating:

1. **Back up** `/Volume1/DockerAppData/twofauthdocker/storage` (database + `app_key` +
   OAuth keys). Keep the backup until you have logged in and verified your accounts.
2. The database is migrated automatically on first start. Do not interrupt the first start.
3. **Personal access tokens created before 8.0 are invalid** (upstream breaking change in
   8.0.0). Re-create them in the UI/API settings after the upgrade.
4. If you use an authentication proxy, set `TRUSTED_PROXIES` as required by 2FAuth 8.0+;
   otherwise proxy authentication is rejected.
5. **2FA sharing is off by default** in 9.x. Enable it in the admin panel if you need it.
6. OTP generation logs are new in 7.0 and use a 365-day retention by default; the generated
   codes are never stored.
7. 9.0.2 fixes CVE-2026-109618, CVE-2026-109619, CVE-2026-123007, CVE-2026-123633 and
   several GHSA advisories (XSS, host-header poisoning, SSRF bypass, stored icon path
   traversal). See `CHANGELOG.md`.

If you need to roll back, restore the backup taken in step 1 with the old image; downgrades
are not supported by upstream.

**APP_URL note:** 2FAuth 7.0+ no longer forces the whole UI to `APP_URL`, so the SPA works on
any LAN address (this is what fixed the blank page). `APP_URL` still matters for password-reset
/ WebAuthn recovery e-mail links, SSO redirects and WebAuthn, and defaults to
`http://localhost`. If you use those features behind a TLS reverse proxy, set `APP_URL` to the
public HTTPS URL in a local compose override. Mail is unconfigured by default
(`MAIL_MAILER=log`), so no e-mail leaves the NAS unless you configure SMTP.

## Build

```bash
scripts/build-dual.sh 9.0.2-1     # x86_64 + aarch64, official checker on both
scripts/build.sh 9.0.2-1 x86_64   # one architecture only
```

`scripts/build.sh` stages the four files, substitutes version/platform, embeds
`src/entrypoint.sh` into the compose block (escaping `$` as `$$`), normalises line endings and
timestamps, then runs `tools/verify.py`, a review-standards self-check (archive layout, JSON
validity, required fields, 14+ languages, version consistency, Docker-Hub-only images, fixed
tag, reserved/recommended ports, non-root user, per-service healthcheck/TZ/restart, data path
below the application data root, never the `/Volume*` wildcard, comment-free sequence blocks,
`x-app-meta` position, no literal secrets, and SVG size/element limits). `build-dual.sh` also
runs the official `TOSAppSelfTestingTool -c` on both packages.

## Local verification

```bash
./TOSAppSelfTestingTool -c out/twofauthdocker_x86_64.tar.gz
./TOSAppSelfTestingTool -c out/twofauthdocker_aarch64.tar.gz
cd ../.. && python3 stage.py work/2fauth --timeout 300   # from issue-watch
```

`stage.py` runs the package on a temporary port and a temporary data directory, asserts the
container is running/healthy, non-root and answering HTTP, then cleans up. It never touches
`/Volume1/DockerAppData`.

> Docker applications cannot be side-loaded through the App Center's manual install page
> (it accepts `.deb` only); the official self-testing tool's `-i` mode or `docker compose`
> are the only ways to install one for testing.

## Release and submission

1. Public GitHub repository with the source, `PRIVACY.md`, `NOTICE.md` and `CHANGELOG.md`.
2. Release tag `v9.0.2-1` with assets `twofauthdocker_x86_64.tar.gz`,
   `twofauthdocker_aarch64.tar.gz` and their `.sha256` files.
3. Developer platform: version `9.0.2-1`, both architectures. The platform parses each
   architecture separately and records a `file_hash`; it must equal the local `sha256sum`.

## Limitations

- The package serves plain HTTP on the LAN. Use a TLS reverse proxy if you expose it. WebAuthn
  and camera QR scanning require a secure context (HTTPS or `localhost`); on plain HTTP use
  password login and manual secret entry.
- The SQLite database is not encrypted at rest unless you enable 2FAuth's field encryption or
  use volume encryption. Enable field encryption after backing up `app_key`.
- 2FAuth is a web application, not a native mobile app; the web UI is responsive and can be
  added to a home screen.
- The upstream image supports `amd64` and `arm64`; this package ships both.

---

Packaged for TOS 7 by Moechz. Upstream image used unmodified from Docker Hub.

## Licence and attributions

| Component | Licence | Notes |
|---|---|---|
| 2FAuth | AGPL-3.0 | upstream application, used unmodified inside the image |
| Container image `2fauth/2fauth:9.0.2` | see the image's own metadata | pulled from Docker Hub at install time |
| This packaging | MIT (see `LICENSE`) | compose file, metadata, translations, icon, wrapper, build scripts |

“2fauth”, “TerraMaster” and “TOS” are trademarks of their respective owners. This is an
independent community package by Moechz and is not affiliated with the upstream project or
TerraMaster. Full details: [NOTICE.md](NOTICE.md).

## Support

- Issues and questions: <https://github.com/Moechz/2fauth/issues>
- E-mail: moechz@163.com
- Privacy: [PRIVACY.md](PRIVACY.md) · Licence: [NOTICE.md](NOTICE.md)
