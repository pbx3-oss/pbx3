# PBX3 Cleanup – Context & Discoveries

**Created:** 2025-02-05  
**Branch:** cleanup  
**Purpose:** Preserve context from repo familiarization and list cleanup items for the project.

---

## Repo overview

**pbx3** is the back-end worker: no HTML front-end, driven by **pbx3api**. Code is PHP, bash, and C. It holds schema, Asterisk config generation, DB scripts, and system config. Not involved in Sanctum/auth (that lives in pbx3api).

### Layout

| Area | Contents |
|------|----------|
| **Root** | README.md, LICENSE, mkdocs.yml, full_schema.sql, .gitignore |
| **docs/** | MkDocs: index.md, filelayout.md, config.md, featureKeys.md |
| **workingdocs/** | Working documents and preserved context (this folder) |
| **pbx3-1/** | Debian package layout: debian/, etc/, opt/pbx3/, usr/ |
| **opt/pbx3/** | always/, cache/, db/, etc/, once/, php/, scripts/, service/ |

### Database (SQLite)

- **db/db_sql/** – Schema split into:
  - **sqlite_create_instance.sql** – System tables: `globals`, `tt_help_core`
  - **sqlite_create_laravel.sql** – Laravel/auth: users, sessions, cache, jobs, personal_access_tokens
  - **sqlite_create_tenant.sql** – Tenant/cluster/agent/app/cos/queue/etc. (bulk of tables)
  - **sqlite_create_legacy.sql** – Legacy schema
  - Plus: sqlite_message.sql, sqlite_device.sql, and fix scripts (sqlite_fix_*.sql)
- **full_schema.sql** (repo root) – Single-file combined schema (~613 lines); canonical reference.
- **always/** and **once/** – SQL applied on init/upgrade.

### PHP

- **config.php** – Paths and constants; run `php utilities/genbashconfig.php` to sync to bashconfig.
- **classes/** – DbClass, GenClass, HelperClass, AsteriskManager, etc.
- **utilities/** – runAstGen.php, runLinker.php, shorewallreload.php, sanitize-firewall.php, dumper.php, refactor*.php, etc. (no generator/ directory).

### Scripts

- **bashconfig** – Generated from config.php; used by scripts.
- **create.initial.db** – Creates initial empty DB (see cleanup item).
- **migrateLegacyDb.sh** – Legacy migration; applies tenant + instance SQL, calls reloader and refactor scripts (see cleanup items).
- **genAst.sh**, **reloader.sh**, age/snap/spin scripts, cronqmove.pl, syshelper.pl.

### Asterisk

- **etc/asterisk/configs/** – pjsip, queues, features, manager, extensions, etc.
- **etc/asterisk/templates/** – .tmpl for trunks, phones, queues, parking.
- **usr/share/asterisk/agi-bin/kwakeup** – Wakeup-call AGI.

### Packaging

- **pbx3-1/debian/** – control, rules, postinst, prerm, etc.
- **pbx3-1/etc/** – apache2 (or nginx if we switch), cron, shorewall, rsyslog, sudoers, systemd.

---

## Cleanup status (summary)

- **create.initial.db** – Uses split SQL files (instance → laravel → tenant → message) in order. ✅
- **migrateLegacyDb.sh** – Uses `$RELOADER`; bashconfig defines both RELOADER and EXEC_DB_RELOAD. Calls `refactorOldDB.php` (utilities). **Bug:** line 23 uses bare `sqlite.db` instead of `$SYSDB`.
- **SYSAGI** – config.php and bashconfig both use `pbx3cagi`. ✅
- **Docs (filelayout, mkdocs nav, index.md)** – Fixed. ✅
- **Full phases and actions:** see **CLEANUP_PLAN.md**.

### Laravel schema vs pbx3api (abilities/role)

- **File:** `pbx3-1/opt/pbx3/db/db_sql/sqlite_create_laravel.sql`
- **Context:** pbx3api now uses `users.abilities` (JSON array) as source of truth for auth; role column no longer used for auth (see pbx3api/docs/SANCTUM_HANDOFF.md).
- **Issue:** sqlite_create_laravel.sql still has `users.role` and `abilities` as varchar; full_schema.sql already uses `abilities` as text. For consistency and to avoid “Invalid ability provided” issues, DB should store abilities as JSON (text) and optionally drop or ignore role.
- **Action:** Align sqlite_create_laravel.sql (and any other create scripts) with pbx3api: abilities as text (JSON), document role as deprecated/unused; sync full_schema.sql if it’s the canonical combined schema.

---

## Architecture note (HTTP server / API)

- **An HTTP server (Apache or nginx) on the pbx3 host** is used to **host the API** (pbx3api). We may replace Apache with **nginx** in the new setup – nginx is usually simpler. Keep the HTTP stack for the API; remove the old colocated admin panel (sark sites, www). Current API site is e.g. **pbx3.conf** (Apache, DocumentRoot `/opt/pbx3api/public`); new setup may use nginx config instead. See CLEANUP_PLAN.md Phase D.
- **TLS:** Old system used **purchased wildcard certificates**. New system should use **Let's Encrypt** – we need to engineer that in (certbot, renewal, HTTP server SSL config). See CLEANUP_PLAN.md Phase F.

## Cross-repo note

- **pbx3api** (see docs/SANCTUM_HANDOFF.md): Auth lives there; `users.abilities` must be stored as JSON array in DB (e.g. `["admin"]`). pbx3’s Laravel schema should match what pbx3api expects.

---

## Workingdocs folder

This folder (**workingdocs/**) is for:

- Preserving context across sessions
- Working documents that help as we proceed with the project
- Notes, checklists, and handoff-style docs for pbx3 cleanup

Add new docs here as needed (e.g. cleanup checklist, script fix log, schema alignment notes).
