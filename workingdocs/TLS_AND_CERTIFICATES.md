# TLS and certificates (canonical index)

**AI / humans:** All **TLS / certificate** documentation for the PBX3 stack lives in **this repo** under **`workingdocs/`**. Use the files below in order: **overview → linear steps → panel/API detail → per-tenant Option A (solo/direct only)**.

| Read first | File | Contents |
|------------|------|----------|
| 1 | **`TLS_AND_CERTIFICATES.md`** (this file) | Overview: ownership, custom → LE → snakeoil, **§0 fleet lock**, LE paths, script roles, API table, nginx/Asterisk. |
| 2 | **`TLS_IMPLEMENTATION_STEPS.md`** | **Linear execution checklist:** Step 0 (prereqs) → Steps 1–4 (pbx3 → pbx3api → pbx3spa → integration); no substitute for §12 rationale — cross-links to **`LETSENCRYPT_PER_TENANT_FQDN.md`**. |
| 3 | **`CERTIFICATES_PANEL_AND_API.md`** | Certificates **panel** (**pbx3spa**), **`/certificates/*`** API, security, implementation order, **existing files to change**. |
| 4 | **`LETSENCRYPT_PER_TENANT_FQDN.md`** | **Option A** multi-SAN — **solo / direct-to-node only** (not SBC fleet default). |

---

## 0. Locked — SBC fleet DNS & node LE (2026-08-06)

> ### WARNING — DO NOT create DNS A records for tenant domains
>
> On an **SBC fleet**, tenant names such as `{shortuid}.pbx3.com` are **SIP domain strings only**.  
> **Do not** add public **A** (or AAAA) records for them.  
> Doing so breaks the model (wrong LE Sync expectations, cert churn, confusion on move).  
> DNS **A** records belong to **instance** FQDNs (`08jzwn…`, `bzy54n…`, …), **SBC**, and **control** — not tenants.  
> Phones register to the **SBC**; SPA opens the **instance** API URL from the catalog.

**Product default** is an **SBC-fronted fleet**. Lab-proven: tenant public **A** records removed; WSS + desk SIP still green.

| Concern | Stance |
|---------|--------|
| **Tenant FQDN** | SIP **domain string** + OpenSIPS `domain` → setid. **No public A record** required. |
| **SPA / admin API** | Catalog → **instance** DNS (`api_base_url` / `{instance}.{apex}`). |
| **Node Let’s Encrypt** | **Instance FQDN only** (HTTP-01). Setup/Sync must **not** add tenant SANs on fleet nodes. |
| **WSS** | Host = **edge or instance** (`wss://sbc…` / instance). SIP domain = tenant FQDN — **separate** names. See **`WEBRTC_WSS_LAB.md`** § SIP domain vs next hop. |
| **Move cutover** | SBC `domain` setid repoint — **not** tenant DNS. **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §7. |

**Solo / direct-to-node (no SBC):** tenant A records + **Option A** multi-SAN remain valid — **`LETSENCRYPT_PER_TENANT_FQDN.md`**.

**Ops:** Do **not** run SPA “Sync” expecting tenant SANs on fleet nodes. CLI: `le-sync-cert-sans.sh <email> <instance-fqdn>` only.

**Repos:** **pbx3** owns acquisition, renewal, applying certs, and **this documentation**. **pbx3api** owns nginx vhost + references paths. **pbx3spa** owns the Certificates UI. **pbx3spa** and **pbx3api** carry **stubs only** that point here (see their `workingdocs/`).

**HTTP/API split:** **`APACHE_CONFIG_TO_PBX3API.md`** — why nginx is not in pbx3; legacy Phase 4 DNS-01 sketches are **not** the adopted LE path.

---

## 1. Ownership

