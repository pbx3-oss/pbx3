# Track B — Release hardening + stakeholder-ready help

**Status:** Phases 0–3 complete on **`main`**. **Phase 4 in progress** on **`helptext`** — Tier 1–2 help gaps closed; golden **08jzwn** has demo data for QA. **Goal:** Trusted HTTPS on fleet nodes, installer fails loudly when misconfigured, fail2ban matches nginx, and every field on stakeholder-facing SPA panels has a visible help message (`?` icon with `tt_help_core` content).

**Repos:** `pbx3`, `pbx3api`, `pbx3spa` — Phase 4 on **`helptext`**; merge to **`main`** when Phase 4 exits.

**References:** `TODO.md`, `TLS_IMPLEMENTATION_STEPS.md` §4.3, `PBX3API_INSTALLER_NGINX_ADDITIONS.md`, **`STAKEHOLDER_DEMO_SCRIPT.md`**, **pbx3spa** `PANEL_PATTERN.md`, **pbx3spa** `SESSION_HANDOFF.md` (help system).

---

## How SPA help works today

- Help text lives in **`tt_help_core`** (~383 seeded rows in `pbx3-1/opt/pbx3/db/db_sql/sqlite_message.sql`).
- SPA loads once via **`GET /helpcore`** → `useHelp` → **`FieldHelpIcon`** on form labels.
- **`FormField` / `FormSelect` / `FormToggle` / etc.** auto-derive `helpPkey` from field `id` (`pbx3spa/src/utils/formHelpPkey.js`).
- **The `?` icon only appears if `htext` is non-empty** — missing DB rows = no help, even when wiring is correct.
- New panels (Backup, Certificates, fleet Login, parts of Sysglobals) likely have **no `tt_help_core` rows** yet.

---

## Phase 0 — Baseline and demo scope (½ day)

| Step | Action | Exit |
|------|--------|------|
| **0.1** | Define **stakeholder demo path** | **`STAKEHOLDER_DEMO_SCRIPT.md`** — 10 sections, Tier 1–2 routes, help checkboxes |
| **0.2** | Record **dev baseline** (below) | Frozen 2026-05-26 |
| **0.3** | Branch **`hardening`** in pbx3, pbx3api, pbx3spa | ✓ merged to **`main`** 2026-05-30; branch deleted |
| **0.4** | **`npm test`** in pbx3spa | ✓ 31 tests passed (vitest 4.1.2, 2026-05-26) |

### Dev baseline (0.2 — 2026-05-26)

Recorded from operator machine; update this block when Phase 1 switches API to HTTPS-only dev.

| Setting | Current value | Notes |
|---------|---------------|--------|
| SPA dev URL | `http://localhost:5173` | `npm run dev` in **pbx3spa** |
| API proxy | `VITE_API_PROXY_TARGET=https://bzy54n.pbx3.com:44300` | Vite proxies `/api` — no browser CORS |
| Catalog | `VITE_CATALOG_PROXY_TARGET=https://08jzwn-pbx3.s3.us-east-1.amazonaws.com` | |
| Catalog URL | `VITE_INSTANCE_DIRECTORY_URL=/dev-catalog/catalog/instance-index.json` | Dev proxy; no S3 CORS |
| Default demo node | **bzy54n** (proxy); **08jzwn** (golden reference) | Change proxy + restart to flip |
| API TLS | HTTPS on `:44300` (LE both nodes, 2026-05-30) | Validate with `curl` without `-k`, not dev-proxy backup alone |
| Fleet nodes | `08jzwn.pbx3.com`, `bzy54n.pbx3.com` | See `AGENT_HANDOFF.md` § Fleet reference |
| Branch | **`main`** | Track B Phases 0–3 merged 2026-05-30 |

**Example file:** `pbx3spa/.env.development.example` (committed); live values in gitignored `.env.development`.

**Phase 0 exit:** ✓ Complete.

---

