# Fleet / node — log retention & SIP capture (requirements)

**Status:** **Phases 1–6 complete (2026-07-17)** — ship/lifecycle/siplog/SBC/control (1–4); SPA retention knobs + S3 archive list/download (5); Asterisk `cdr_sqlite3_custom` + `GET /cdr` + SPA `/cdr` (6). Phase 7 / SBC MySQL aging planning lives in **`SBC_DATA_RETENTION_REQUIREMENTS.md`** (kickoff 2026-07-20).  
**MVP (when prioritized):** Local hot store (~7 days) + async offload of **rotated** files to S3 cold store by class; SIP-only pcap ring on the **SBC**; instance `sys-ua-siplog` **solo only** (disabled in fleet).  
**Related:** **`SBC_DATA_RETENTION_REQUIREMENTS.md`** (SBC MySQL + logs aging review); **`DESIGN_RULES.md`** Rule 1 (telephony independent of directory/S3), Rule 6 (solo without S3); **`OPS_S3_RUNBOOK.md`** §15 / backups + **`RECORDINGS_STORAGE_DESIGN.md`** (async upload cousins); **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`** (instance detection; Gatekeeper delivery); **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** (ops-events SMTP); pbx3api **`LogController`** (local log read) + **`CdrController`** (SQLite search); instance **`sys-ua-siplog`** (`dumpcap` carousel); SBC OpenSIPS **`acc`** (MySQL CDR).

---

## Problem

Operators need a week of logs on each box for live troubleshooting, and longer retention without filling disks. Today rotation is uneven (`Master.csv` grows as one file; siplog is a local carousel; OpenSIPS/syslog rely on host defaults). There is **no** fleet-wide offload of syslog, Asterisk messages/CDRs, or SBC SIP capture to S3.

Fleet stance: **all phones terminate on the SBC** — no direct SIP to instances. Instance SIP pcaps therefore only see SBC↔Asterisk and are misleading as a product “SIP archive” in fleet mode.

---

## Design stance (settled)

| Topic | Choice |
|-------|--------|
| **Model** | **Local hot (~7d) → async upload of rotated files → S3 cold → lifecycle expire** |
| **Call path** | Log offload is **not** in the call path (**Rule 1**). Telephony and local log read work if S3 is down |
| **Solo / singleton** | Local retention only until fleet/S3 opted in (**Rule 6**) |
| **Ship what** | **Rotated** chunks only — never a live open file (especially CDR `Master.csv`) |
| **Bucket** | **Org fleet bucket** (same family as backups/catalog) — **not** the recordings bucket |
| **CDR vs other logs** | Separate lifecycle class; default **2 months** S3 vs **1 month** for syslog/messages |
| **Instance CDR store** | **CSV** = archive / S3 cold; **SQLite on the instance** = searchable HoR for panels (no MySQL CDR warehouse). Dual-write OK; see § CDR |
| **SBC CDR store** | Already **MySQL `acc`** (`do_accounting("db", "cdr")`) — keep; not replaced by CSV. Edge legs ≠ instance Asterisk CDR |
| **SIP product capture** | **SBC** — SIP-only pcap (no RTP), dumpcap ring like instance siplog |
| **Instance `sys-ua-siplog`** | Keep for **singleton**; **disabled by default in fleet** |
| **Supervisor on SBC** | Same **dumpcap** mechanics as `sys-ua-siplog`; **not** required to use runit — prefer systemd / host-native |
| **SPA over S3** | Phase 5: **list + download** on System Logs (presigned/`temporaryUrl`); not in-browser grep. Hot local = existing `LogController` tail (or SSH for `tail -f`) |

```mermaid
flowchart LR
  rotate["logrotate / dumpcap ring"] --> local["Local hot store ~7d"]
  local --> upload["Async upload rotated files"]
  upload --> s3["S3 cold store by class"]
  s3 --> lifecycle["S3 lifecycle expire"]
