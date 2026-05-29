# Track B — Release hardening + stakeholder-ready help

**Status:** Active (2026-05-26). **Goal:** Trusted HTTPS on fleet nodes, installer fails loudly when misconfigured, fail2ban matches nginx, and every field on stakeholder-facing SPA panels has a visible help message (`?` icon with `tt_help_core` content).

**Repos:** `pbx3`, `pbx3api`, `pbx3spa` (all on **`main`**).

**References:** `TODO.md`, `TLS_IMPLEMENTATION_STEPS.md` §4.3, `PBX3API_INSTALLER_NGINX_ADDITIONS.md`, **pbx3spa** `PANEL_PATTERN.md`, **pbx3spa** `SESSION_HANDOFF.md` (help system).

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
| **0.1** | Define **stakeholder demo path** (suggested): Login → pick instance → Dashboard → Extension create/edit → Tenant → Queue → Backup create/list → Certificates Sync | Written checklist (10–15 screens) |
| **0.2** | Record current dev setup: HTTP vs HTTPS API URL, which node (`08jzwn` / `bzy54n`) | Note in handoff |
| **0.3** | Open branch **`release-hardening`** in each repo (or work on `main`) | Branch ready |
| **0.4** | Run **`npm test`** in pbx3spa | Green |

---

## Phase 1 — TLS finish pass (2–3 days)

*From `TODO.md` — move off LAN HTTP dev to trusted HTTPS on 44300.*

### 1A — Fleet nodes

| Step | Action | Repo | Verify |
|------|--------|------|--------|
| **1.1** | Confirm LE cert active: `tls-active.json`, `openssl x509 -text` shows node + tenant SANs | pbx3 (node) | SANs present |
| **1.2** | Run **`apply-active-cert.sh`**; confirm nginx uses `snippets/pbx3-ssl-active.conf` | pbx3 | `nginx -t` OK |
| **1.3** | `curl -sS -o /dev/null -w '%{http_code}\n' https://08jzwn.pbx3.com:44300/up` | — | `200` |
| **1.4** | Repeat **1.1–1.3** on **bzy54n** | — | Both nodes HTTPS |

### 1B — SPA + Sanctum on HTTPS

| Step | Action | Repo | Verify |
|------|--------|------|--------|
| **1.5** | Update **`.env.development`**: `VITE_API_PROXY_TARGET=https://{fqdn}.pbx3.com:44300` (keep Vite proxy — avoids CORS for now) | pbx3spa | `npm run dev` |
| **1.6** | Login, whoami, navigate 3–4 panels, **Commit** dirty state | pbx3spa | No cert / CORS / Sanctum errors |
| **1.7** | Re-test **backup create + S3-only restore** over HTTPS proxy | pbx3spa + pbx3api | Same as LAN HTTP test |
| **1.8** | **Certificates** panel: view domains, **Sync with tenant list**, renew dry-run | pbx3spa | Toasts OK |

### 1C — Document and close

| Step | Action |
|------|--------|
| **1.9** | Update **`TODO.md`** — check off TLS finish pass (or note remaining gaps) |
| **1.10** | Update **`AGENT_HANDOFF.md`**: dev pattern is HTTPS API + Vite proxy |

**Phase 1 exit:** Both fleet nodes serve API on **trusted LE HTTPS**; local SPA dev works through Vite proxy without browser cert warnings on API calls.

---

## Phase 2 — pbx3api installer health checks (1 day)

*From `TODO.md` — fail install when the stack is broken.*

| Step | Action | File / area | Verify |
|------|--------|-------------|--------|
| **2.1** | After nginx/php-fpm setup, **DB symlink check**: exists, target resolves, `www-data` can read/write sqlite | `pbx3api/scripts/installer.sh` | Fails with clear message if bad |
| **2.2** | **`nginx -t`** + php-fpm socket exists | same | Non-zero exit on failure |
| **2.3** | **HTTP readiness**: `curl -k -s -o /dev/null -w '%{http_code}' https://127.0.0.1:44300/up` | same | Expect `200`; fail otherwise |
| **2.4** | Test on **clean Ubuntu 24.04** VM or disposable instance | — | Full install → all checks pass |
| **2.5** | Test **failure paths** (break symlink, bad nginx config) | — | Installer exits non-zero |

**Phase 2 exit:** Fresh install cannot succeed with a broken API layer.

---

## Phase 3 — fail2ban → nginx (½ day)

| Step | Action | Repo | Verify |
|------|--------|------|--------|
| **3.1** | Replace Apache **`apache-badbots`** jail in `jail.local` with nginx log path or disable until nginx jail exists | **pbx3** `pbx3-1/opt/pbx3/etc/fail2ban/jail.local` | No `/var/log/apache2/` references |
| **3.2** | Add **`/etc/fail2ban/jail.d/pbx3-api.conf`** fragment (optional): badbots-style filter on nginx access log | pbx3 or pbx3api installer | `fail2ban-client status` |
| **3.3** | Align with **`PBX3API_INSTALLER_NGINX_ADDITIONS.md`** § optional fail2ban | docs | Consistent |
| **3.4** | On test node: `fail2ban-client reload`; confirm jails start without error | node | No Apache dependency |
| **3.5** | Bump **pbx3 deb** + changelog if package ships fail2ban change | pbx3 | Next deb revision |

**Phase 3 exit:** fail2ban config matches nginx API reality.

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
| **6.5** | Optional git tag: `release-hardening-2026-05` |

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
| B1 | HTTPS API on both fleet nodes | `curl https://…:44300/up` → 200, trusted cert |
| B2 | SPA works on HTTPS via Vite proxy | Login + backup + certs OK |
| B3 | Installer health checks | Fresh install fails on broken nginx/DB |
| B4 | fail2ban nginx-aligned | No Apache log references |
| B5 | Help on all Tier 1–2 demo fields | Every label has `?` + useful text |
| B6 | Stakeholder rehearsal | Third party can follow demo script |

---

## First session (recommended)

1. **Phase 0.1** — write the stakeholder demo script.
2. **Phase 1.1–1.4** — HTTPS on `08jzwn`, then `bzy54n`.
3. **Phase 4.1** — start help audit on **ExtensionDetailView** + **BackupView**.