## Dev proxy vs node TLS (read this before Phase 1 smoke tests)

In **`npm run dev`**, the browser only talks to **`http://localhost:5173`**. Vite forwards `/api` to **`VITE_API_PROXY_TARGET`** with **`secure: false`** (`pbx3spa/vite.config.js`) — the proxy **does not validate** the node certificate (snakeoil or LE both work).

| Test | Proves node has trusted LE? | Proves API/auth works in dev? |
|------|------------------------------|-------------------------------|
| Login / backup / panels via localhost proxy | **No** | **Yes** |
| **`curl https://{fqdn}:44300/up`** (no `-k`) | **Yes** | API up + trusted cert |
| Certificates panel → LE configured + SANs | **Yes** | Panel + syshelper path |
| Browser tab directly to `https://{fqdn}:44300/up` | **Yes** | Same as curl |

Tenant FQDN DNS (e.g. `wfh69h.pbx3.com`) is required for **LE issuance/Sync**, not for API calls to the **node** FQDN through the dev proxy.

See **pbx3spa** **`workingdocs/DEV_ENVIRONMENT.md`** §7.

---

## Phase 1 — TLS finish pass (2–3 days)

*From `TODO.md` — trusted LE on `:44300` on fleet nodes. **Phase 1 exit: ✓ Complete (2026-05-30).***

### 1A — Fleet nodes

| Step | Action | Verify |
|------|--------|--------|
| **1.1–1.3** | **08jzwn** — LE since May 2026; `curl https://08jzwn.pbx3.com:44300/up` → **200** | ✓ |
| **1.4** | **bzy54n** — was snakeoil until 2026-05-30; **Certificates → Get certificate** after DNS for `wfh69h.pbx3.com` | ✓ |

**bzy54n LE (2026-05-30):** Panel **Get certificate** → covers `bzy54n.pbx3.com`, `wfh69h.pbx3.com`; expires **2026-08-28**; issuer Let's Encrypt (YE2). First issue is **manual** (not install/onboard) — see **`INSTALL_SEQUENCE_UBUNTU.md`** / **`le-instance-bootstrap.sh`**.

### 1B — SPA + Sanctum on HTTPS

| Step | Action | Verify |
|------|--------|--------|
| **1.5** | `.env.development`: `VITE_API_PROXY_TARGET=https://bzy54n.pbx3.com:44300` | ✓ |
| **1.6–1.7** | Login, backup via dev proxy | ✓ (API smoke; **not** cert validation — see above) |
| **1.8** | Certificates panel on bzy54n | ✓ (Get certificate succeeded) |

### 1C — Document and close

| Step | Action | Status |
|------|--------|--------|
| **1.9** | **`TODO.md`** — fleet LE done; installer health checks → Phase 2 | ✓ |
| **1.10** | **`AGENT_HANDOFF.md`**, **`DEV_ENVIRONMENT.md`** | ✓ |

**Phase 1 exit:** Both fleet nodes serve API on **trusted LE HTTPS** (`curl` without `-k` → 200). Dev SPA uses HTTPS proxy target; **`secure: false`** means login/backup do not prove LE — use curl or Certificates panel.

---

## Phase 2 — pbx3api installer health checks (1 day)

*From `TODO.md` — fail install when the stack is broken. **Complete (2026-05-30)** — golden rebuild validated on **0.0.3-12**+.*

| Step | Action | File / area | Verify |
|------|--------|-------------|--------|
| **2.1** | After nginx/php-fpm setup, **DB symlink check**: exists, target resolves, `www-data` can read/write sqlite | `pbx3api/scripts/installer.sh` `validate_install_health` | ✓ |
| **2.2** | **`nginx -t`** + php-fpm socket exists | same | ✓ |
| **2.3** | **HTTP readiness**: `curl -k -s -o /dev/null -w '%{http_code}' https://127.0.0.1:44300/up` | same; `curl` added to apt install | ✓ expect `200` |
| **2.4** | Test on **clean Ubuntu 24.04** VM or disposable instance | — | ✓ golden **08jzwn** rebuild (2026-05-30) |
| **2.5** | Test **failure paths** (break symlink, bad nginx config) | — | Operator optional; health checks exit non-zero when broken |

