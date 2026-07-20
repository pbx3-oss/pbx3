# SBC data & log aging — review project

**Status:** **WS0–WS4 done** (2026-07-20). Lab purge + cron live; Filament **Logs → Data retention**; MkDocs fleet page.  
**Owner:** ops + agent sessions against live lab SBC (`sbc.pbx3.com`).  
**Related:** **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** (Phases 1–6 shipped; Phase 7 = `acc` — now purge-only under this file); **`pbx3sbc/docs/FLEET_LOG_RETENTION.md`** (what already rotates/ships); **`DESIGN_RULES.md`** Rule 1 (telephony independent of S3), Rule 13 (edge-authored); **`SBC_BACKUP_RESTORE_REQUIREMENTS.md`** (DR — separate; after this project).  
**MySQL access:** lab host uses `sudo mysql` (unix_socket); plain `ubuntu` MySQL login fails.

## Goal

Inventory everything that grows on the SBC (MySQL + filesystem + journals), decide **local retention**, **cold export (optional)**, and **purge mechanics** per class — then implement only what we explicitly approve.

This project **supersedes “Phase 7 alone”** as the planning frame: `acc` is one class among several; security event tables (`door_knock_attempts`, `failed_registrations`) are in scope too.

## Already aged (out of decision for v1 — document only)

| Stream | Local | Cold / S3 | Notes |
|--------|-------|-----------|--------|
| OpenSIPS text | logrotate ~**7d** → `/var/log/opensips/opensips.log*` | `sbc/{id}/logs/opensips/…` (ship when enabled) | Phase 3 |
| Host syslog | system logrotate | `sbc/{id}/logs/syslog/…` | OpenSIPS stopped from shared syslog |
| SIP pcap | dumpcap **size/ring** | `sbc/{id}/logs/sip-pcap/…` | Not calendar-only |
| Fail2ban log | host logrotate / journal | not product-shipped | Admin **Logs → Fail2ban log** is live tail only |

Do not redesign these unless lab evidence says the ring/days are wrong.

## Inventory — decisions applied

### A. Append-only MySQL (v1 retention)

| Table | Writer | Admin UI | v1 retention |
|-------|--------|----------|--------------|
| **`acc`** | OpenSIPS CDR | Logs → CDR | **Edge ops only**; local **90d**; **purge-only** (no S3/export v1) |
| **`door_knock_attempts`** | OpenSIPS security | Logs → Door Knock | Local **30d**; **purge-only** |
| **`failed_registrations`** | OpenSIPS | Logs → Failed Registrations | Local **30d**; **same security job** as door-knock; purge-only |

### B. Runtime / state MySQL (usually self-limiting — confirm, don’t blindly purge)

| Table | Role | Aging stance (proposed default) |
|-------|------|----------------------------------|
| **`dialog`** | Active / recent dialogs | OpenSIPS manages; verify no orphan growth in lab |
| **`location`** (usrloc) | Live registrations | TTL / expires — not a retention project |
| **`version`**, module schema meta | Install | Never purge |

### C. Config / HoR MySQL (do **not** age)

| Tables | Role |
|--------|------|
| `domain`, `dispatcher`, `dr_*`, `dbaliases`, `registrant` | Routing / peering HoR |
| `fail2ban_whitelist`, `fail2ban_blacklist` | Operator policy |
| Laravel `users`, `sessions`, `cache`, `jobs`, … | Admin panel |

### D. Filesystem / other (spot-check)

| Path / system | Notes |
|---------------|--------|
| `/var/log/fail2ban.log*` | Confirm logrotate present; optional S3 later |
| Prometheus TSDB (if enabled) | Installer mentioned ~30d — verify on host |
| MySQL binary logs / full DB backups | **Out of this project** — see **`SBC_BACKUP_RESTORE_REQUIREMENTS.md`** (future DR; production gate) |
| nginx / php-fpm / Laravel `storage/logs` | Standard rotate; low SIP value |

## Design principles (non-negotiable unless override)

