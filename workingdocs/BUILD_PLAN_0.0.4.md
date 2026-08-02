# Build plan — pbx3 **0.0.4-1** + pbx3cagi **1.0.0-7** (+ golden rebuild)

**Status:** Plan locked **2026-07-31** — execute when operator schedules.  
**Why:** Golden is heavily surgical-patched; cut a clean minor for pbx3 and a matching cagi that includes WebRTC PrepDial. Then Mode 4 rebuild golden from S3 (**no CDR** — `master.db` not in backup).  
**Related:** **`CDR_TIMEZONE_POLICY.md`**, **`REBUILD_INSTANCE_RUNBOOK.md`**, **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4, **`INSTALL_SEQUENCE_UBUNTU.md`**.

---

## 1. Target versions

| Package | From | To | Arch / artefact |
|---------|------|-----|-----------------|
| **pbx3** | `0.0.3-25` | **`0.0.4-1`** | Ubuntu noble `.deb` (`dpkg-buildpackage` from `pbx3-1/`) |
| **pbx3cagi** | `1.0.0-6` | **`1.0.0-7`** | sailhpe-style `_all.deb` (pre-staged `pbx3cagi.{amd64,arm64}`) |

**Not in these debs (deploy separately on rebuild):** **pbx3api** `git pull` + migrate; **pbx3spa** Pages if needed; Gatekeeper unchanged unless a tip requires it.

---

## 2. What ships in each package

### 2.1 pbx3 **0.0.4-1** (instance)

Already in `pbx3-1/` on `main` since mid-arc (never left `-25` deb) — changelog should **name** them:

- GenAst hermit (overlays phone/webrtc/trunk/queue/park; LepDial / `PBX3_DIAL`; fleet AoR / `$outbound_proxy` / `PBX3_SBC_EGRESS_HOST`)
- `pjsip_webrtc.tmpl` shortuid / `$id`; http **:8089**; shorewall **8089**; egress identify tmpl
- Sitename installer (`INSTANCE_SITENAME`)
- PHP classes `*.php` only

**Must land before build (still dirty / gap):**

| Item | Action |
|------|--------|
| **CDR HoR UTC** | Commit `cdr_sqlite3_custom.conf` (`STRFTIME(…UTC…)`); aligns CSV `usegmtime=yes` |
| **Overlay postinst SQL** | Idempotent `ALTER`/`sqlite_add_*_overlay.sql` + postinst (create SQL has columns; `apt upgrade` alone may not). Mirror recordings postinst pattern |
| **debian/changelog** | New entry **`0.0.4-1`** summarizing above + CDR UTC |

**Optional in same build:** sitename help apply on upgrade (`sqlite_message.sql`).

**Out of deb:** Magrathea/`019242*`/Twilio Peers; soak phones/queue; lab SG; call-tests recipes; AST residue (Page/`***`, NAT tmpl polish).

### 2.2 pbx3cagi **1.0.0-7**

| Item | Notes |
|------|--------|
| **PrepDial WebRTC** | Skip `/sip:user@tenant.fqdn` when `ipphone.device=WebRTC` (tip **`3a9b7d7`** hot on golden; not in **1.0.0-6** changelog) |
| Binaries | Rebuild **arm64** (required for golden); **amd64** if available via `seed-deb-binaries.sh` |
| Packaging | Existing `scripts/build-deb.sh` / sailhpe `_all.deb` — no compile inside debuild |
| Changelog | **1.0.0-7** — WebRTC PrepDial + any other unreleased cagi commits on `main` since `-6` |

Deploy **cagi before** GenAst Commit on the new node if dialplan expects current PrepDial behaviour.

---

## 3. Build order (Mac / build host)

```text
A. Code freeze on main
   ├── commit CDR UTC + overlay postinst (pbx3)
   ├── confirm cagi WebRTC PrepDial on main
   └── bump both changelogs

B. Build pbx3cagi 1.0.0-7
   ├── make / cross-build arm64 (+ amd64)
   ├── seed usr/share/asterisk/agi-bin/pbx3cagi.{arm64,amd64}
   └── ./scripts/build-deb.sh  →  pbx3cagi_1.0.0-7_all.deb

C. Build pbx3 0.0.4-1
   └── cd pbx3-1 && dpkg-buildpackage -us -uc -b
       → ../pbx3_0.0.4-1_*.deb  (arch as packaged)

D. Smoke artefacts
   ├── dpkg-deb -c … | grep cdr_sqlite3_custom   # UTC STRFTIME present
   ├── dpkg-deb -c … | grep pbx3cagi.arm64
   └── store debs where Mode 4 install will pull them (S3 / operator path)
```

Do **not** install on live golden until backup + new EC2 are ready (or install on a throwaway first).

---

## 4. Golden rebuild (after debs exist)

Follow **`REBUILD_INSTANCE_RUNBOOK.md`** (Mode 4). Lab-specific knobs:

| Step | Detail |
|------|--------|
| 0 | SPA **Backup → S3** on current golden (fresh stamp) |
| 1 | Operator launches new EC2 (same size/SG pattern); **ask before** terminate old |
| 2 | Install **pbx3 0.0.4-1** then **pbx3cagi 1.0.0-7** (or cagi immediately after Asterisk stack is up) |
| 3 | `fetch-latest-instance-backup.sh` → `restore-backup-zip.sh --full` |
| 4 | **CDR:** empty `master.db` by design (not in zip) — no wipe step |
| 5 | pbx3api deploy + migrate; fleet `.env` / onboard as runbook |
| 6 | `pbx3:fleet-preflight` all green |
| 6b | **`reconcile-node-tenants.sh`** OK (no node-only tenants) — **`LAB_FLEET_TENANTS.md`** |
| 7 | Smoke: Domains REGISTER; one Domain call; **CDR `calldate` ≈ `date -u`**; Home Outcomes (today) non-empty after that call |
| 8 | Optional: WebRTC REGISTER smoke on `:8089`; re-provision soak phones/queue **under a catalog tenant** if wallpaper needed |
| 9 | Only then: DNS/LE if needed; terminate old EC2 |

**KSUID / FQDN:** keep **`08jzwn`** identity from backup (same instance). Org bucket historically `08jzwn-pbx3` — confirm from catalog before kickoff.

---

## 5. Acceptance

- [ ] `pbx3 0.0.4-1` installs clean on noble arm64; `cdr_sqlite3_custom.conf` has UTC `STRFTIME`
- [ ] Overlay columns present after install **without** relying on api migrate alone (postinst)
- [ ] `pbx3cagi 1.0.0-7` binary on node; WebRTC inbound uses `Dial(PJSIP/{shortuid})` not FQDN suffix
- [ ] Restore preflight green; no Magrathea Peer on new node EIP
- [ ] Fresh CDR UTC; Home doughnut sees post-restore traffic
- [ ] Old golden terminated only after operator confirm

---

## 6. Kickoff prompt (copy for build+rebuild session)

```text
Execute BUILD_PLAN_0.0.4.md: cut pbx3 0.0.4-1 + pbx3cagi 1.0.0-7, then Mode 4 rebuild golden.
Commit CDR UTC + overlay postinst before pbx3 deb. Ask before: terminate EC2, DNS/LE, IAM.
CDR starts empty after restore (intentional). Preflight green before retire old 08jzwn.
```

---

## Changelog (this doc)

| Date | Note |
|------|------|
| 2026-07-31 | Plan: 0.0.4-1 + cagi 1.0.0-7; CDR UTC; overlay postinst; golden rebuild without CDR. |