| Responsibility | Owner |
|----------------|--------|
| ACME / certbot (LE), Shorewall port 80 for HTTP-01, `le-domain`, custom cert directory, `apply-active-cert.sh` | **pbx3** |
| Reload **nginx** and **Asterisk** after cert change | **pbx3** (scripts / deploy hook) |
| `http.conf`, PJSIP TLS transport templates, generator (`GenClass`) | **pbx3** |
| FQDN inline firewall template (**`pbx3_inline_fqdn`**) when **fqdninspect** is enabled | **pbx3** (`NetHelperClass` / **`update-fqdn-inline.sh`** — **`LETSENCRYPT_PER_TENANT_FQDN.md`**) |
| nginx site for API: listen **44300**, `ssl_certificate` / `ssl_certificate_key`, PHP-FPM | **pbx3api** |
| Certificates admin UI | **pbx3spa** |
| HTTP routes: `/certificates/*` | **pbx3api** (admin + Sanctum; syshelper for privileged I/O) |

---

## 2. Three sources; one active identity

Exactly **one** server TLS **material** (one key pair + chain) is active for nginx and Asterisk at a time. **Precedence** (first match wins):

1. **Custom (commercial or user-provided)** — PEM at **`/opt/pbx3/etc/ssl/custom/fullchain.pem`** and **`privkey.pem`** (fullchain = leaf + intermediates).
2. **Let’s Encrypt** — Material under **`/etc/letsencrypt/live/<primary>/`**. **`/opt/pbx3/etc/identity/le-domain`** = **primary** (certbot live dir basename). **Fleet:** one SAN = instance FQDN (**§0**). **Solo/direct:** may be multi-SAN (**Option A** — node + **`cluster.fqdn`**).
3. **Snakeoil** — if neither custom nor LE is usable.

**`apply-active-cert.sh`** applies the resolved pair to nginx + Asterisk **`http.conf`**. One cert path always (single or multi-SAN PEM).

**Asterisk WSS / WebRTC (`:8089`):** LE trees default to root-only keys. apply-active-cert also: (1) adds **`asterisk`** (and **www-data**) to group **`ssl-cert`**, (2) makes **`/etc/letsencrypt/{live,archive}`** group-readable (`750` dirs, `640` privkeys), (3) **`systemctl restart asterisk`** so TLS rebinds if the previous start failed quietly (plain **:8088** only). Without this, rebuild/LE leaves **“connecting”** webphones. See **`WEBRTC_WSS_LAB.md`**.

**Out of scope:** Manufacturer “3rd party” CA bundles — separate panel (**`CERTIFICATES_PANEL_AND_API.md`**).

---

## 3. Let’s Encrypt

| Mode | Cert shape | Detail |
|------|------------|--------|
| **SBC fleet (default)** | Instance FQDN **only** | **§0**; Setup/Sync via API omit tenant SANs |
| **Solo / direct** | **Option A** multi-SAN (node + tenant FQDNs) | **`LETSENCRYPT_PER_TENANT_FQDN.md`** §4, §10–§12 |

| Topic | Choice |
|-------|--------|
| **Challenge** | **HTTP-01**; **each** SAN must resolve here at issuance/sync. **No DNS API**. |
| **Re-issue** | **Manual** — **POST `/certificates/letsencrypt/sync`** (**`CERTIFICATES_PANEL_AND_API.md`** §5). Fleet = instance only. |
| **Renewal** | **`certbot renew`** + **`le-renew-with-80.sh`**; keeps SANs from last issue/sync. |

**Scripts:** **`le-port80-open.sh` / `close`**, **`le-first-cert.sh`** / **`le-first-cert-multi.sh`**, **`le-sync-cert-sans.sh`**, **`le-renew-with-80.sh`**, **`apply-active-cert.sh`**, **`update-fqdn-inline.sh`**. **`PBX3_SYSCMD_TIMEOUT` ≥ 90** for panel setup/renew/sync.

---

## 4. Commercial / purchased certificates

Custom **overrides** LE. Wildcard / multi-SAN purchased certs cover tenant hostnames without LE. **`CERTIFICATES_PANEL_AND_API.md`** §6, **`LETSENCRYPT_PER_TENANT_FQDN.md`** §6.

---

## 5. nginx (pbx3api)