1. **Never in the SIP call path** — purge/export is cron/CLI only (Rule 1 kinship).
2. **No delete before durable export** when the class is marked “export required”; purge-only classes must be explicit.
3. **Batched, indexed deletes** — small PK ranges; don’t lock `acc` behind OpenSIPS writes.
4. **`--dry-run` first**; lab soak before production cron.
5. **Admin panels** show only locally retained rows; cold archive list/download is optional later.
6. **Edge-authored** — jobs live on SBC (or SBC-admin artisan), not Gatekeeper (Rule 13).

## Lab measurement (do this before picking numbers)

On `sbc.pbx3.com` (read-only first):

```bash
# Row counts + oldest/newest
mysql -N -e "
SELECT 'acc' t, COUNT(*), MIN(time), MAX(time) FROM opensips.acc
UNION ALL
SELECT 'door_knock_attempts', COUNT(*), MIN(attempt_time), MAX(attempt_time) FROM opensips.door_knock_attempts
UNION ALL
SELECT 'failed_registrations', COUNT(*), MIN(attempt_time), MAX(attempt_time) FROM opensips.failed_registrations
UNION ALL
SELECT 'dialog', COUNT(*), NULL, NULL FROM opensips.dialog;
"

# Table sizes
mysql -e "
SELECT table_name, table_rows,
       ROUND(data_length/1024/1024,2) data_mb,
       ROUND(index_length/1024/1024,2) index_mb
FROM information_schema.tables
WHERE table_schema='opensips'
  AND table_name IN ('acc','door_knock_attempts','failed_registrations','dialog','location')
ORDER BY data_length DESC;
"

# Disk for log trees
sudo du -sh /var/log/opensips /var/log/pbx3sbc /var/log/fail2ban.log* 2>/dev/null
```

Record results in § Lab notes below (append dated blocks).

## Decisions recorded (locked 2026-07-20)

- [x] **`acc` product role:** **edge ops only** — not product call history; Asterisk CDR remains HoR for calls. Filament Logs → CDR stays for edge troubleshooting.
- [x] **`acc` local days** / S3 / export: local **90 days**; **no S3**; **purge-only** (no cold CSV v1).
- [x] **`door_knock_attempts`:** local **30 days**; **purge-only**.
- [x] **`failed_registrations`:** local **30 days**; **same job** as door-knock; purge-only.
- [x] **Job shape:** one **security-events** purge job (`door_knock` + `failed_reg`); **separate** `acc` purge job.
- [x] **Cron / batch:** daily **06:15** (host local); batch size **1000** rows per delete.
- [x] **Who runs destructive jobs:** **root cron** → artisan/CLI; **no** Filament-triggered delete in v1.
- [x] **Privacy / CSV:** **N/A v1** (no cold export). If export is added later → **redact** URIs/usernames.

## Workstreams

| WS | Scope | Status |
|----|--------|--------|
| **WS0** | Lab measurement + decision checklist | **Done** 2026-07-20 |
| **WS1** | Security tables purge (`door_knock` + `failed_reg`), 30d, cron 06:15, batch 1000, `--dry-run` | **Lab live** 2026-07-20 |
| **WS2** | `acc` purge-only, 90d (no export v1) | **Lab live** 2026-07-20 (cron 06:20) |
| **WS3** | Admin UI knobs / “last purge” status | **Done** — Logs → Data retention (override JSON; no Filament delete) |
| **WS4** | Docs: MkDocs ops + Phase 7 pointer | **Done** — `pbx3-docs` fleet/sbc-data-retention.md |

### Operator commands (pbx3sbc-admin)

```bash
cd /home/ubuntu/pbx3sbc-admin   # lab path
php artisan pbx3sbc:purge-security-events --dry-run
php artisan pbx3sbc:purge-security-events          # real delete
php artisan pbx3sbc:purge-acc --dry-run
php artisan pbx3sbc:purge-acc

# Enable daily cron (after dry-run OK):
sudo cp deploy/cron.d/pbx3sbc-retention.example /etc/cron.d/pbx3sbc-retention
sudo chmod 644 /etc/cron.d/pbx3sbc-retention
```

