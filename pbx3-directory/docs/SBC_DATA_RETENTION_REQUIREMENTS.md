# SBC data & log aging — review project

**Status:** Review kickoff (2026-07-20). **No purge/export implementation until decisions are recorded here.**  
**Owner:** ops + agent sessions against live lab SBC (`sbc.pbx3.com`).  
**Related:** **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** (Phases 1–6 shipped; Phase 7 = `acc` proposal only); **`pbx3sbc/docs/FLEET_LOG_RETENTION.md`** (what already rotates/ships); **`DESIGN_RULES.md`** Rule 1 (telephony independent of S3), Rule 13 (edge-authored).

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

## Inventory — needs a decision

### A. Append-only MySQL (grows forever today)

| Table | Writer | Admin UI | PII / sensitivity | Suggested review questions |
|-------|--------|----------|-------------------|----------------------------|
| **`acc`** | OpenSIPS CDR | Logs → CDR | Call-ID, From/To URI, timing | Product HoR vs Asterisk CDR? Local days? Export before purge? (**former Phase 7**) |
| **`door_knock_attempts`** | OpenSIPS security xlog/SQL | Logs → Door Knock | source IP, UA, RURI, domain | Hot window for Fail2ban forensics? Purge-only vs export? |
| **`failed_registrations`** | OpenSIPS | Logs → Failed Registrations | username, source IP, UA | Align with door-knock? Same job? |

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
| MySQL binary logs / backups | Ops concern; separate from app-table purge |
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

## Decisions to record (checklist)

Fill in before any implement session:

- [ ] **`acc` product role:** edge ops only vs product call history vs both (with Asterisk)
- [ ] **`acc` local days** / S3 days / export-mandatory?
- [ ] **`door_knock_attempts` local days** (e.g. 7 / 30 / 90) / export?
- [ ] **`failed_registrations` local days** / same job as door-knock?
- [ ] Shared **security-events** purge job vs separate from CDR?
- [ ] Cron window (e.g. daily 06:xx) and batch size defaults
- [ ] Who may run destructive jobs (root cron vs Filament-triggered — prefer root cron)
- [ ] Privacy: redact URIs/usernames in any cold CSV?

## Proposed workstreams (after decisions)

| WS | Scope | Depends on |
|----|--------|------------|
| **WS0** | Lab measurement + fill decision checklist | — |
| **WS1** | Security tables purge (`door_knock` + `failed_reg`) — likely simplest, high growth under scanners | WS0 |
| **WS2** | `acc` export + purge (ex–Phase 7) | WS0 + CDR HoR decision |
| **WS3** | Admin UI knobs / “last purge” status (optional) | WS1/WS2 |
| **WS4** | Docs: MkDocs ops + update Phase 7 pointer to this file | WS1/WS2 |

## Out of scope (this project)

- Instance Asterisk CDR / SQLite aging (already Phase 6 + retention knobs).
- Changing Fail2ban jail thresholds.
- HEP/Homer, RTP capture.
- Deleting config/HoR rows.

## Lab notes

<!-- Append dated measurement dumps here -->

_(none yet — run § Lab measurement on next session)_

## Pointers for implementers

- Schema create: **`pbx3sbc/scripts/init-database.sh`** (`failed_registrations`, `door_knock_attempts`).
- Filament models: **`pbx3sbc-admin/app/Models/{Cdr,DoorKnockAttempt,FailedRegistration}.php`**.
- Existing Phase 7 sketch: **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** § Phase 7 — keep in sync; this file is the broader project home.