```

---

## Per-node inventory

### Instance (pbx3 + Asterisk + pbx3api)

| Stream | Path / source | Notes |
|--------|---------------|--------|
| **syslog family** | `/var/log/syslog`, and typically `auth.log`, `mail.log`, `fail2ban.log` unless split out | Per-instance local/S3 days configurable |
| **Asterisk messages** | `/var/log/asterisk/messages` | Ops notify REGISTER scanner reads this; keep local readable |
| **Asterisk CDR CSV** | `/var/log/asterisk/cdr-csv/Master.csv` | Archive / S3; must **rotate by day/size** before “7 days” is meaningful |
| **Asterisk CDR SQLite** | `/var/log/asterisk/master.db` via **`cdr_sqlite3_custom`** | Searchable HoR (`GET /cdr`, SPA `/cdr`); CSV still archive/S3 |
| **queue_log** (optional sibling) | `/var/log/asterisk/queue_log` | Call-center tenants; same local/S3 pattern when prioritized |
| **`sys-ua-siplog`** | `dumpcap` → `SIPLOG` carousel (`logsipnumfiles` / `logsipfilesize`) | **Solo on**; **fleet off** by default |

### SBC (OpenSIPS edge)

| Stream | Path / source | Notes |
|--------|---------------|--------|
| **OpenSIPS text** | `/var/log/opensips/opensips.log` via **rsyslog split** (`programname == opensips`, `stop` — not shared syslog) | Cheap always-on; ship `class=opensips`. Lab Fail2ban uses journal, not this file |
| **OpenSIPS CDR (`acc`)** | MySQL `acc` via `acc` module CDR mode | Already live; Filament CDR panel. Retention/purge separate from text-log S3 |
| **syslog family** | Host syslog / auth / fail2ban | Same 7d / 1mo defaults |
| **SIP pcap** | dumpcap ring, SIP ports only (e.g. 5060/5061), **no RTP** | Product SIP archive; ring by filesize × files |

### Control (Gatekeeper host)

| Stream | Path / source | Notes |
|--------|---------------|--------|
| **syslog / nginx / gatekeeper** | Host + app logs | Low volume; same 7d local / 1mo S3 pattern |

---

## Retention defaults

| Stream | Where | Local | S3 | Configurability |
|--------|--------|-------|-----|-----------------|
| syslog (+ auth/mail/fail2ban as syslog-family unless called out) | Instance, SBC, control | **7 days** | **1 month** | **Per-instance** for instance syslog |
| Asterisk `messages` | Instance | **7 days** | **1 month** | Instance (may share panel with syslog) |
| Asterisk CDR CSV | Instance | **7 days** | **2 months** | **Org/fleet default** + optional instance override |
| OpenSIPS text | SBC | **7 days** | **1 month** | SBC / fleet |
| SIP pcap (SIP-only) | **SBC** | dumpcap ring + ~**7 days** of completed segments | **~1 month** (shorten if cost) | Ring size configurable (filesize × files), like instance `logsip*` |
| Instance `sys-ua-siplog` | Instance | Solo: existing carousel | Solo optional | Existing `logsip*` globals; **fleet flag off** |

CDR is PII (CLI, dialled numbers) — private prefix, SSE, no catalog bleed. Prefer consistent fleet CDR retention; instance override is for disk/compliance exceptions, not day-to-day drift.

---

## CDR (settled 2026-07-17)

### Two different CDR planes

| Plane | Store today / target | What it records |
|-------|----------------------|-----------------|
| **SBC (edge)** | **MySQL `acc`** — OpenSIPS `do_accounting("db", "cdr")`; Filament **CDR** reads it | SIP legs at the edge (Call-ID, From/To URI, duration, setup) |
| **Instance (Asterisk)** | **CSV** `Master.csv` today (LogController download); **SQLite on-node** when searchable CDR is prioritized | Dialplan truth: billsec, disposition, extension/tenant context |

Do **not** treat SBC `acc` as a substitute for instance Asterisk CDR (or the reverse). Keep both.

### Instance: searchable without a big DB

| Role | Format | Why |
|------|--------|-----|
| **Search / panels / velocity input** | **SQLite on the instance** | Indexed queries; no MySQL to manage; works solo (**Rule 6**) |
| **Cold archive / S3** | **Rotated CSV** (or periodic dump of the same rows) | Simple offload; matches retention R1–R2; no live open file |

- Dual-write (Asterisk → SQLite + CSV) is fine; pick **SQLite as search HoR** and **CSV (or dump) as archive format**.
- **Do not** introduce a fleet-central CDR warehouse or instance MySQL just for CDR.
- SQLite purge/retention should align with local ~7d hot + whatever remains needed for in-panel search; cold history lives on S3 CSV.

### SBC `acc` retention

Text-log / pcap S3 offload does **not** replace `acc`. When prioritized: purge or archive old `acc` rows (local retention + optional export) under the same privacy rules as instance CDR. Product log-retention v1 can ship instance CSV→S3 before `acc` archive is designed.

## Phase 7 — SBC `acc` retention / cold export (**part of SBC data aging review**)

**Status:** **Purge-only v1 shipped** in **pbx3sbc-admin** (`pbx3sbc:purge-acc`, 90d, edge ops only) — planning home **`SBC_DATA_RETENTION_REQUIREMENTS.md`**. Cold CSV/S3 export from the list below is **deferred** (not required for v1).

### Why this may be needed

OpenSIPS writes edge CDR rows to MySQL `acc`, and the SBC Admin CDR panel reads them. Those rows currently persist indefinitely. This is distinct from instance Asterisk CDR: SBC `acc` describes SIP edge legs, while Asterisk records dialplan/billing truth. Phase 7 would bound SBC database and PII growth without treating either plane as a replacement for the other.

### Shipped (purge-only)

- Decisions: edge ops only; local **90d**; no S3 export v1; batched DELETE; root cron 06:20.
- Command: `php artisan pbx3sbc:purge-acc [--dry-run] [--days=] [--batch=]`.

### Deferred (cold export — optional later)

1. Export eligible `acc` rows to a versioned, compressed CSV before purge (manifest + checksum).
2. Upload under `sbc/{sbc-id}/logs/cdr/{stamp}/…`.
3. Never delete before durable export when export-mandatory policy is chosen.
4. Optional Admin cold-archive list/download.

### Velocity (pointer)

Toll-fraud / call-pattern **detection** runs **on the instance** next to SQLite CDR + CoS. Gatekeeper = **notify delivery** only. SBC = SIP abuse (Fail2ban/pike), not dial-pattern velocity. Detail: **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`**.

