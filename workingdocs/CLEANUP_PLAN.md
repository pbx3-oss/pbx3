# PBX3 Cleanup Plan

**Created:** 2025-02-05  
**Branch:** cleanup  
**Status:** Draft – to be refined as we proceed.

---

## 1. Background: Old vs New

| | Old system | New system (PBX3) |
|---|------------|-------------------|
| **Model** | Traditional Asterisk PBX with **colocated admin panel** (HTTP/S on same server) | **Backend + API on same host** – An HTTP server (Apache or **nginx**; nginx is often simpler) hosts **pbx3api** only; no colocated admin UI |
| **Admin** | Web UI and backend on same server | Admin is a **SPA** (pbx3spa), separate; SPA talks to API (pbx3api) |
| **Configuration** | Changed via web UI hitting local backend | Changed **only via API** (pbx3api); API talks to pbx3 (DB, Asterisk, scripts) as needed |
| **This repo (pbx3)** | Contained both PBX logic and web-serving pieces | PBX logic, schema, config generation, DB, scripts; HTTP server (Apache or nginx) on host is for **hosting the API**, not admin UI |

PBX3 was hacked out of the old system to get something running as a basis for further work. Cleanup means: align the repo with the **API-on-host, no colocated admin UI** model – keep HTTP for the API, remove legacy sark/admin panel and www.

---

## 2. Guiding principles

- **An HTTP server (Apache or nginx) on the pbx3 host is for hosting the API (pbx3api).** We may replace Apache with **nginx** in the new setup – nginx is usually simpler. No colocated admin UI – admin is the SPA, separate. Keep the HTTP stack for the API; remove sark/admin sites and www.
- **TLS / certificates:** The old system used **purchased wildcard certificates**. For the new system we are leaning towards **Let's Encrypt**; we need to **engineer that in** (e.g. certbot, automatic renewal, HTTP server SSL config using Let's Encrypt cert paths). This is part of Phase F (installer & deployment) and any HTTP server config we ship.
- **Single entry point for changes:** API (pbx3api). No code paths that assume a local web app.
- **Naming and structure** should reflect pbx3, not the old product names (sark, gcs, sail) except where still required for compatibility.
- **Documentation** should describe the current architecture (API-driven, SPA admin) and how pbx3 fits in.
- **Fix broken references** (missing files, wrong variables, broken links) so scripts and packaging are consistent and runnable.
- **Cross-repo coordination:** Schema or path changes in pbx3 may require matching changes in **pbx3api** (and possibly pbx3spa if API URLs or behaviour change). When touching schema (Phase C) or shared paths, check the other repos.
- **Secrets / credentials:** Do not leave production secrets in the repo. config.php has e.g. AMIPWD; pbx3api uses .env. Phase E or F: review where credentials come from (env vars, installer prompt, secrets store) and document; move hardcoded secrets out of versioned config where appropriate.

---

## 3. Cleanup phases (overview)

| Phase | Focus | Outcome |
|-------|--------|--------|
| **A** | Docs & quick fixes | Correct typos, fix MkDocs nav, align docs with “backend only, API + SPA” |
| **B** | Scripts & config | Fix create.initial.db, migrateLegacyDb.sh (RELOADER, refactorOldDb), SYSAGI; ensure bashconfig matches config.php |
| **C** | Schema & DB | Align Laravel schema with pbx3api (users.abilities as JSON/text); sync full_schema.sql; document role as unused |
| **D** | Legacy web & paths | **HTTP server (Apache or nginx) hosts the API.** Remove sark admin sites and www from *code/config*; fix sark/gcs paths in scripts and Asterisk configs (no installer rewrite yet) |
| **E** | Naming & leftovers | Replace or document sark/gcs/sail references; drop dead paths and files; tidy .gitignore and packaging |
| **F** | Installer & deployment | **Separate, larger step.** Installer was lifted from old debian package postinst; will likely need substantial work. Support both: (1) deb package for distribution, or (2) clone repo + run installer (increasingly common). Do this after D/E so the installer operates on a cleaned codebase. |

Phases can be reordered or split; dependencies: B and C are largely independent. **Decision made:** An HTTP server (Apache or nginx; we may switch to nginx – usually simpler) stays on the pbx3 host to host the API (pbx3api). Phase D = remove old admin (sark/www) and fix paths; Phase F = installer and deployment strategy as a separate, later step.

---

## 4. Phase A – Documentation & quick fixes ✅

- **Done:** filelayout typo, mkdocs nav, docs/index.md (backend-only). See PBX3_CLEANUP_CONTEXT.md for status.

---

## 5. Phase B – Scripts & config

- **create.initial.db** – ✅ Fixed. Applies split SQL (instance → laravel → tenant → message) in order.

