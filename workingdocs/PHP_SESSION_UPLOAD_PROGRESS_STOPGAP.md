# PHP critical RCE — CVE-2026-109618 / CVE-2026-109619 (2026-10)

**Status:** Official advisory live ([php.net](https://www.php.net/), 21 Oct 2026). Stopgap `upload_progress=Off` shipped earlier same day; **upgrade is the only complete fix**.  
**Stack posture:** PBX3 HTTP is **nginx + PHP-FPM** (homes, provision, SBC Filament, Gatekeeper). php.net rates **PHP-FPM in scope** (highest risk still mod_php).

## Advisory (product read)

Two critical unauthenticated RCEs (CVSS v4.0 **9.2**):

| CVE | Summary | Official interim mitigations (incomplete) |
|-----|---------|-------------------------------------------|
| **CVE-2026-109618** | RCE via OOM corruption (partially initialized request data) | Prefer no finite `memory_limit` override path; keep `post_max_size` low; edge multipart limits. Do **not** treat as safe without upgrade. |
| **CVE-2026-109619** | RCE via stale global state across worker requests | `session.upload_progress.enabled=0` + restart workers; other variants may remain. |

**Fixed upstream:** PHP **8.5.12 / 8.4.27 / 8.3.36 / 8.2.35**.  
**Ubuntu 24.04 (noble) stock `php8.3`:** security rebuild **`8.3.6-0ubuntu0.24.04.13`** (Ubuntu CVE tracker — not the upstream 8.3.36 number).  
**ondrej/php PPA:** **8.3.36** / **8.4.27** packages published for noble.

There are **no complete mitigations**; update is the only safe choice (php.net).

## PBX3 stopgap already shipped (keep)

Set in PHP-FPM (+ CLI) `conf.d` (blocks the confirmed **109619** session path only):

```ini
session.upload_progress.enabled = Off
```

| Surface | Drop-in | Apply |
|---------|---------|--------|
| Home API | `pbx3api/config/php/99-pbx3-uploads.ini` (also package `pbx3` `/opt/pbx3/etc/php/…`) | `install-nginx-site.sh` / `apply-api-upload-limits.sh` |
| SBC admin | `pbx3sbc-admin/deploy/php/99-pbx3sbc-session.ini` | `install.sh` / `scripts/apply-php-session-hardening.sh` |
| Gatekeeper | same Off one-liner in FPM `conf.d` | ops tip (no product drop-in yet) |

Keep Off after upgrade (harmless; Laravel/Filament unused) unless a future reason appears.

**Do not** set fleet-wide `memory_limit=-1` as a substitute for upgrade — conflicts with upload/runaway control on API hosts. Prefer package roll.

## Roll plan (ops)

1. **Homes / control on Ubuntu stock `php8.3`:** `apt update && apt install --only-upgrade 'php8.3-*'` → expect **`8.3.6-0ubuntu0.24.04.13`**; reload `php8.3-fpm`.
2. **SBC (ondrej `php8.4`):** `apt update && apt install --only-upgrade 'php8.4-*'` → expect **`8.4.27-…+deb.sury.org+1`**; reload `php8.4-fpm`.
3. **Optional fast-path to upstream numbers:** add `ppa:ondrej/php` on stock homes for **8.3.36** — not required if Ubuntu **`.13`** is installed; lock before changing home package source fleet-wide.
4. Verify: `php -v` + `systemctl is-active php*-fpm` + SPA/Filament `/up` or login smoke.
5. Tip inventory: **`~/GiT/pbx3-ops/TODO_OPS.md`**.

## Verify stopgap

```bash
php -i | grep session.upload_progress
# expect: session.upload_progress.enabled => Off => Off
```

## Out of scope

- Third-party PoC bundles on lab/fleet.
- Lowering home `post_max_size` below the MOH/backup **55M** floor without a product decision (php.net suggests ≤32M for upload apps as mitigation only).
