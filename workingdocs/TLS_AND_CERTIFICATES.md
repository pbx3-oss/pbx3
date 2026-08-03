# TLS and certificates (canonical index)

**AI / humans:** All **TLS / certificate** documentation for the PBX3 stack lives in **this repo** under **`workingdocs/`**. Use the files below in order: **overview → linear steps → panel/API detail → per-tenant Option A spec**.

| Read first | File | Contents |
|------------|------|----------|
| 1 | **`TLS_AND_CERTIFICATES.md`** (this file) | Overview: ownership, custom → LE → snakeoil, **Option A** LE summary, script roles, API table, nginx/Asterisk, release follow-ups. |
| 2 | **`TLS_IMPLEMENTATION_STEPS.md`** | **Linear execution checklist:** Step 0 (prereqs) → Steps 1–4 (pbx3 → pbx3api → pbx3spa → integration); no substitute for §12 rationale — cross-links to **`LETSENCRYPT_PER_TENANT_FQDN.md`**. |
| 3 | **`CERTIFICATES_PANEL_AND_API.md`** | Certificates **panel** (**pbx3spa**), **`/certificates/*`** API, security, implementation order, **existing files to change**. |
| 4 | **`LETSENCRYPT_PER_TENANT_FQDN.md`** | **Option A** full spec: options B/C/D comparison, **pbx3_inline_fqdn**, **§11** prerequisites, **§12** phases (pbx3 → pbx3api → pbx3spa), tenant migration notes. |

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
2. **Let’s Encrypt** — Material under **`/etc/letsencrypt/live/<primary>/`**. **`/opt/pbx3/etc/identity/le-domain`** = **primary** (certbot live dir basename). The cert may list **many SANs** (**Option A**): node + all **`cluster.fqdn`** included at last setup/sync.
3. **Snakeoil** — if neither custom nor LE is usable.

**`apply-active-cert.sh`** applies the resolved pair to nginx + Asterisk **`http.conf`**. **Option A** still uses **one** cert path (multi-SAN in **one** PEM).

**Asterisk WSS / WebRTC (`:8089`):** LE trees default to root-only keys. apply-active-cert also: (1) adds **`asterisk`** (and **www-data**) to group **`ssl-cert`**, (2) makes **`/etc/letsencrypt/{live,archive}`** group-readable (`750` dirs, `640` privkeys), (3) **`systemctl restart asterisk`** so TLS rebinds if the previous start failed quietly (plain **:8088** only). Without this, rebuild/LE leaves **“connecting”** webphones. See **`WEBRTC_WSS_LAB.md`**.

**Out of scope:** Manufacturer “3rd party” CA bundles — separate panel (**`CERTIFICATES_PANEL_AND_API.md`**).

---

## 3. Let’s Encrypt — Option A (multi-SAN, HTTP-01)

Summary only — detail: **`LETSENCRYPT_PER_TENANT_FQDN.md`** §4, §10–§12.

| Topic | Choice |
|-------|--------|
| **Cert shape** | One LE cert per node; SANs = **primary** (node) + **all tenant FQDNs** on the node. |
| **Challenge** | **HTTP-01**; **each** SAN must resolve here at issuance/sync. **No DNS API**. |
| **SAN limit** | ~**50** names (LE policy); above that see options B/C in **`LETSENCRYPT_PER_TENANT_FQDN.md`**. |
| **Re-issue SAN list** | **Manual** — **POST `/certificates/letsencrypt/sync`** (see **`CERTIFICATES_PANEL_AND_API.md`** §5). |
| **Renewal** | **`certbot renew`** + **`le-renew-with-80.sh`**; renewal profile holds all SANs if first issue did. |

**Scripts:** **`le-port80-open.sh` / `close`**, **`le-first-cert.sh`** (or **`le-first-cert-multi.sh`**), **`le-renew-with-80.sh`**, **`apply-active-cert.sh`**, **`update-fqdn-inline.sh`** — see **`LETSENCRYPT_PER_TENANT_FQDN.md`** §10.1. **`PBX3_SYSCMD_TIMEOUT` ≥ 90** for panel setup/renew/sync.

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
| POST | `/certificates/letsencrypt/setup` | multi-SAN first issue (**implementation:** **`LETSENCRYPT_PER_TENANT_FQDN.md`** Phase 2) |
| POST | `/certificates/letsencrypt/renew` | **`le-renew-with-80.sh`** |
| POST | `/certificates/letsencrypt/sync` | manual SAN re-issue |
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
- **APACHE_CONFIG_TO_PBX3API.md** Phase 4 (DNS-01 wildcard) — **not** adopted; **Option A** is HTTP-01 multi-SAN.

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