- **migrateLegacyDb.sh**  
  - **Status:** Uses `$RELOADER`; bashconfig defines both RELOADER and EXEC_DB_RELOAD. Calls `refactorOldDB.php` (utilities).  
  - **Remaining bug:** Line 23 uses bare `sqlite.db` instead of `$SYSDB` or `$DBPATH/sqlite.db`.

- **config.php vs bashconfig** – ✅ SYSAGI aligned: both use `pbx3cagi`. Run `php utilities/genbashconfig.php` after editing config.php.

- **reloader.sh / HTTPOWNER**  
  - Uses `www-data` for DB/cache ownership. The HTTP server (Apache or nginx + PHP-FPM) typically runs as www-data to serve the API, so this is correct; document that www-data is the API/PHP user.

---

## 6. Phase C – Schema & DB alignment with pbx3api

- **sqlite_create_laravel.sql**  
  - **Context:** pbx3api uses `users.abilities` (JSON array) for auth; role column not used for auth (see pbx3api/docs/SANCTUM_HANDOFF.md).  
  - **Actions:**  
    - Ensure `users.abilities` is defined as `text` (for JSON), not `varchar`.  
    - Keep or drop `users.role` – if kept, document as deprecated/unused for auth.  
    - Match column order/types with what pbx3api expects (e.g. cluster, endpoint, etc.).

- **full_schema.sql**  
  - Treat as canonical combined schema; update it to match the corrected Laravel + instance + tenant schema so it stays the single reference.