---

## SIP capture

### Fleet edge rule

**Everyone, wherever they originate, comes through the SBC.** No direct SIP connect to instances. Instance `:5060` is SBC↔Asterisk only.

### Instance `sys-ua-siplog`

- **Singleton / solo:** useful — instance is the edge; keep existing dumpcap carousel (`port 5060`, `-b filesize` / `-b files`). Enable: **`/opt/pbx3/scripts/siplog-set-mode.sh solo`**.
- **Fleet:** **disabled by default** — pcaps will not show phone REGISTER/INVITE and waste disk. Package ships with service **`down`**; postinst/onboard do **not** `sv u`. Disable on existing nodes: **`siplog-set-mode.sh fleet`**. Optional trunk-side override later (not v1).
- **Session debug (fleet homes):** R3 stands for *always-on*. Opt-in **TTL session** home SIP **text** (+ optional pcap companion) for SBC↔Asterisk debug is specified in **`pbx3/workingdocs/HOME_SIP_LOGGING_REQUIREMENTS.md`** (AI-first; SPA arm/disarm; S3 classes `sip-text` / `sip-pcap` when fleet log-ship is configured — not implemented as of 2026-08-11). Does not replace SBC archive.

Reference: `pbx3-1/opt/pbx3/service/sys-ua-siplog/run` (runit today); globals `logsipnumfiles`, `logsipfilesize`.

### SBC SIP pcap

- **Same dumpcap model** as instance siplog: SIP-only filter, `-b filesize` / `-b files` ring, rotate completed files, then upload.
- **Not** required to use runit — systemd (or host-native) on the SBC is fine.
- Bound by **size/ring**, not only calendar days — scanners and REGISTER loops can spike SIP pps.
- Text OpenSIPS logs remain the cheap always-on path; pcaps are for deep dive.

---

## S3 layout, IAM, lifecycle

### Keys (org bucket)

```
instances/{ksuid}/logs/{class}/{stamp}/…
sbc/{id}/logs/{class}/…
control/{id}/logs/{class}/…
```

Suggested `class` values: `syslog`, `asterisk-messages`, `cdr`, `opensips`, `sip-pcap`, …

**Do not** put logs in **`PBX3_RECORDINGS_BUCKET`**.

Lab org bucket name **`08jzwn-pbx3`** is a **fleet-slug coincidence** (first node shortuid) — not instance-owned. Real fleets should use a neutral slug; see **`OPS_S3_RUNBOOK.md`** § Design note — fleet slug vs lab bucket name. Irrelevant to key layout / function.

### IAM

- Node / SBC / control writer scoped to **own** prefix (mirror backups: `instances/{ksuid}/…`).
- Lifecycle (or policy.json per class) reads **`maxage_days`** per class — CDR longer than syslog.

### Upload mechanics (when implemented)

Pattern cousins: instance backup upload; recordings async PUT after local file exists.

1. Rotate (logrotate or dumpcap segment close).
2. Upload completed object.
3. Delete or age out local after confirm (respect local max days / ring).
4. If S3 fails: keep rotating locally; do not block Asterisk/OpenSIPS.

---

## Failure modes

| Condition | Expected behaviour |
|-----------|-------------------|
| **S3 unreachable** | Keep local rotation; upload retries later; telephony unaffected |
| **Disk full / ring full** | dumpcap / logrotate drops oldest segment; ops may get disk alerts separately |
| **Solo without fleet** | No S3 requirement; local retention only |
| **Fleet with siplog left on** | Wasteful but not call-path; product default must be **off** |

---

## Out of v1

