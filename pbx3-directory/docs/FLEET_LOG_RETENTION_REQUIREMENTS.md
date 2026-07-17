# Fleet / node — log retention & SIP capture (requirements)

**Status:** **Phases 1–3 on branch `logs` (2026-07-17)** — instance rotate + S3 ship (lab smoke OK); fleet siplog off; SBC OpenSIPS/syslog/SIP-pcap ship (install on SBC). Phases 4–7 not started.  
**MVP (when prioritized):** Local hot store (~7 days) + async offload of **rotated** files to S3 cold store by class; SIP-only pcap ring on the **SBC**; instance `sys-ua-siplog` **solo only** (disabled in fleet).  
**Related:** **`DESIGN_RULES.md`** Rule 1 (telephony independent of directory/S3), Rule 6 (solo without S3); **`OPS_S3_RUNBOOK.md`** §15 / backups + **`RECORDINGS_STORAGE_DESIGN.md`** (async upload cousins); **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** § Velocity (instance detection; Gatekeeper delivery); pbx3api **`LogController`** (local log read); instance **`sys-ua-siplog`** (`dumpcap` carousel); SBC OpenSIPS **`acc`** (MySQL CDR).

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
| **SPA over S3** | Out of v1 — local **`LogController`** stays; S3 = retrieve/download later |

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
| **Asterisk CDR SQLite** (when prioritized) | Instance-local DB (Asterisk `cdr_sqlite` or app-owned) | Searchable panels; not a central warehouse — see § CDR |
| **queue_log** (optional sibling) | `/var/log/asterisk/queue_log` | Call-center tenants; same local/S3 pattern when prioritized |
| **`sys-ua-siplog`** | `dumpcap` → `SIPLOG` carousel (`logsipnumfiles` / `logsipfilesize`) | **Solo on**; **fleet off** by default |

### SBC (OpenSIPS edge)

| Stream | Path / source | Notes |
|--------|---------------|--------|
| **OpenSIPS text** | `/var/log/opensips` (xlog, failed-reg, door-knock) | Cheap always-on; Fail2ban input |
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

### Velocity (pointer)

Toll-fraud / call-pattern **detection** runs **on the instance** next to SQLite CDR + CoS. Gatekeeper = **notify delivery** only. SBC = SIP abuse (Fail2ban/pike), not dial-pattern velocity. Detail: **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** § Velocity checking.

---

## SIP capture

### Fleet edge rule

**Everyone, wherever they originate, comes through the SBC.** No direct SIP connect to instances. Instance `:5060` is SBC↔Asterisk only.

### Instance `sys-ua-siplog`

- **Singleton / solo:** useful — instance is the edge; keep existing dumpcap carousel (`port 5060`, `-b filesize` / `-b files`). Enable: **`/opt/pbx3/scripts/siplog-set-mode.sh solo`**.
- **Fleet:** **disabled by default** — pcaps will not show phone REGISTER/INVITE and waste disk. Package ships with service **`down`**; postinst/onboard do **not** `sv u`. Disable on existing nodes: **`siplog-set-mode.sh fleet`**. Optional trunk-side override later (not v1).

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
- Instance SQLite CDR + SPA search UI (settled design above; implement when asked — not required to ship CSV rotate→S3 first).
- Velocity / toll-fraud analysis (settled **where**; implement later — **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`**).
- Full SPA log browser over S3 objects (local panel remains).
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

OpenSIPS text: 7d / 1mo. SIP pcap: dumpcap ring (SIP-only, no RTP), ~7d completed local, ~1mo S3; systemd unit **`pbx3sbc-sip-pcap`**.

**Acceptance:** Lab REGISTER/INVITE visible in SBC pcap segment; RTP absent; ring drops oldest under flood.

**Status (2026-07-17):** **Code on `pbx3sbc` `logs`** — `install-log-retention.sh`, `ship-logs-to-s3.sh`, IAM tmpl `pbx3-sbc-s3-writer.policy.json.tmpl`. Lab host install still ops (SBC SSH key differs from golden).

### R5 — Control host log offload

Same 7d / 1mo for control syslog/nginx/gatekeeper under `control/{id}/logs/…`.

---

## Implementer map (later — no code in the requirements pass)

| Phase | Work | Repos / surfaces |
|-------|------|------------------|
| **1** | Instance rotate + local retain + S3 upload (syslog, messages, CDR) | **pbx3** / **pbx3api**; logrotate; IAM; `OPS_S3_RUNBOOK` — **code on `logs` (2026-07-17)**; lab smoke OK |
| **2** | Fleet default: disable `sys-ua-siplog`; document solo vs fleet | **pbx3** installer / fleet onboard — **done on `logs` (2026-07-17)** |
| **3** | SBC OpenSIPS text rotate + S3; SIP dumpcap unit + upload | **pbx3sbc** — **done on `logs` (2026-07-17)**; host install via `scripts/install-log-retention.sh` |
| **4** | Control host rotate + S3 | **pbx3-directory** / control runbook |
| **5** | SPA / instance config for retention knobs; optional S3 retrieve | **pbx3spa**, **pbx3api** |
| **6** (optional track) | Instance SQLite CDR + search API/panel; dual-write with CSV archive | **pbx3** / **pbx3api** / **pbx3spa** |
| **7** (optional) | SBC `acc` purge / cold export | **pbx3sbc** / **pbx3sbc-admin** |

Do not start **Phases 2+** without an explicit ask. Phase 1: deploy logrotate + cron on lab, run `apply-logs-lifecycle-rules.sh`, smoke `pbx3:logs-s3-upload`.
