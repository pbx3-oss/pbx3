# SBC backup & restore — requirements

**Status:** **Active (2026-07-20).** Dump scope locked; **v1 backup + restore scripts** shipped. **Scratch-box restore drill** is the remaining production-gate exercise (host not yet spun).  
**Production gate:** A tested SBC backup/**restore** path is **required before any production fleet** — catalog re-project alone is not enough.  
**Related:** PBX instance pattern (`OPS_S3_RUNBOOK.md`, `backup-manifest.v0.json`, `REBUILD_INSTANCE_RUNBOOK.md`); schema **`sbc-backup-manifest.v0.json`**; tools **`fetch-latest-sbc-backup.sh`**; **`FLEET_TRUNK_PEERING_DECISION.md`** §6.0 (MariaDB current; Litestream **parked**); **`DESIGN_RULES.md`** Rule 1, Rule 13; **`SBC_DATA_RETENTION_REQUIREMENTS.md`** (aging ≠ DR); ops note **`pbx3sbc/docs/SBC_BACKUP_RESTORE.md`**.

## Problem

Each SBC member keeps a **local MariaDB** plus on-box config. Fleet **catalog → edge projection** recovers directory-owned routing (domains, dispatcher, DID projection). It does **not** recover **edge-authored** state (peering/carriers, Fail2ban lists, Filament admins, and other rows that only live on the SBC).

Without a dump + restore runbook, losing an SBC box means re-keying and drift risk. Active–passive HA is **not** the same as cold rebuild/DR.

## Not this project

| Topic | Home |
|-------|------|
| Append-only table **purge** (`acc`, door-knock, failed-reg) | **`SBC_DATA_RETENTION_REQUIREMENTS.md`** (done) |
| Text log / pcap rotate + S3 ship | Log retention Phases 1–4 |
| Litestream / SQLite edge | **Parked** — irrelevant while on MariaDB |
| Instance (PBX) zip → S3 | Already shipped |
| Filament “Create backup” UI / SPA archive browser | Later |
| HA promote automation | Separate from cold restore (see below) |

## Locked decisions (v1)

| Decision | Choice |
|----------|--------|
| **Engine** | **MariaDB** only — single DB **`opensips`** (OpenSIPS + Filament). No Litestream. |
| **Call path** | Cron/CLI only (Rule 1 kinship; Rule 13 edge-owned). |
| **Dump scope** | HoR/config + edge-authored + Filament users + append-only ops; **exclude** hot soft-state (below). |
| **Local artifact** | `/var/lib/pbx3sbc/bkup/sbcbak.{epoch}.zip` |
| **Local retention** | FIFO keep **9** (option C kinship with instance backups). |
| **S3** | `s3://{ORG}/sbc/{PBX3_SBC_ID}/backups/{stamp}/backup.zip` + `manifest.json` + prefix `policy.json` (`maxage_days: 30`) |
| **Tag** | `class=backup` on zip + manifest → lifecycle (ops laptop; see `apply-backup-lifecycle-rule.sh`) |
| **IAM** | Existing `pbx3-sbc-s3-writer.policy.json.tmpl` (`sbc/{id}/*`) — no new shape |
| **Secrets** | Admin `.env` (APP_KEY + DB) rides in the zip (operator artifact). LE certs = **certbot on new host**, not in zip. |
| **HA vs cold** | Cold restore = this DR path. HA promote = warm standby + catalog re-project — **separate drill**, not this zip. |

### MariaDB — include vs exclude

One schema: **`opensips`**.

**Include (must recover):**

| Class | Tables (representative) |
|-------|-------------------------|
| Routing / projection | `domain`, `dispatcher`, `dbaliases`, `version` |
| Peering (edge-authored) | `dr_gateways`, `dr_rules`, `dr_carriers`, `dr_groups`, `registrant` |
| Fail2ban policy | `fail2ban_whitelist`, `fail2ban_blacklist` |
| Filament admin | `users`, `password_reset_tokens` |
| Append-only ops | `acc`, `door_knock_attempts`, `failed_registrations` |
| Other durable | Any remaining non-excluded tables (mysqldump default + ignore-list) |

**Exclude (hot soft-state — recreate at runtime):**

| Table | Why |
|-------|-----|
| `dialog` | Active/recent dialogs — OpenSIPS manages |
| `location` | usrloc — TTL/expires |
| `sessions`, `cache`, `cache_locks` | Laravel ephemeral |
| `jobs`, `job_batches`, `failed_jobs` | Queue soft-state |

Implementation: `mysqldump` with `--ignore-table=opensips.<name>` for each exclude; prefer **root unix_socket** (`sudo mysql` / `mysqldump` as root) on lab — do not require embedding DB passwords in cron env when socket works.

### Filesystem — in zip vs reinstall

| In zip | Reinstall / recreate on new host |
|--------|----------------------------------|
| `/etc/opensips/opensips.cfg` | Package / `install.sh` image |
| `/etc/opensips/.mysql_credentials` (if present) | — |
| pbx3sbc-admin `.env` (lab: `/home/ubuntu/pbx3sbc-admin/.env`) | nginx from `pbx3sbc-admin/deploy/nginx-pbx3sbc-admin.conf` |
| | Let’s Encrypt via certbot (`LE_HTTPS_SBC_ADMIN.md`) |
| | Fail2ban package + sync from restored MySQL whitelist |

### Cold restore posture

1. Build/replace host from image; install OpenSIPS + MariaDB + admin; **do not** run empty `init-database.sh` after restore in a way that wipes data.
2. Fetch zip (`fetch-latest-sbc-backup.sh`) then **`restore-sbc-backup.sh --full --yes`** (imports `opensips.sql` + selective FS).
3. Optional `--restart`; else start MariaDB → OpenSIPS → php-fpm/admin by hand. `certbot` + nginx on new host.
4. Smoke: Filament login; carrier peer / DID path as appropriate.
5. **Catalog reconcile:** check drift; **Apply** projection only for **fleet-owned** mismatches. Do **not** blindly re-project in a way that destroys restored **edge-authored** peers / Fail2ban / hand rows (Rule 13).

**Safe pre-drill on live lab:** `--target-db opensips_restore_test` imports into a side schema only (no FS, no service stop).

**Never** after DB restore: regenerate from empty templates / `init-database` reset that drops restored HoR.

### Scratch restore drill checklist

See **`pbx3sbc/docs/SBC_BACKUP_RESTORE.md`** § Scratch restore drill.  
**Hosts:** local **ARM64** VM (UTM/Parallels — matches Graviton; models on-prem edge SBC) or scratch **`t4g.*` EC2**.  
Lab archive for first drill: `s3://08jzwn-pbx3/sbc/sbc/backups/20260720T172044Z/`.

### HA promote (not this zip)

Active–passive VIP promote uses the standby’s **local** DB (kept warm via projection/rebuild policy) — see **`FLEET_TRUNK_PEERING_DECISION.md`** §6. That is a **failover drill**, not “restore `sbcbak.*.zip` onto the standby.” Cold zip DR is for box loss / rebuild when local DB is gone.

## Product shape (v1 scripts)

Scripts live in **`pbx3sbc/scripts/`** (edge-owned):

| Script | Role |
|--------|------|
| `backup-sbc.sh` | mysqldump → stage → zip → local FIFO; `--dry-run`; `--trigger=` |
| `upload-sbc-backup.sh` | PUT zip + manifest under `sbc/{id}/backups/{stamp}/`; tag `class=backup`; ensure `policy.json` |
| `restore-sbc-backup.sh` | Extract zip → import SQL (+ FS on `--full`); `--dry-run` / `--target-db` / `--yes` / `--restart` |
| `cron.d/pbx3sbc-backup.example` | Daily scheduled create + upload |
| `pbx3-directory/tools/fetch-latest-sbc-backup.sh` | Ops: S3 → `sbcbak.{epoch}.zip` |

Env: reuse `/etc/pbx3sbc/log-ship.env` (`PBX3_ORG_BUCKET`, `PBX3_SBC_ID`, region) — same IAM prefix as log ship.

Manifest: **`schema/sbc-backup-manifest.v0.json`** (`scope: "sbc"`).

Optional later: touch `sbc/{id}/meta.json` → `backup_latest_stamp` (not required for v1 gate of “zip + S3 + manifest”).

## Acceptance (production gate)

- [x] **v1 backup path:** Scheduled/manual backup produces local zip + S3 `backup.zip` + valid manifest (scripts + requirements locked 2026-07-20).
- [x] **v1 restore scripts:** `restore-sbc-backup.sh` + `fetch-latest-sbc-backup.sh`; side-DB integrity testable on live lab.
- [x] **Scratch restore drill (2026-07-20):** amd64 host `192.168.1.55` — install → restore `20260720T172044Z` → OpenSIPS up + Filament Login HTTP 200; counts matched lab (users/domain/gateways). SIP carrier path optional / not required for this gate slice.
- [ ] Catalog reconcile after restore does not blindly destroy restored edge-authored rows (when scratch is fleet-joined — N/A for offline LAN scratch).
- [x] Operator MkDocs page — **`pbx3-docs/docs/fleet/sbc-backup-restore.md`** (Fleet nav; publish with next Pages deploy). Litestream docs stay marked historical.

## Implement order

1. ~~Finish SBC data aging~~ — **done** (WS0–WS4).
2. ~~Lock dump contents + requirements~~ — **this file**.
3. ~~Scripts + cron + S3 upload~~ — backup/upload/cron + lifecycle `sbc/`.
4. ~~Restore scripts + side-DB integrity~~ — `restore-sbc-backup.sh`, fetch tool.
5. **Scratch-box restore drill** + MkDocs page + TODO closeout (next — operator spins host).