Env knobs: `PBX3_SBC_SECURITY_EVENTS_LOCAL_DAYS` (30), `PBX3_SBC_ACC_LOCAL_DAYS` (90), `PBX3_SBC_PURGE_BATCH_SIZE` (1000).  
UI override: Filament **Logs → Data retention** → `storage/app/pbx3-retention-override.json`.  
MkDocs: **`pbx3-docs/docs/fleet/sbc-data-retention.md`**.

## Out of scope (this project)

- Instance Asterisk CDR / SQLite aging (already Phase 6 + retention knobs).
- Changing Fail2ban jail thresholds.
- HEP/Homer, RTP capture.
- Deleting config/HoR rows.

## Lab notes

<!-- Append dated measurement dumps here -->

### 2026-07-20 — `sbc.pbx3.com` (read-only)

**Host:** root **6.8G**, **5.3G used (79%)**, **1.5G free**. Hot filesystem consumers: `/var/log` **1.3G** (journal **639M**, `syslog.1` **389M**, `pbx3sbc` **124M**, `opensips` **106M**), `/var/lib` **938M** (MySQL **138M** total / `opensips` datadir **13M**, Prometheus **101M**). Fail2ban logrotate present; live + 4 rotated files (~tiny).

**Append-only MySQL** (`sudo mysql`):

| Table | Rows | Oldest | Newest | data_mb | index_mb |
|-------|------|--------|--------|---------|----------|
| `door_knock_attempts` | **4703** | 2026-01-28 22:32 | 2026-07-20 12:49 | 1.52 | 0.59 |
| `failed_registrations` | **737** | 2026-01-28 23:45 | 2026-07-09 21:41 | 0.11 | 0.13 |
| `acc` | **105** | 2026-01-29 00:09 | 2026-07-20 00:51 | 0.08 | 0.02 |

**Windows:** door-knock **339 / 7d**, **3157 / 30d**; failed-reg **0 / 7d**, **37 / 30d**; `acc` **17 / 7d**, **97 / 30d**.

**Runtime:** `dialog` **0** rows; `location` **12** (expires present — looks self-limiting).

**Takeaways (lab):** MySQL tables are **not** the disk crisis yet — journal/syslog + product log trees dominate. Under scanners, **`door_knock_attempts` is the clear MySQL growth leader** (~10× `failed_registrations`, ~45× `acc`). `acc` stays tiny at lab traffic; production fleet volume will change the absolute numbers but not the “edge CDR ≠ Asterisk CDR” product split. Security purge (WS1) is the highest-value first implement after decisions; `acc` (WS2) can wait on HoR/export choices without blocking disk relief from security tables.

### 2026-07-20 — first purge + cron (lab)

Surgical deploy of Retention services + `routes/console.php` + cron example (dirty tree; no wholesale pull).

| Table | Deleted | Remaining | Oldest after |
|-------|---------|-----------|--------------|
| `door_knock_attempts` | 1546 | 3158 | 2026-07-08 |
| `failed_registrations` | 700 | 37 | 2026-07-09 |
| `acc` | 8 | 99 | 2026-07-09 |

Cron: `/etc/cron.d/pbx3sbc-retention` (06:15 security, 06:20 acc).

## Pointers for implementers

- Schema create: **`pbx3sbc/scripts/init-database.sh`** (`failed_registrations`, `door_knock_attempts`).
- Filament models: **`pbx3sbc-admin/app/Models/{Cdr,DoorKnockAttempt,FailedRegistration}.php`**.
- Purge: **`pbx3sbc-admin/app/Services/Retention/*`**, artisan `pbx3sbc:purge-security-events` / `pbx3sbc:purge-acc`, cron **`deploy/cron.d/pbx3sbc-retention.example`**.
- Existing Phase 7 sketch: **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** § Phase 7 — keep in sync; this file is the broader project home.