- **always/ and once/**  
  - Review any SQL that touches `users` (e.g. abilities/role); ensure no conflicts with pbx3api.

---

## 7. Phase D – Legacy web & paths (no installer rewrite)

**Decision:** An HTTP server (Apache or **nginx**; we may replace Apache with nginx in the new setup – it’s usually simpler) is required on the pbx3 host to **host the API** (pbx3api). We **keep** the HTTP stack for the API; we **remove** references to the old colocated admin panel (sark sites, www) from *code and config*. The **installer itself** is not rewritten in this phase – that is Phase F.

**Target state (for code/config only):**
- HTTP server serves **only the API**: e.g. existing **pbx3.conf** (Apache) or equivalent nginx config (DocumentRoot/root `/opt/pbx3api/public`, SSL on 44300). No sark-* site configs or enabling in the codebase we maintain.
- No `$SYSPATH/www` for an admin UI in scripts/config. Provisioning dirs (`public/aastra`, etc.) – keep only if the API or another service serves them; otherwise remove or document as future use.
- All script and Asterisk config paths use pbx3 (e.g. `/opt/pbx3/`) not sark/gcs.

**Current state (findings):**

- **Scripts and configs (not installer.sh in this phase):**  
  - **getmaclist.sh** / **getimages.sh** reference `/opt/gcs/www/gcs-common/` – old product paths; update to pbx3 paths or remove if obsolete.  
  - **agegracerecordings.sh** references `/opt/sark/media/recordings/deletes` – legacy path; align with pbx3 layout (e.g. RECORDINGS/DELETES from config).  
  - **vmail_header.conf** (asterisk): `externnotify=/opt/sark/scripts/vmnotify.sh` – point to `/opt/pbx3/scripts/vmnotify.sh` (or equivalent).

- **Installer:** installer.sh was lifted from the old debian package postinst. It still references sark-* sites, www, etc., and will need **substantial work** – but that is **Phase F (Installer & deployment)**, done as a separate step after the codebase is cleaned (D, E). Do not try to fix the installer in Phase D; just fix the scripts and configs that the installer (or a future installer) will rely on.

**Actions (Phase D only):**

- Replace `/opt/sark` and `/opt/gcs` with pbx3 paths in **scripts** and **Asterisk configs** (e.g. vmail_header.conf).  
- Remove or update references to sark/www in any *non-installer* code.  
- Do **not** rewrite installer.sh here – defer to Phase F.

---

## 8. Phase F – Installer & deployment (separate, larger step)

**Context:** The installer (e.g. `installer.sh`) was **lifted from the old debian package postinst**. It will likely need **a lot of work** and should be done as a **separate step** in the plan – after the codebase is cleaned (Phases D, E). Do not try to fix the installer in Phase D.

**Deployment options (both in scope):**

1. **Deb package for distribution** – We may still build a deb package (e.g. `pbx3_1.0.0-1_all.deb`) for distribution. postinst would call the installer or equivalent.
2. **Clone repo + run installer** – We may instead (or also) support “clone the repo and run an installer,” which more and more packages do these days. No deb required for that path.

**Phase F actions (when we get there):**

- Rewrite or heavily adapt the installer so it aligns with the cleaned codebase: API-only HTTP server (Apache pbx3.conf or **nginx** config; we may switch to nginx – usually simpler), no sark-* sites, no www for admin UI; correct paths (pbx3, not sark/gcs).
- **Engineer Let's Encrypt** for TLS: old system used purchased wildcard certs; new system should use **Let's Encrypt** (e.g. certbot, automatic renewal, HTTP server SSL config pointing at certbot’s cert paths). Include this in installer/deployment and in any HTTP server config templates we ship.
- Decide and document deployment story: deb package, clone+installer, or both.
- Ensure debian/ (control, rules, postinst, prerm, files) matches what we actually ship and how we want to install (e.g. postinst may just run the installer script from the cloned/installed tree).
- Test both paths if we support both.

**Dependency:** Do Phase F after D and E so the installer operates on a cleaned codebase and we are not constantly fixing installer and code in lockstep.

---

## 9. Phase E – Naming & leftovers

- **sark / gcs / sail:**  
  - Rename or document: e.g. `sarkServerName.conf` → `pbx3ServerName.conf` (or keep name but document as legacy).  
  - Grep for sark, gcs, sail across the repo; replace with pbx3 where it denotes the product, or add a short comment where we keep for compatibility.

- **Dead or obsolete files:**  
  - CLEANDB in config points to `sqlite_clean.db` – confirm if this file is generated or expected to exist; document or fix.

- **.gitignore / packaging:**  
  - Ensure build artifacts and local-only files are ignored; debian/files and install paths match what we actually ship.

- **Cron:**  
  - Review **cron.d/pbx3** and any scripts it calls for legacy paths (sark/gcs) and relevance; fix or document.

- **Migration from existing installs:**  
  - Migration-from-old-system code (e.g. **migrateLegacyDb.sh** and related scripts) stays in this repo. Fix remaining bug (line 23: `sqlite.db` → `$SYSDB`); document migration path for users migrating from old (sark/pbx3) installs.

- **Device provisioning:**  
  - **public/** (aastra, cisco, polycom, etc.) – **Removed for now.** Device provisioning directories and references have been removed from the codebase. Future provisioning (if needed) will be handled separately.

- **Supported versions (optional):**  
  - Document or pin supported versions (PHP, SQLite, Asterisk, OS) in Phase F or in docs so installers and operators know the target stack.

---

## 10. Discovery checklist (as we go)

- [ ] List all files under `pbx3-1/etc/apache2` (or nginx equiv. if we switch) and compare with what installer.sh expects (Phase F).  
- [ ] Confirm whether `sark_http.conf`, `sark_modules.conf`, `sark_pjsip.conf` exist in the package (under opt or etc).  
- [ ] Grep for `/opt/sark`, `/opt/gcs`, `sark`, `gcs` and list every reference with a keep/change/remove decision.  
- [ ] Confirm order of applying sqlite_create_*.sql (and legacy) for a fresh DB and document in workingdocs.  
- [ ] Document “what runs on the pbx3 host” (processes, users, HTTP server for API – Apache or nginx) in docs or workingdocs.  
- [ ] Phase F: Document deployment options (deb vs clone+installer) and installer rewrite scope.  
- [ ] Phase F: Document Let's Encrypt approach (certbot, renewal, paths) and ensure HTTP server config uses it; remove or don’t assume purchased wildcard certs.
- [ ] Review cron.d/pbx3 and referenced scripts for legacy paths and relevance.
- [ ] Fix migrateLegacyDb.sh issues (RELOADER variable, refactorOldDb.php); document migration path.
- [ ] Decide device provisioning ownership (public/ dirs); document.
- [ ] List where secrets/credentials live (config.php, .env, etc.) and document how they are set (Phase E/F).

---

## 11. Later / out of scope (for this cleanup)

Items we are **not** doing as part of the current cleanup phases; consider later or in separate work:

- **Automated testing / CI** – When we change scripts or schema, add or run a minimal check (e.g. run key scripts, lint). No test suite or CI pipeline in scope for this cleanup; add when it becomes useful.
- **Backup / restore** – dumper.php and DBDUMPS exist; a formal backup strategy and restore procedure belong in ops docs or a later phase, not in this cleanup.
- **Logging strategy** – logrotate is already in etc; a full logging/observability design is out of scope here.
- **Rollback procedure** – How to roll back a bad install or deploy. Fits runbooks/ops docs once deployment (Phase F) is stable; not part of the cleanup phases.
- **Performance / scaling** – Tuning Asterisk, DB, or API is out of scope unless we hit a concrete problem during cleanup.

---

## 12. References

- **workingdocs/PBX3_CLEANUP_CONTEXT.md** – Repo overview and initial cleanup list.  
- **pbx3api/docs/SANCTUM_HANDOFF.md** – Auth model and users.abilities; pbx3 schema must match.  
- **pbx3 docs/index.md** – High-level description of pbx3 (backend only, API + SPA).

---

*This plan is a living document. Update phases and checklists as we execute and discover more.*
