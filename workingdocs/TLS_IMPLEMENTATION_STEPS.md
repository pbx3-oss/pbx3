# TLS / Option A — step-by-step implementation

**Purpose:** One **linear** checklist for engineers (or agents) implementing **Option A** — Let’s Encrypt **multi-SAN** (node + all tenant **`cluster.fqdn`**) + **pbx3_inline_fqdn** firewall rules.

**Deep spec:** **`LETSENCRYPT_PER_TENANT_FQDN.md`** (options, §9 firewall detail, product decisions).  
**Panel + API tables:** **`CERTIFICATES_PANEL_AND_API.md`**.  
**Overview:** **`TLS_AND_CERTIFICATES.md`**.

**Plan agent?** Not required. Use Cursor **Plan mode** only if you want to **change** strategy (e.g. wildcard DNS-01) or resolve ambiguous product tradeoffs. Execution order below is already fixed.

**Branch:** Feature branch from **`main`** in each repo you touch (typically **pbx3** first, then **pbx3api**, then **pbx3spa**).

**Automated checks:** **`pbx3/scripts/tls-implementation-tests/`** — run **`./run-all.sh`** or **`./stepN.sh`** (see **`README.md`** in that folder for env vars).

---

## Step 0 — Prerequisites (before Phase 1)

Complete **all** before writing multi-SAN cert code. (Table from **`LETSENCRYPT_PER_TENANT_FQDN.md`** §11.) **Implemented on branch `certificates`:** 0.1–0.4 below (installer + pbx3api + Instance Globals UI).

| # | Task | Repo / area |
|---|------|----------------|
| 0.1 | **Base apex domain** for tenant hostnames: **`globals.domain`** (GET sysglobals JSON field **`domain`**). Installer sets **`globals.domain`** and **`globals.fqdn`**. **API:** **`domain`** and **`fqdn`** are no longer in **`SysglobalController`** **`$updateableColumns`** (install-time identity). | **pbx3** + **pbx3api** |
| 0.2 | Ensure **default tenant** has **`cluster.fqdn`** (and **`domain`**) = **node FQDN** after install. **`installer.sh`** runs **`UPDATE cluster … WHERE pkey='default'`** when that row exists. | **pbx3** installer |
| 0.3 | **GET/PUT sysglobals** includes **`fqdninspect`** (TEXT **YES**/**NO**). **`Sysglobal`:** removed from **`$hidden`**; **`SysglobalController`:** validate **`fqdninspect`**. **pbx3spa:** Instance Globals shows/edits FQDN inspect pill. | **pbx3api** + **pbx3spa** |
| 0.4 | **Tenant create** returns **shortuid**; **`fqdn`** / **`domain`** set from **`globals.domain`** (optional body override on create). **Updates:** **`fqdn`** and **`domain`** removed from **`$updateableColumns`** (immutable after create). | **pbx3api** `TenantController` |

**Gate:** You can read **`domain`** and **`fqdninspect`** from GET sysglobals, and create a tenant with a deterministic hostname from **`globals.domain`**.

---

## Step 1 — pbx3 backend (scripts + firewall)

| # | Task | Details |
|---|------|---------|
| 1.1 | **Multi-SAN first issue** | Add **`le-first-cert-multi.sh`** *or* extend **`le-first-cert.sh`**: args or file with FQDN list + email → `certbot certonly --standalone -d …` (all names) → write **first** `-d` to **`/opt/pbx3/etc/identity/le-domain`** → **`apply-active-cert.sh`**. Renewal config must list **all** SANs. |
| 1.2 | **`NetHelperClass::copyFirewallTemplates()`** | If **`globals.fqdninspect`**: load all non-null **`cluster.fqdn`**; for each, emit **TCP + UDP** INLINE rules on **`globals.bindport`**, string **`sip:<fqdn>`**, `--to 1000`. If disabled: comment-only file. |
| 1.3 | **`update-fqdn-inline.sh`** | Shell (or PHP invoker) that runs 1.2’s logic, writes **`pbx3_inline_fqdn`**, then **restarts Shorewall** (product decision: auto restart). Install under **`/opt/pbx3/scripts/`**; ship in **pbx3-1**. |
| 1.4 | **Package / perms** | Ensure new script is executable in package; document in **AGENT_HANDOFF** key paths if new files appear. |
| 1.5 | **Verify** | Dev box: two tenant FQDNs + fqdninspect ON → run **update-fqdn-inline** → Shorewall restarts → **`pbx3_inline_fqdn`** has two rules per FQDN with **`sip:`** prefix. Run **le-first-cert-multi** → **`openssl x509 -text`** shows both SANs. |

---

## Step 2 — pbx3api (syshelper + controllers)

| # | Task | Details |
|---|------|---------|
| 2.1 | **Domain list helper** | Internal helper: domain list = all **`cluster.fqdn`** (non-null) from **GET tenants** (same logic as controller queries). No FQDN in sysglobals payload except via tenants. |
| 2.2 | **POST `/certificates/letsencrypt/setup`** | Build list from 2.1 + email → syshelper → **`le-first-cert-multi`**. Keep **409** if already configured. **`PBX3_SYSCMD_TIMEOUT` ≥ 90**. |
| 2.3 | **GET `/certificates/letsencrypt`** | Add **`domains`** array (tenant FQDNs). Keep **`domain`** = primary from **`le-domain`**. |
| 2.4 | **POST `/certificates/letsencrypt/sync`** | **Manual only:** rebuild list from 2.1 → re-issue (same cert name / **`le-domain`**). |
| 2.5 | **FirewallController** | **`ipv4restart` / `ipv6restart`**: before Shorewall, syshelper runs **update-fqdn-inline** (writes file + restarts Shorewall per script — avoid double restart if script already restarts; align implementation). |
| 2.6 | **TenantController** | **Create:** ensure **`fqdn` = `shortuid + "." + globals.domain`** (already when request omits **`fqdn`**/**`domain`**); **immutable** later if required by product. **After create/update/delete:** syshelper **update-fqdn-inline** (Shorewall auto per product decision). |
| 2.7 | **SysglobalController** | After PUT affecting **fqdninspect** / relevant globals: **update-fqdn-inline**. |
| 2.8 | **Syshelper registration** | Wire new script paths and timeouts; follow **`SYSCOMMANDS_VIA_SYSHELPER.md`**. |
| 2.9 | **Verify** | API-only tests: setup returns multi-SAN cert; GET shows **domains**; tenant create sets **fqdn** and triggers inline update; firewall restart path runs updater. |