- HEP / Homer, RTP capture, Prometheus/Loki as home of record for logs.
- App CSV→SQLite ingest (Phase 6 uses Asterisk native `cdr_sqlite3_custom` dual-write instead).
- Live log follow over the API (SSE/`tail -f`) — use local paginated tail or SSH.
- Velocity / toll-fraud analysis (own track — **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`**; V1 uses SQLite CDR here).
- In-browser grep/search of S3 log objects (list+download only).
- Auto-enabling instance trunk-side pcap override in fleet.
- Central/fleet MySQL (or other) CDR warehouse.

---

## Requirements (when prioritized)

### R1 — Rotate CDR and text logs on the instance

Day/size rotation for `Master.csv`, syslog family, and Asterisk `messages`; local retain ~7 days (configurable for syslog).

**Acceptance:** After N days of lab traffic, local disk holds ~7 days of segments; no unbounded single `Master.csv`.

### R2 — Async S3 offload by class (instance)

Upload rotated files to `instances/{ksuid}/logs/{class}/…`; lifecycle CDR **2 months**, syslog/messages **1 month**; per-instance syslog knobs.

**Acceptance:** Delete local segment older than local max; object still GET-able from S3 until class `maxage_days`.

### R3 — Disable instance siplog in fleet; keep for solo

Fleet onboarding / package default: `sys-ua-siplog` **down**. Solo install: carousel available via **`siplog-set-mode.sh solo`**.

**Acceptance:** Fleet golden/bzy54n: no dumpcap on `:5060` unless ops override; solo lab box: carousel works after `solo`.

**Status (2026-07-17):** **Done on `logs`** — `down` file + postinst no longer `sv u`; onboard calls `siplog-set-mode.sh fleet`; fleet-preflight warns if running.

### R4 — SBC OpenSIPS text + SIP pcap ring + S3

OpenSIPS text: rsyslog split to `/var/log/opensips/opensips.log` (not shared syslog); 7d / 1mo. SIP pcap: dumpcap ring (SIP-only, no RTP), ~7d completed local, ~1mo S3; systemd unit **`pbx3sbc-sip-pcap`**.

**Acceptance:** Lab REGISTER/INVITE visible in SBC pcap segment; RTP absent; ring drops oldest under flood.

**Status (2026-07-17):** **pbx3sbc `install.sh`** installs OpenSIPS rsyslog split + **`pbx3sbc-sip-pcap`**. S3 ship via **`scripts/install-log-retention.sh`** + IAM tmpl `pbx3-sbc-s3-writer.policy.json.tmpl`. Lab smoke OK.

### R5 — Control host log offload

Same 7d / 1mo for control syslog/nginx under `control/{id}/logs/…`.

**Status (2026-07-17):** **Code on `logs`** — `gatekeeper/deploy/install-control-log-retention.sh`; IAM JSON includes `control/*`. Apply live IAM + run install on control host.
---

## Implementer map (later — no code in the requirements pass)

| Phase | Work | Repos / surfaces |
|-------|------|------------------|
| **1** | Instance rotate + local retain + S3 upload (syslog, messages, CDR) | **pbx3** `.deb` logrotate; **pbx3api** installer + onboard install **`/etc/cron.d/pbx3-logs`** — **done on `logs`** |
| **2** | Fleet default: disable `sys-ua-siplog`; document solo vs fleet | **pbx3** installer / fleet onboard — **done on `logs`** |
| **3** | SBC OpenSIPS text + SIP dumpcap + S3 ship | **pbx3sbc `install.sh`** CORE (rsyslog split + sip-pcap); **S3-OPT** via `install-log-retention.sh` — **done on `logs`** |
| **4** | Control host rotate + S3 | **pbx3-directory** ops: `gatekeeper/deploy/install-control-log-retention.sh` — **done on `logs`** |
| **5** | SPA / instance config for retention knobs; S3 archive list+download | **pbx3spa**, **pbx3api** — **done on `logs56`**: `GET/PUT logs/retention`, override file, `logs/archive`; Sysglobals Logging + Logs S3 section. Lifecycle script still ops-owned (knobs update `policy.json` intent). |
| **6** (optional track) | Instance SQLite CDR + search API/panel; dual-write with CSV archive | **pbx3** `cdr_sqlite3_custom.conf` (Asterisk 20: legacy `columns`/`values`) + module load; **pbx3api** `GET cdr` + `pbx3:cdr-prune`; **pbx3spa** `/cdr` — **done on `logs56`**. Lab golden: module Running, `master.db` rows, retention override + archive list/download smoke OK. |
| **7** (optional; under SBC aging review) | SBC `acc` (+ security tables) purge / cold export — planning: **`SBC_DATA_RETENTION_REQUIREMENTS.md`** | **pbx3sbc** / **pbx3sbc-admin** — decisions first; not a blocker |

Phases **1–6** are implemented. Phase 7 / broader SBC aging: decisions in **`SBC_DATA_RETENTION_REQUIREMENTS.md`** before any purge code.