**Phase 2 exit:** ✓ Fresh install cannot succeed with a broken API layer (validated on golden).

---

## Phase 3 — fail2ban → nginx (½ day)

*Track B Phase 3 — **complete (2026-05-30)**; deb **0.0.3-15** on **`main`**.*

| Step | Action | Repo | Verify |
|------|--------|------|--------|
| **3.1** | Drop full **`jail.local`** symlink (fixes `%(auth_log)s` on Ubuntu 24.04) | **pbx3** `installer.sh` | ✓ |
| **3.2** | **`jail.d/pbx3-jails.conf`**: sshd, asterisk, recidive | **pbx3** `etc/fail2ban/jail.d/` | ✓ |
| **3.3** | **`jail.d/pbx3-api.conf`**: **`pbx3-api-badbots`** + **`apache-badbots`** on `/var/log/nginx/access.log` | **pbx3** | ✓ (noble has no `nginx-badbots` filter) |
| **3.4** | On test node: upgrade deb + re-run installer; `fail2ban-client status` | node | ✓ golden: 4 jails |
| **3.5** | Deb **0.0.3-15** + changelog | pbx3 | ✓ on **`main`** |

**Phase 3 exit:** ✓ fail2ban config matches nginx API reality.

---

## Phase 4 — SPA field help coverage (1–2 weeks)

*Stakeholder gate — every display field on demo panels should show a **`?`** with useful text.*

### 4A — Audit (2–3 days)

| Step | Action | Output |
|------|--------|--------|
| **4.1** | Build **help coverage report**: scan `*CreateView.vue`, `*DetailView.vue`, settings views (`BackupView`, `CertificatesView`, `SysglobalsEditView`, `NetworkView`, `FirewallView`, `LoginView`) | List of field `id`s → derived `helpPkey` |
| **4.2** | Cross-check against **`tt_help_core`** (`sqlite_message.sql` + live `GET /helpcore`) | Buckets: **has help**, **missing pkey**, **pkey mismatch** |
| **4.3** | Extend **`formHelpPkey.js`** for known mismatches | Mapping table |
| **4.4** | Prioritize by **stakeholder demo path** (Phase 0.1) | Tier 1 → Tier 4 panel list |

**Panel tiers**

| Tier | Panels | Stakeholder priority |
|------|--------|----------------------|
| **1** | Extension, Tenant, Queue, Route, Trunk, Inbound route, IVR | Core PBX config |
| **2** | Backup, Certificates, Sysglobals, Network, Firewall | Ops / instance |
| **3** | Agent, COS, Day/Holiday timer, Greeting, Conference, Device, Custom app | Secondary |
| **4** | Users, Logs, Help messages admin | Admin-only |

### 4B — Content — `tt_help_core` rows (3–5 days)

| Step | Action | Repo |
|------|--------|------|
| **4.5** | Add **`INSERT OR IGNORE INTO tt_help_core`** for missing pkeys — Tier 1, then Tier 2 | **pbx3** `sqlite_message.sql` |
| **4.6** | Write help for **new features**: S3 backup archive id, restore-from-archive, Certificates Sync, fleet instance picker, `fqdninspect`, etc. | same |
| **4.7** | Review existing help for stakeholder clarity | same |
| **4.8** | Deploy seeds via reloader or Help Messages admin; prefer SQL seeds for reproducibility | ops |
| **4.9** | Remove **`hide-help`** where rows now exist (e.g. SysglobalsEditView, TenantCreateView) | **pbx3spa** |

### 4C — Wiring fixes (2–3 days)

