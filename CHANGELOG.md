# Changelog

All notable user-visible changes to the 2fauth TOS application package.

## 9.0.2-1 — 2026-11-22

Review remediation for the App Center findings on 6.1.3-3 (aarch64 `C3 C4 C5 C6 C8 C9 C10 T1
F3 F5 F7`; x86_64 `C6 C8 C9 T1 F3 F7 F10`) and the blocking "blank page" finding.

### Changed
- **T1 — upstream upgraded 6.1.3 → 9.0.2**, a security release that fixes CVE-2026-109618,
  CVE-2026-109619, CVE-2026-123007, CVE-2026-123633 and the GHSA-3xgg-3487-6cg6,
  GHSA-5j97-34rm-v5cp, GHSA-3c3f-fvc4-87rh and GHSA-7j9c-p3v3-74xp advisories. The image is
  the multi-arch `2fauth/2fauth:9.0.2` OCI index
  (`sha256:6774efa7c612e424eb17a54e2373524d9a04af6cad7e38d85d76fed87f6a48bd`, amd64/arm64).
- **F7 (blocking) — SPA assets no longer use `http://localhost/...`**: 2FAuth 7.0 removed the
  global `URL::forceRootUrl(APP_URL)` and 9.x defaults `asset_url` to `/`, so CSS/JS/manifest
  URLs are rooted on the address the browser used. Verified on the staged container: the HTML
  has `/build/assets/...` and no `http://localhost` asset URL.
- **F3 — clean shutdown**: the wrapper now runs the upstream entrypoint as a child and relays
  `SIGTERM`/`SIGINT` to supervisord (pidfile + `/proc` fallback), so php-fpm/nginx stop with
  the container instead of being orphaned; `stop_grace_period: 20s` added. Verified with
  `docker stop`.
- **F10 — no secrets in logs**: the first-run `passport:install` output (OAuth client secrets)
  is redirected to a temporary file that is deleted, and `LOG_LEVEL=warning` suppresses the
  upstream info/notice messages that contain login e-mails and client IPs. The leaked trial-log
  block was removed from `tosapp.json`.
- **C6 / C8 — declaration matches behaviour**: `PRIVACY.md` now lists every outbound endpoint
  (icon CDNs, 2fa.directory, GitHub release check, Docker Hub, user-configured SSO/SMTP/remote
  image links), what each sends and its region, plus the retention/logging rules. The old
  claim that the app contacts only user-configured services was wrong: icon lookup is on by
  default and the release check runs weekly.
- **C3 / C4 / C5 — complete, accessible privacy policy**: rewritten `PRIVACY.md` covering
  storage locations, retention, user rights, security measures, third-party sharing, deletion
  channel, contact, `APP_KEY`/AES-256-CBC, the **default-off** field encryption, WebAuthn,
  backups/exports and log contents. `tosapp.json.help` and `config.ini.help` now point to the
  public policy: <https://github.com/Moechz/2fauth/blob/main/PRIVACY.md>.
- **C9 / F5 — description matches delivered functionality**: the 23-language `app.lang` text now
  describes TOTP/HOTP/Steam, groups, import/export and optional local sharing, and states that
  WebAuthn and camera QR scanning need HTTPS (plain LAN HTTP uses password + manual secret).
  zh-cn and zh-hk are real translations; the rest intentionally fall back to English.
- **C10 — repository/README compliance**: public repository; README now has repository layout,
  privacy, notices, build, data/uninstall, upgrade/migration and limitations sections. The
  obsolete `specs/twofauth-entrypoint.sh` pointer became `src/entrypoint.sh`.
- **C2/NOTICE**: packaging licence corrected to MIT (it was mislabelled GPL-3.0 while `LICENSE`
  is MIT); upstream AGPL-3.0, image source/digest and trademark attribution documented.

### Added
- `src/entrypoint.sh` now creates the framework/icon/log directories an empty mounted volume
  lacks, writes a proper `base64:` `APP_KEY` on new installations (existing raw keys are kept
  unchanged), and initialises Passport once, silently.
- `stop_grace_period`, `LOG_LEVEL=warning`, and a persistent `storage/app_key` are documented.
- `README.md` migration notes for 6.1.3 → 9.0.2, including the pre-8.0 personal-access-token
  invalidation and the `TRUSTED_PROXIES` requirement for authentication proxies.

### Migration
1. Back up `/Volume1/DockerAppData/twofauthdocker/storage` — especially `database.sqlite` and
   `app_key` — before updating.
2. Start the new version once without interruption; database migrations run automatically.
3. Re-create personal access tokens created before 8.0; set `TRUSTED_PROXIES` if you use an
   authentication proxy. 2FA sharing is off by default.
4. To roll back, restore the backup with the old image; downgrades are not supported upstream.

## 6.1.3-1 — 2026-11-11

### Added
- First release. 2fauth (`2fauth/2fauth:6.1.3`, Docker Hub official image, unmodified)
  packaged as a TOS 7 Docker application, published on port 8040 and running
  as a non-root user (1000:1000).
- Persistent data is kept under `/Volume1/DockerAppData/twofauthdocker/`.