One **`ssl_certificate` / `ssl_certificate_key`** pair; multi-SAN cert serves all names on **44300**. **`CERTIFICATES_PANEL_AND_API.md`** §10.1; **pbx3api** **`docs/deployment-nginx.md`**; **PBX3API_INSTALLER_NGINX_ADDITIONS.md**.

---

## 6. API (pbx3api)

| Method | Path | Purpose |
|--------|------|--------|
| GET | `/certificates/active` | `source`: `custom` \| `letsencrypt` \| `snakeoil` |
| GET | `/certificates/letsencrypt` | configured?, **primary** `domain`, **`domains[]`**, expiry, issuer |
| POST | `/certificates/letsencrypt/setup` | first issue (fleet = instance FQDN; solo = Option A list) |
| POST | `/certificates/letsencrypt/renew` | **`le-renew-with-80.sh`** |
| POST | `/certificates/letsencrypt/sync` | re-issue with current intended SAN list (fleet = instance only) |
| GET/POST/DELETE | `/certificates/custom` | purchased cert install/remove |

Detail: **`CERTIFICATES_PANEL_AND_API.md`** §5.

---

## 7. Asterisk and generator

**`GenClass::genPjsipTransport()`** — **`CERTIFICATES_PANEL_AND_API.md`** §10.3.

---

## 8. Security and operations

**`CERTIFICATES_PANEL_AND_API.md`** §8. Backup **`/opt/pbx3/etc/ssl/custom/`**, **`le-domain`**, DB / **`cluster.fqdn`**.

---

## 9. Install order

**INSTALL_SEQUENCE_UBUNTU.md**. Prerequisites: **`LETSENCRYPT_PER_TENANT_FQDN.md`** §11.

---

## 10. Implementation checklist

**Day-to-day order:** **`TLS_IMPLEMENTATION_STEPS.md`** (Step 0 → 4, numbered tables). **Rationale and firewall detail:** **`LETSENCRYPT_PER_TENANT_FQDN.md`** **§12** (Phases 1–4). Panel/API file lists: **`CERTIFICATES_PANEL_AND_API.md`** §9–10.

**Automated step checks:** shell scripts under **`scripts/tls-implementation-tests/`** — see **`README.md`** there (`./run-all.sh`, env vars **`PBX_SQLITE`**, **`PBX3API_BASE`**, **`PBX3API_TOKEN`**).

---

## 11. Release checklist / follow-ups

- **Phases 1–4** (`LETSENCRYPT_PER_TENANT_FQDN.md`).
- **TLS finish pass:** HTTPS **44300**, CORS, Sanctum (**TODO.md**).
- **pbx3api installer health** (**TODO.md**).
- **APACHE_CONFIG_TO_PBX3API.md** Phase 4 (DNS-01 wildcard) — **not** adopted; LE is HTTP-01 (fleet instance-only or solo Option A).

---

## 12. Other related files

| Location | Use |
|----------|-----|
| **scripts/tls-implementation-tests/README.md** (in **pbx3**) | Bash gates for **`TLS_IMPLEMENTATION_STEPS.md`** (run **`./run-all.sh`**) |
| **APACHE_CONFIG_TO_PBX3API.md** | nginx vs pbx3 |
| **PBX3API_INSTALLER_NGINX_ADDITIONS.md** | pbx3api installer |
| **nginx-api-site-reference.conf** | reference vhost |
| **INSTALL_SEQUENCE_UBUNTU.md** | install order |
| **pbx3api** `docs/deployment-nginx.md`, **README.md** | deploy + ownership |
| **pbx3spa** `TRUNK_ROUTE_MULTITENANCY.md` | tenant move |
| **pbx3spa** `CENTRAL_ADMIN_DIRECTION.md` | **Future:** central admin + instance directory (Model B); per-node TLS remains data-plane |
| **`pbx3-directory/`** (repo root stub) | Instance index schema v0 (S3/map TBD) |

---

***LETSENCRYPT_PLAN.md** is a redirect stub; history preserved in git.*