| Step | Action | Repo |
|------|--------|------|
| **4.10** | **BackupView** / **CertificatesView** / **LoginView**: `FormField`/`FormSelect` with `id`s matching `tt_help_core.pkey`, or explicit `:help-pkey` | pbx3spa |
| **4.11** | Readonly rows: **`FormReadonly`** with correct `id` (not `hide-help`) where help exists | pbx3spa |
| **4.12** | **Tenant advanced** fields: verify `tenantAdvanced.js` `helpPkey` overrides | pbx3spa |
| **4.13** | Optional: add **`helpPkey` to GET /schemas** | pbx3api + pbx3spa |

### 4D — QA gate

| Step | Action | Exit |
|------|--------|------|
| **4.14** | Walk **every Tier 1–2 panel** create + detail: every label shows `?` with non-empty popover | Checklist signed off |
| **4.15** | Spot-check Tier 3; document deferrals for Tier 4 | Gap list |
| **4.16** | Optional: Vitest or script — demo-path fields with help ≥ 95% | Automated guard |

**Phase 4 exit:** Stakeholder demo path has complete, readable help on all fields.

---

## Phase 5 — Stakeholder demo rehearsal (1 day)

| Step | Action | Verify |
|------|--------|--------|
| **5.1** | Run full **demo script** (Phase 0.1) on HTTPS + `npm run dev` | No cert warnings; no missing help on script path |
| **5.2** | **Solo path** smoke: unset `VITE_INSTANCE_DIRECTORY_URL`, direct API login | Rule 6 still works |
| **5.3** | **AGENT_HANDOFF §11** subset: backup → change DB → restore | Regression OK on HTTPS |
| **5.4** | Second person (or fresh browser profile) follows demo without operator explaining fields | Help text stands alone |

**Phase 5 exit:** Ready to share with stakeholders.

---

## Phase 6 — Bookkeeping (½ day)

| Step | Action |
|------|--------|
| **6.1** | Update **`TODO.md`** — check off TLS, fail2ban, installer checks; mark help coverage done |
| **6.2** | Update **`AGENT_HANDOFF.md`** — Track B complete |
| **6.3** | Refresh **`pbx3spa/workingdocs/SESSION_HANDOFF.md`** |
| **6.4** | Deb/changelog bumps as needed (`pbx3`, `pbx3api`, `pbx3spa`) |
| **6.5** | Optional git tag: `track-b-phases-0-3-2026-05` |

---

## Suggested timeline

```text
Week 1     Phase 0 + Phase 1 (TLS) + Phase 3 (fail2ban)
           Phase 4A audit in parallel (pbx3spa)

Week 2     Phase 2 (installer checks) + Phase 4B content (Tier 1–2)

Week 3     Phase 4C wiring + Phase 4D QA + Phase 5 demo rehearsal

Week 3 end Phase 6 bookkeeping → stakeholder demo
```

**Parallelism:** Phase 4A audit can start **Day 1** while TLS work runs on nodes.

---

## Track B completion checklist

| # | Deliverable | Done when |
|---|-------------|-----------|
| B1 | HTTPS API on both fleet nodes | ✓ `curl` without `-k` → 200 (08jzwn + bzy54n) |
| B2 | SPA works on HTTPS via Vite proxy | ✓ login/backup (proxy `secure: false` — see § Dev proxy vs node TLS) |
| B3 | Installer health checks | ✓ coded + golden validated |
| B4 | fail2ban nginx-aligned | ✓ **0.0.3-15** on **`main`**; 4 jails on golden |
| B5 | Help on all Tier 1–2 demo fields | Every label has `?` + useful text |
| B6 | Stakeholder rehearsal | Third party can follow demo script |

---

## First session (recommended)

**Phases 0–3:** ✓ Done on **`main`** (2026-05-30). See **`STAKEHOLDER_DEMO_SCRIPT.md`**, dev baseline above, golden rebuild notes in **`AGENT_HANDOFF.md`**.

**Next:** **Phase 4** SPA field help — audit Tier 1–2 panels against `tt_help_core`.