---

## Step 3 — pbx3spa (UI)

| # | Task | Details |
|---|------|---------|
| 3.1 | **TenantDetailView** | Read-only **Tenant FQDN** (from API **`cluster.fqdn`** or derived display consistent with API). |
| 3.2 | **TenantCreateView** | Hint: FQDN assigned on create; no edit field. |
| 3.3 | **CertificatesView** | Show **“Cert covers: …”**. Button **Sync certificate** → **POST `/certificates/letsencrypt/sync`**. Fleet = instance FQDN only (**`TLS_AND_CERTIFICATES.md` §0**). |
| 3.4 | **Verify** | Browser: Certificates Sync succeeds; nginx/Asterisk load via **`apply-active-cert`**. |

---

## Step 4 — Integration, ops, handoff

| # | Task | Details |
|---|------|---------|
| 4.1 | **Cron** | Confirm **`le-renew-with-80.sh`** + cron renews cert; deploy hook **`apply-active-cert.sh`**. |
| 4.2 | **Tenant move runbook** | **SBC fleet:** setid + catalog; **no** tenant DNS/SAN. **Solo/direct:** dest Sync may add tenant SAN; source Sync after wipe. **`TENANT_MIGRATION_RUNBOOK.md`**. |
| 4.3 | **TLS release pass** | HTTPS **44300**, trusted cert, CORS, Sanctum (**`TODO.md`**). |
| 4.4 | **Handoff docs** | Point to **`TLS_AND_CERTIFICATES.md`** (**§0**). |

---

## Optional follow-ons

- **`POST /syscommands/refresh-fqdn-inline`** without full firewall restart (support tooling).
- Per-tenant **fqdninspect** (today: global only).
- **GenClass** / **`pjsip_transport`** active cert paths (**`CERTIFICATES_PANEL_AND_API.md`** §10.3) if not already aligned with **`apply-active-cert`**.

---

## Quick reference — product decisions (do not “improve” without approval)

1. **Cert sync:** manual (**Sync** button only).  
2. **Firewall:** after **update-fqdn-inline**, **restart Shorewall** automatically.  
3. **FQDN storage:** Tenant hostname material is **`cluster.fqdn`** (API field **`fqdn`**); apex for the tenant suffix is **`globals.domain`** (API **`domain`**). **`fqdninspect`** lives on **globals** (instance) for the firewall plan.  
4. **New tenant FQDN:** **`{tenant_shortuid}.globals.domain`** (tenant **`shortuid`** on create), **immutable** after create — *this is not the instance hostname.*  
5. **Node / instance FQDN:** **`globals.fqdn`** = `{subdomain}.{apex}`; the **`subdomain`** is generated by the **installer** (typically **6-char `idpwgen`**, or legacy **`INSTANCE_FQDN`**). Instance **globals** do not store a separate **`shortuid`** column. Treat **`globals.fqdn`** as **install-time and long-lived**; changing it is an ops migration, not routine UI.
