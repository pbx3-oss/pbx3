# PHP `session.upload_progress` stopgap (2026-10)

**Status:** Pre-patch hygiene shipped (homes + SBC admin). Reassess after official PHP/distro advisory.  
**Stack posture:** PBX3 HTTP is **nginx + PHP-FPM** (homes, provision, SBC Filament). Not Apache prefork + mod_php.

## Context

Public research (2026-10) described a `session.upload_progress` / serialize-state UAF class. Corrected write-up: the durable issue is **prefork-only**, memory-safety style (not a confirmed FPM RCE path). Default `session.upload_progress.enabled` is often **On**; PBX3 does not use the feature (Laravel/Sanctum / Filament).

## Stopgap (locked)

Set in PHP-FPM (+ CLI) `conf.d`:

```ini
session.upload_progress.enabled = Off
```

| Surface | Drop-in | Apply |
|---------|---------|--------|
| Home API | `pbx3api/config/php/99-pbx3-uploads.ini` (also package `pbx3` `/opt/pbx3/etc/php/…`) | `install-nginx-site.sh` / `apply-api-upload-limits.sh` |
| SBC admin | `pbx3sbc-admin/deploy/php/99-pbx3sbc-session.ini` | `install.sh` / `scripts/apply-php-session-hardening.sh` |

Harmless for product behaviour. Keep until upstream patches land; then confirm default/advisory and decide whether to keep Off permanently.

## Verify

```bash
php -i | grep session.upload_progress
# expect: session.upload_progress.enabled => Off => Off
```

## Out of scope here

- Downloading or running third-party PoC bundles on lab/fleet.
- Gatekeeper / other PHP hosts — apply the same Off drop-in if desired; not required for this stopgap track.
