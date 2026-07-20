# SBC backup & restore — requirements (future project)

**Status:** **Scoped stub only (2026-07-20).** Aging purge is **lab-live**; this DR project is next when you open it.  
**Production gate:** A tested SBC backup/restore path is **required before any production fleet** — catalog re-project alone is not enough.  
**Related:** PBX instance pattern (`OPS_S3_RUNBOOK.md`, `backup-manifest.v0.json`, `REBUILD_INSTANCE_RUNBOOK.md`); **`FLEET_TRUNK_PEERING_DECISION.md`** §6.0 (MariaDB current; Litestream **parked**); **`DESIGN_RULES.md`** Rule 1, Rule 13; **`SBC_DATA_RETENTION_REQUIREMENTS.md`** (aging ≠ DR).

## Problem

Each SBC member keeps a **local MariaDB** plus on-box config. Fleet **catalog → edge projection** recovers directory-owned routing (domains, dispatcher, DID projection). It does **not** recover **edge-authored** state (peering/carriers, Fail2ban lists, Filament admins, and other rows that only live on the SBC).

Without a dump + restore runbook, losing an SBC box means re-keying and drift risk. Active–passive HA is **not** the same as cold rebuild/DR.

## Not this project

| Topic | Home |
|-------|------|
| Append-only table **purge** (`acc`, door-knock, failed-reg) | **`SBC_DATA_RETENTION_REQUIREMENTS.md`** |
| Text log / pcap rotate + S3 ship | Log retention Phases 1–4 |
| Litestream / SQLite edge | **Parked** — irrelevant while on MariaDB |
| Instance (PBX) zip → S3 | Already shipped |

## Target shape (mirror PBX; MariaDB dump)

Reuse the **instance backup product template**, adapted for the edge:

1. **Local artifact:** e.g. `sbcbak.{epoch}.zip` containing **mysqldump** (or equivalent) of OpenSIPS + admin DBs **and** selective config dirs (OpenSIPS / nginx / Fail2ban as decided at design time).
2. **S3 layout:** `s3://{ORG}/sbc/{sbc-id}/backups/{stamp}/backup.zip` + `manifest.json` + `policy.json`.
3. **Tag:** `class=backup` → lifecycle `maxage_days` (ops laptop script, like instance).
4. **Upload:** after local create; best-effort; verify `exists()`; touch SBC meta `backup_latest_stamp` if we add SBC meta.
5. **Triggers:** scheduled cron + manual; optional pre-upgrade later.
6. **Local retention:** FIFO N; S3 age via lifecycle.
7. **Restore:** selective flags and/or `--full` shell; **never** “reload from empty templates” after DB restore in a way that wipes restored data; then re-check projection vs catalog (reconcile).
8. **IAM:** prefix-scoped writer on the SBC; lifecycle/admin on ops.

**Engine:** **MariaDB** only for v1. Do not assume Litestream.

## Design decisions still open (when this project starts)

- Exact dump scope (which schemas/tables; exclude `dialog` / hot soft-state?).
- Which filesystem trees ride in the zip vs reinstall-from-image.
- Whether Filament passwords / APP_KEY need a separate secrets story.
- HA promote vs cold restore runbooks (two drills).
- Relationship to catalog reconcile after restore (apply projection vs trust dump for fleet rows).

## Acceptance (production gate)

- [ ] Scheduled backup produces local zip + S3 `backup.zip` + valid manifest on lab SBC.
- [ ] Documented restore on a **replacement** host (or wiped lab) brings edge-authored peering + admin login back.
- [ ] Call path + Filament smoke after restore; catalog reconcile does not blindly destroy restored edge-authored rows.
- [ ] Operator MkDocs page (or runbook) exists; Litestream docs stay marked historical.

## Implement order (later)

1. Finish **SBC data aging** (WS1/WS2).
2. Open this project: inventory edge-authored vs projected tables → lock dump contents.
3. Scripts + cron + S3 upload + lab restore drill.
4. Docs + TODO closeout.
