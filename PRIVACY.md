# Privacy Policy — 2fauth for TerraMaster TOS (`twofauthdocker`)

**Last updated:** 22 November 2026

**Data controller / contact:** Moechz — moechz@163.com

**Public copy of this policy:** <https://github.com/Moechz/2fauth/blob/main/PRIVACY.md>
(also linked from the application's `help` field)

This policy covers the TOS application `twofauthdocker` (the “app”), its packaging, and the
data the app processes when it runs as a container on your TerraMaster NAS. It does not cover
the TOS operating system, the Docker engine, or the NAS itself; those are governed by their
own documentation and by the NAS administrator.

## 1. Summary

- The app is **self-hosted**. Your accounts, TOTP secrets, users, icons and logs are stored
  on your NAS. **The developer operates no server in this path and has no access to your
  data.**
- There is **no telemetry, no analytics, no advertising, no crash reporting and no developer
  account**. The developer does not receive your data.
- A few features make ordinary outbound HTTP requests (account icons, a release check, the
  Docker image pull, and anything **you** configure such as SSO or SMTP). These are listed
  in §8, with the data they send and how to turn them off.
- The app can store the **TOTP/HOTP/Steam shared secrets** that generate your one-time
  codes. Those secrets are the most sensitive data in the app; §4 explains exactly how they
  are stored and the optional encryption that protects them.

## 2. What data the app stores

All paths below are container paths; the persistent volume is mapped to
`/Volume1/DockerAppData/twofauthdocker/storage` on the NAS (see §3).

| Data | Where | Why |
|---|---|---|
| **2FA account data**: service name, account/login name, **TOTP/HOTP/Steam secret**, `otpauth://` URI, OTP type, algorithm, digits, period/counter, group, icon filename, order/favourite flags | SQLite table `twofaccounts` (and `icons` when icons are stored in the database) | To generate your one-time codes and display your accounts |
| Groups | SQLite table `groups` and assignment tables | Organise accounts |
| **User account**: name, e-mail address, password hash, optional OAuth/SSO identifier and provider, administrator flag, preferences (theme, language, icon settings, notification choices), last-seen time | SQLite table `users` | Sign-in, authorisation, UI preferences |
| **WebAuthn credentials**: credential ID, public key, signature counter, user-supplied label, timestamps | SQLite table `webauthn_credentials` | Optional passwordless / second-factor login. The private key and any biometric data stay on your authenticator; the server never receives them |
| Authentication log: IP address, user agent, login/logout time, success flag, guard and login method, user ID | SQLite table `auth_logs` | Security audit trail shown in the UI |
| **OTP generation log** (2FAuth 7.0+): requester and owner user IDs/names/e-mails, account ID, IP address, OTP type, HOTP counter, timestamp. **The generated code itself is never logged.** | SQLite table `otp_logs` | Audit trail for shared/team use |
| Personal access tokens (API): hashed token, abilities, expiry | SQLite table `personal_access_tokens` | API access that you create |
| OAuth/Passport keys: private and public key | `storage/oauth-private.key`, `storage/oauth-public.key` | Sign Laravel Passport tokens |
| **APP_KEY** (32 random bytes) | `storage/app_key` (mode 600) | Laravel encryption/signing; see §4 |
| Application logs | `storage/logs/laravel.log*` | Diagnostics; see §7 |
| Sessions and framework cache | `storage/framework/*` | Keep you signed in, CSRF protection, compiled views |
| Icons, cached icon-library files, remote image links, icon packs, temporary files | `storage/app/public/icons`, `storage/app/logos`, `storage/app/imagesLink`, `storage/app/iconPacks`, `storage/app/temp` | Display account icons |
| Installation marker (upstream commit) | `storage/installed` | Decide whether first-run tasks are needed |

The app does **not** collect: advertising identifiers, device fingerprints, location data,
contacts, calendar data, analytics events, crash dumps, or the contents of your screen. It
does not read files outside its own application data folder.

## 3. Where the data is stored

- Everything persistent is below the application data folder
  `/Volume1/DockerAppData/twofauthdocker/storage` (mounted at `/2fauth/storage`), inside the
  SQLite database `database.sqlite`, the `app_key` file, the OAuth keys, the icon folders and
  the logs.
- The developer does not receive a copy and operates no backup or sync service.
- Container-internal paths such as `/tmp`, `/srv`, `/run` are ephemeral and are discarded
  when the container is recreated, except where they are symlinked to the storage volume.
- Docker and the TOS App Center may keep the container's stdout/stderr log on the NAS
  according to their own settings; the developer cannot read it.

## 4. Encryption and keys (including the 2FA secrets)

**APP_KEY.** On first start the package generates 32 random bytes and stores them as
`storage/app_key` with mode 600. Laravel uses this key with **AES-256-CBC** for encryption and
for signing. The key is unique per installation and is passed to the app as the `APP_KEY`
environment variable. **Back it up together with the database.** If `app_key` is lost or
replaced, data that was encrypted with it cannot be decrypted (2FAuth marks such accounts as
indecipherable); there is no recovery service.

**Optional field-level encryption (important).** 2FAuth's database-field encryption is a
setting, and it is **OFF by default** in upstream 2FAuth. It can be enabled in
**Admin → App Setup → “Encrypt sensitive data”** (`useEncryption`). When it is ON, 2FAuth
encrypts the `service`, `account`, `secret` and `legacy_uri` fields of `twofaccounts`, and
stored icon contents, with `APP_KEY` using AES-256-CBC. When it is OFF, those values —
**including the TOTP seeds** — are stored as plain text inside the SQLite file. This package
does not silently flip that setting on upgrade, because enabling it rewrites existing rows and
must be done with a verified backup and a saved `app_key`. **Recommendation:** after the first
setup, back up `storage/` and `app_key`, then enable “Encrypt sensitive data”.

**Other protections.** User passwords are stored as one-way hashes (Laravel's `hashed` cast,
bcrypt/Argon2). Personal access tokens are stored hashed. WebAuthn private keys never leave
your authenticator; the server stores only the public key, credential ID and counter. The
Passport private key is stored with owner-only permissions.

**Transport and at-rest limits.** The package serves plain HTTP on the LAN. If you expose the
UI beyond the LAN, terminate TLS in a reverse proxy and keep the proxy patched. WebAuthn and
camera-based QR scanning require a secure browser context (HTTPS, or `localhost` on the same
machine); over plain HTTP on a LAN use password login and manual secret entry. The SQLite
file itself is not encrypted when field encryption is off; protect it with NAS volume
permissions, snapshots and, ideally, disk/volume encryption.

## 5. WebAuthn (security keys, passkeys, platform authenticators)

WebAuthn is optional. When you register a device, 2FAuth stores the credential's public key,
credential ID, signature counter and the label you choose. The private key and any biometric
template remain in your authenticator or platform; they are never sent to the NAS or to the
developer. Authentication is verified locally by the browser and the server, with the
relying-party ID derived from the URL you use. WebAuthn requires HTTPS (a secure context);
plain HTTP on a LAN is not sufficient, except for `localhost` on the NAS itself. If you lose
the device, use the recovery flow configured in the app (for example a recovery e-mail) or an
administrator account; recovery e-mails are sent only through the mail settings **you**
configure.

## 6. Backup, export, migration and deletion

- **Export from the UI:** 2FAuth can export accounts as its JSON format, `otpauth://` URIs or
  QR codes. **Exports contain the TOTP secrets in readable form** — store them encrypted, and
  delete them when no longer needed.
- **Full backup:** stop the container, then copy the whole
  `/Volume1/DockerAppData/twofauthdocker/storage` folder (database, `app_key`, OAuth keys,
  icons and logs). Keep the database and `app_key` together, otherwise encrypted fields cannot
  be restored.
- **Restore:** copy the folder back before starting the same or a newer version. Downgrades
  are not supported; keep the backup made before an upgrade.
- **Upgrade:** database migrations run automatically on first start of the new image. Back up
  first. Upgrading from a version before 8.0 invalidates personal access tokens created
  earlier (upstream breaking change) — re-create them in the UI. If you use an authentication
  proxy, set `TRUSTED_PROXIES` as required by 2FAuth 8.0+.
- **Uninstall:** uninstalling with “delete data” (or deleting the folder after stopping the
  container) removes the database, `app_key`, OAuth keys, icons and logs. Uninstalling without
  deleting the data leaves the folder on the NAS.

## 7. Logs

- **Application log:** `storage/logs/laravel.log*`. Laravel's `daily` channel keeps 7 days by
  default. This package sets `LOG_LEVEL=warning`, so the info/notice messages in which upstream
  2FAuth records login e-mail addresses and client IPs are not written during normal operation.
  Warnings and errors can still contain user IDs, IP addresses, file paths and exception
  messages. The app does not intentionally log TOTP codes, passwords, `APP_KEY` or OAuth client
  secrets.
- **First start:** upstream's `passport:install` prints OAuth client secrets to stdout. This
  package runs that step once with its output redirected to a temporary file that is deleted
  immediately, so those secrets do not appear in `docker logs`.
- **Container log (stdout/stderr):** the entrypoint messages and the nginx access log. They can
  contain client IP addresses, request paths, status codes and user agents. A WebAuthn
  recovery link contains a one-time token in its query string; if such a link is opened, the
  token can appear in the access log. Treat container logs as confidential and do not post them
  publicly. Docker/TOS controls their rotation and retention; the app does not upload them.
- The app keeps its own audit trail in the database (`auth_logs`, `otp_logs`) as described in
  §2 and §9; that is separate from the text logs.

## 8. Network requests and third-party services

The app is local-first and has **no developer-operated endpoint, no analytics and no
third-party SDK**. The requests below are the complete set of outbound connections the
application makes on its own; the NAS (not your browser) is the client for the first two, so
the NAS's IP address is visible to those services, not your browser's.

| When | Endpoint | Data sent | Recipient / region | How to turn it off |
|---|---|---|---|---|
| Account icon lookup (on by default) | `cdn.jsdelivr.net` — the `selfhst/icons` and `homarr-labs/dashboard-icons` collections | A slug derived from the account's **service name** (e.g. `github`), plus normal HTTP metadata (IP, user agent) | jsDelivr CDN (global; operated from the US/EU) | Admin → App Setup → turn off “Get official icons”, or set the icon source to “none”; you can also upload icons locally |
| Icon directory (only with the TFA icon library) | `2fa.directory/api/v3/tfa.json`, then `raw.githubusercontent.com/2factorauth/twofactorauth` | A cached directory download, then an icon path derived from the service name | 2FA Directory / GitHub (US) | Choose a different icon source, or disable official icons |
| Release check (on by default, at most once a week when the UI is opened) | `https://api.github.com/repos/Bubka/2FAuth/releases/latest` | A plain HTTP request (IP, user agent); **no app data, no account data** | GitHub (US) | Admin → App Setup → turn off “Check for updates” |
| Image pull / update | `registry-1.docker.io` (or your configured registry mirror) | An anonymous image pull; Docker Hub sees the NAS IP and the requested tag | Docker Hub (US) or your mirror | Managed by TOS/Docker; use a mirror or pre-pull the image |
| SSO you enable (optional) | The OIDC issuer or GitHub OAuth endpoints **you** configure | The authentication data the provider requires (typically e-mail/profile) | The provider you chose | Leave SSO disabled (default) |
| E-mail you configure (optional) | The SMTP server **you** configure | Notification e-mails (new-device/login alerts, WebAuthn recovery) to your users | Your mail provider | Leave `MAIL_MAILER=log` (the upstream default) or do not configure SMTP |
| Remote image link you paste (optional) | The URL **you** enter for an account icon | An HTTP GET for that image; the app's SSRF guard blocks private/loopback/link-local destinations | The destination you chose | Do not use the “image link” feature |
| Authentication/reverse proxy (optional) | Your own proxy | The headers your proxy is configured to pass | Your infrastructure | Do not enable reverse-proxy authentication |

The developer does not sell, rent or share data with advertisers or data brokers. There is no
third-party analytics, tracking pixel or advertising identifier in the app.

## 9. Retention periods

| Data | Retention |
|---|---|
| Accounts, secrets, groups, users, icons, WebAuthn credentials, APP_KEY, OAuth keys | Until **you** delete them; no automatic expiry. Kept across restarts and upgrades. Removed when you uninstall with data removal or delete the folder |
| Authentication log (`auth_logs`) | Configured retention **365 days** by default (`AUTHENTICATION_LOG_RETENTION`). Entries older than the configured period are deleted when the authentication log is viewed (the app runs the purge then) or when you purge manually; until then they remain in the database |
| OTP generation log (`otp_logs`) | Configured retention **365 days** by default (`OTP_LOG_RETENTION`), purged when the OTP log is viewed or manually. The generated codes are never stored |
| Laravel application log | 7 daily files by default (`LOG_DAILY_DAYS`), then deleted by Laravel |
| Container stdout/stderr log | Controlled by Docker/TOS, not by the app; delete/recreate the container to clear it |
| Backups and exports | Controlled by you; the developer has no copy |
| `moechz.com` website logs | Short-lived operational logs for the documentation site; not used for profiling and not linked to app data |

## 10. Your rights and the deletion channel

Because the app is self-hosted, most requests are self-service:

| Right | How |
|---|---|
| **Access / export** | Use the app's export (JSON / `otpauth://` / QR) and copy the data folder. The folder is the complete state |
| **Correct** | Edit accounts, users, groups and preferences in the web UI |
| **Delete** | Delete individual accounts/groups/logs in the UI; uninstall with “delete data”; or stop the container and remove `/Volume1/DockerAppData/twofauthdocker/` |
| **Restrict / object** | Disable icon lookup, release checks, SSO and mail; run the app without exposing it to the internet |
| **Portability** | JSON and `otpauth://` export |
| **Assistance / complaints** | E-mail **moechz@163.com** with the subject “2fauth privacy request”. A reply follows within 30 days. The developer holds no copy of your data, so deletion is normally completed on your own NAS |

Deletion is immediate on the NAS once you confirm it; the developer cannot delete data it does
not hold. If you e-mail a request about the documentation website or the publishing records,
the developer will handle it under the same 30-day window.

## 11. Security measures

- The container runs as **uid/gid 1000**, never root; no `privileged`, no `cap_add`, no host
  network, no Docker socket, one published port, a health check and a pinned image tag.
- The image is the official 2FAuth image, used unmodified; the package only adds the wrapper
  that prepares the storage volume and forwards the stop signal.
- `APP_KEY` and the OAuth private key are created per installation with owner-only
  permissions. Passwords are hashed; personal access tokens are hashed; WebAuthn private keys
  never leave the authenticator.
- Optional field-level encryption (§4) protects the 2FA secrets if the database file leaks;
  enable it after backing up `app_key`.
- Upstream 2FAuth applies a Content-Security-Policy, validates WebAuthn origins, and applies
  SSRF guards to remote icon/image fetching. Keep the package updated to receive upstream
  security fixes; this release moves to 9.0.2, which fixes CVE-2026-109618, CVE-2026-109619,
  CVE-2026-123007, CVE-2026-123633 and several GHSA advisories.
- **Residual risks:** the package speaks HTTP on the LAN; the SQLite file is not encrypted at
  rest unless you enable field encryption or volume encryption; a NAS administrator can read
  the data folder. For internet exposure, use a TLS reverse proxy, strong accounts, and
  network access controls.

## 12. Children

The app is a self-hosted utility for administering your own accounts and is not directed at
children. The developer does not knowingly collect data from children (the developer collects
no app data at all).

## 13. Changes to this policy

Material changes are published in this file, in the repository and in the release notes, and
the “Last updated” date is revised. The version of the policy that applies to your installed
package is the one shipped with that release and linked from its `help` field.

## 14. Contact

**Moechz** — moechz@163.com — <https://www.moechz.com/>
Issues and questions: <https://github.com/Moechz/2fauth/issues>
