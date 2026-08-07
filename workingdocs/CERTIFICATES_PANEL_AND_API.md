# Certificates panel and API

**Location:** **pbx3** repository, `workingdocs/CERTIFICATES_PANEL_AND_API.md` — all TLS documentation for the stack is consolidated under **pbx3/workingdocs/** (see **`TLS_AND_CERTIFICATES.md`** index).

**Purpose:** Plan the **Certificates** admin panel (**pbx3spa**), **`/certificates/*`** API (**pbx3api**), and related **pbx3** backend paths. **SBC fleet** uses **instance-only** LE (**`TLS_AND_CERTIFICATES.md` §0**). **Option A (multi-SAN)** — node + tenant **`cluster.fqdn`** — is **solo/direct only** (**`LETSENCRYPT_PER_TENANT_FQDN.md`**).

**Out of scope for this panel:** **3rd-party cert bundles** (manufacturer CA certs for provisioning verification, e.g. Snom, Yealink) — separate panel.

**References:**
- **`TLS_AND_CERTIFICATES.md`** — Canonical TLS overview (**§0 fleet lock**, custom → LE → snakeoil).
- **`LETSENCRYPT_PER_TENANT_FQDN.md`** — Solo/direct multi-SAN; firewall **pbx3_inline_fqdn**.
- **`APACHE_CONFIG_TO_PBX3API.md`** §3 — HTTP/nginx split; TLS ownership summary.
- **pbx3spa** `workingdocs/SINGLE_PANEL_SCREENS.md` — Certificates (#7), Certs 3rd Party (#8); routes `/certificates`, `/certificates/3rd-party`.

---

## 1. Two first-class options: purchased cert vs Let's Encrypt

**Users must be able to choose either:**

- **Purchased (custom) certificate** — Some users will upload their own certificate (e.g. from a commercial CA). They install cert + key via the panel; nginx and Asterisk use it for TLS until they remove it.
- **Let's Encrypt** — Automatic certs via **HTTP-01** (**`TLS_AND_CERTIFICATES.md`**). **Fleet:** one SAN = **instance FQDN**; **Sync certificate** re-issues that name only. **Solo/direct:** Option A may include tenant FQDNs (**`LETSENCRYPT_PER_TENANT_FQDN.md`**). No DNS API in the adopted path.

Both are supported. The system must **handle both** and make it clear which source is currently in use. There is no “primary” or “secondary” path: either a user has set up Let's Encrypt (via the pbx3 installer) or they have uploaded a purchased cert (via the panel), or neither (snakeoil fallback). The panel should present both options neutrally and show **Currently in use: Purchased certificate** or **Currently in use: Let's Encrypt** (or **Snakeoil** when neither is active).

---

## 2. Scope: two certificate areas (this panel only)

| Area | Owner | Purpose | Panel section |
|------|--------|---------|----------------|
| **Let's Encrypt** | pbx3 | Fleet: instance FQDN cert. Solo: optional multi-SAN. Status, **Renew now**, **Sync certificate**. | **Status** + “Cert covers …”; **Renew now**; **Sync**. |
| **Purchased / custom cert** | User, via API | User-supplied PEM + key. | **Install** / **Remove**. |

**Not in this panel:** 3rd-party cert bundles (manufacturer certs for provisioning verification — Snom, Yealink, etc.) are handled in a **separate panel**. See SINGLE_PANEL_SCREENS.md Certs 3rd Party (#8).

**Panel type:** Single-screen with **two cascaded sections** (see **pbx3spa** `PANEL_PATTERN.md`). One view at `/certificates`: **Let's Encrypt** and **Purchased certificate**. Fleet copy must **not** tell operators to put tenant FQDNs on the node cert.

---

## 3. Active certificate selection (which cert nginx/Asterisk use)

One TLS identity is active at a time. **Selection order** (fallback):

1. **Purchased (custom) cert** — If custom cert files exist and are valid at `/opt/pbx3/etc/ssl/custom/`, nginx and Asterisk use them.
2. **Let's Encrypt** — Else if LE is configured (`le-domain` exists with this host's FQDN and fullchain.pem exists), use LE.
3. **Snakeoil** — Else use the system snakeoil cert.

Custom takes precedence when present; removing the custom cert reverts to LE or snakeoil. No "mode" toggle: file presence defines which is active.

---

## 4. Data and source of truth

- **No DB table for certs.** Certificates are file-based. Metadata (which cert is “in use” for nginx/Asterisk) can be inferred from nginx config or from a small state file under `/opt/pbx3/etc/` if we need to remember “use custom” vs “use LE”.
- **LE:** This host's FQDN from `/opt/pbx3/etc/identity/le-domain` (e.g. `myhost.mydomain.com`). Cert files: `/etc/letsencrypt/live/<fqdn>/fullchain.pem`, `privkey.pem`. Expiry: read via `openssl x509 -enddate -noout -in fullchain.pem`.
- **Custom cert:** Define a single path pair, e.g. `/opt/pbx3/etc/ssl/custom/fullchain.pem` and `privkey.pem`. Nginx (and optionally Asterisk) can be pointed at these when present; otherwise use LE or snakeoil. API + syshelper write here on “Install”; “Remove” = delete or rename so nginx falls back.
- **3rd-party bundles:** Out of scope for this panel; see separate panel.

---

## 5. API design (pbx3api)

All cert endpoints require **auth:sanctum** and **abilities:admin** (same as other system panels). Privileged file access via **syshelper** (no sudo from API).

### 5.1 Active certificate (which source is in use)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/certificates/active` | Returns `{ "source": "custom" | "letsencrypt" | "snakeoil" }`. Derive from files: if custom fullchain.pem (and privkey.pem) exist and valid → `custom`; else if LE domain + fullchain exist → `letsencrypt`; else `snakeoil`. Panel uses this to show “Currently in use: …” |

### 5.2 Let's Encrypt

| Method | Path | Description |
|--------|------|-------------|
| GET | `/certificates/letsencrypt` | Returns status: `{ "configured": bool, "domain": string|null, "domains": string[]|null, "expires_at": "YYYY-MM-DD"|null, "issuer": string|null }`. **`domain`** = primary (**`le-domain`**). **`domains`** = all names intended on cert (from tenants / SAN list) when API implements **Option A** (**`LETSENCRYPT_PER_TENANT_FQDN.md`** Phase 2). |
| POST | `/certificates/letsencrypt/setup` | **First-time setup:** Body `{ "fqdn": "host.example.com", "email": "admin@example.com" }` or implementation builds full SAN list from **GET tenants** + email — see **`LETSENCRYPT_PER_TENANT_FQDN.md`**. Syshelper runs **`le-first-cert-multi`** (or extended **`le-first-cert.sh`**). |
| POST | `/certificates/letsencrypt/renew` | Trigger renewal: syshelper runs **`le-renew-with-80.sh`**. |
| POST | `/certificates/letsencrypt/sync` | **Manual re-issue** with current tenant FQDN list (**Option A**); **`TLS_AND_CERTIFICATES.md`** §6. |

**Implementation:** Controller reads `/opt/pbx3/etc/identity/le-domain` via syshelper (`cat le-domain`); file contains this host's FQDN (e.g. `myhost.mydomain.com`). Then `openssl x509 -enddate -noout -in /etc/letsencrypt/live/<fqdn>/fullchain.pem` via syshelper; parse `notAfter` to ISO date. Never return private key or cert body.

### 5.3 Purchased / custom cert

| Method | Path | Description |
|--------|------|-------------|
| GET | `/certificates/custom` | Returns `{ "installed": bool }`. Installed = custom fullchain.pem and privkey.pem exist and are valid. When installed, this cert is the active one (see §3). |
| POST | `/certificates/custom` | **Install (upload purchased cert):** Request body: multipart or JSON with two PEM bodies (e.g. `cert`, `key`). Validate: PEM format, key matches cert. Write to `/opt/pbx3/etc/ssl/custom/fullchain.pem` and `privkey.pem` via syshelper; nginx/Asterisk will use them automatically (custom takes precedence); reload nginx and Asterisk. |
| DELETE | `/certificates/custom` | **Remove:** Delete custom cert files via syshelper; system falls back to LE (if configured) or snakeoil; reload nginx and Asterisk. |

**Security:** Never return private key in GET. Validate cert/key pair server-side before writing. Return **422** with a clear message when validation fails (e.g. "Certificate and private key do not match", "Invalid PEM format") so the panel can show a helpful error.

**Not in this API:** 3rd-party cert bundles (manufacturer CA certs for provisioning verification) are served by a separate panel and API; not part of the Certificates panel scope.

---

## 6. pbx3 (backend) responsibilities

- **Let's Encrypt:** pbx3 owns LE (**`TLS_AND_CERTIFICATES.md`**, **`LETSENCRYPT_PER_TENANT_FQDN.md`**). **Target:** multi-SAN HTTP-01; **initial setup** and **Sync** from Certificates panel / API. Renewal via **`le-renew-with-80.sh`** (cron + **Renew now**). **No DNS API** in adopted path.
- **Purchased (custom) cert:** Define paths `/opt/pbx3/etc/ssl/custom/fullchain.pem` and `privkey.pem`. Nginx (and Asterisk) config must use **selection order** (§3): if custom cert exists and is valid, use it; else if LE exists, use LE; else snakeoil. Nginx config (or snippet) checks custom path first, then LE path, then snakeoil. No "mode" flag: file presence defines which is active. Optionally: script or config snippet that nginx includes — “if custom cert exists, use it; else use LE; else snakeoil.”
- **3rd-party bundle:** Out of scope for this panel. Manufacturer cert bundles (provisioning verification) are defined and used in the separate 3rd-party / provisioning panel.

---

## 7. Certificates panel (pbx3spa)

- **Route:** `/certificates` (single view). 3rd-party cert bundle has its own panel (separate route; see SINGLE_PANEL_SCREENS.md).
- **View:** `CertificatesView.vue` — single-screen with **two** cascaded sections (same structure as BackupView: section header, actions, message area, content).

**At the top:** One line showing **Currently in use: Purchased certificate** | **Let's Encrypt** | **Snakeoil** (from GET `/certificates/active`). Both purchased and LE are first-class.

- **Section 1 — Let's Encrypt** (for users who prefer automatic certs):  
  - **Fleet warning (prominent):** **DO NOT create DNS A records for tenant domains.** Tenant FQDNs are SIP domains only; A records for **instance** hostname only. Shown on the panel when posture is fleet. Canonical: **`TLS_AND_CERTIFICATES.md` §0**.  
  - **User-facing explanation:** "A certificate for this host's hostname (e.g. `myhost.mydomain.com`) is issued and renewed automatically via HTTP-01. Port 80 must be reachable from the internet only during issuance or renewal (a few minutes); you can leave it closed the rest of the time. No DNS API or wildcard — just an A record for this host's FQDN."  
  - **DNS requirement:** User must create an **A record** (and optionally AAAA) for this host's **instance** FQDN pointing to this server's IP before getting the certificate. **Not** for tenant shortuids.
  - **When configured:** Display primary hostname, **“Cert covers:”** list (from **`domains`** / **`cert_sans`**), Expires, Issuer. Buttons **Renew now** and **Sync certificate** (POST **`/certificates/letsencrypt/sync`**). Fleet intended list = instance FQDN only.  
  - **When not configured:** Setup form + **Get certificate** as today; implementation may use **multi-SAN** list from tenants (**`LETSENCRYPT_PER_TENANT_FQDN.md`**).
- **Section 2 — Purchased certificate** (for users who prefer their own cert):  
  - Display: “Customer certificate: In use” or “Not installed.”  
  - Buttons: **Install** (upload cert + key; POST `/certificates/custom`), **Remove** (DELETE with confirmation). When the user removes the purchased cert, the system reverts to Let's Encrypt (if configured) or snakeoil.
  - Use toast for success/error; firstErrorMessage for load errors.
- **Nav:** Add “Certificates” under System (or single panels) in the sidebar, linking to `/certificates`. 3rd-party bundle is a separate panel (e.g. "Certs 3rd Party" / provisioning verification).
- **Pattern:** Follow **pbx3spa** `PANEL_PATTERN.md` § single-screen / cascaded sections.

---

## 8. Security

- **Admin only:** All cert endpoints behind `abilities:admin`.
- **No private key in API responses:** GET endpoints never return private keys.
- **Validation:** Custom cert install must validate PEM format and that key matches cert (e.g. `openssl x509 -noout -modulus -in cert.pem` and `openssl rsa -noout -modulus -in key.pem`; hashes must match).
- **Privileged writes:** All file writes (custom cert install, and any “renew” trigger) go through **syshelper** (pbx3_request_syscmd). No direct file_put_contents to system paths from API.

---

## 9. Implementation order

1. **API: Active source (GET /certificates/active)**  
   - Returns `source`: `custom` | `letsencrypt` | `snakeoil` from file presence (custom first, then LE, then snakeoil). Panel uses this for “Currently in use: …”.
2. **API: LE status (GET /certificates/letsencrypt)**  
   - CertificateController; read le-domain + fullchain.pem via syshelper; parse expiry; return JSON. No renew yet.
3. **SPA: Certificates view shell + top line + LE section**  
   - CertificatesView.vue, route `/certificates`, nav link. Top: “Currently in use: …” from `/certificates/active`. Section 1: Let's Encrypt status (hostname, expires, issuer). Message when not configured.
4. **API: LE renew (POST /certificates/letsencrypt/renew)**  
   - Syshelper runs certbot renew (or lego) and deploy hook. Return 200/503.
5. **SPA: Renew now button**  
   - Call renew endpoint; toast; refetch status and active.
6. **pbx3: Custom cert paths and nginx selection order**  
   - Define `/opt/pbx3/etc/ssl/custom/`. Nginx (pbx3api) config or snippet: use custom if present and valid, else LE, else snakeoil (§3). Document in pbx3/pbx3api.
7. **API: Custom cert GET/POST/DELETE**  
   - GET `installed`; POST validate + write via syshelper; reload nginx + Asterisk. DELETE remove files; reload; fallback to LE or snakeoil.
8. **SPA: Purchased certificate section**  
   - Install (upload cert + key), Remove with confirmation. Show “Installed” and that it’s in use when active.
9. **Docs** — All certificate docs live under **pbx3** `workingdocs/`; update **pbx3spa** `SINGLE_PANEL_SCREENS.md` pointers if panel status text changes externally.

---

## 10. Existing code to change

This section lists **existing** files that must be modified (not new files like CertificateController or CertificatesView).

### 10.1 pbx3api

| File | Current state | Change |
|------|----------------|--------|
| **`config/nginx/pbx3-api.conf`** | Hardcoded snakeoil + commented LE paths (lines 6–10). | Stop hardcoding cert paths. Use an **include** for the active cert (e.g. `include snippets/pbx3-ssl-active.conf;`) and have the API/syshelper (or a script) **write** that snippet with the chosen paths (custom → LE → snakeoil). Alternatively, the same script could rewrite this server block's `ssl_certificate` / `ssl_certificate_key` lines. |
| **`routes/api.php`** | Admin certificate routes | Group: `certificates/active`, `certificates/letsencrypt`, **`letsencrypt/sync`** (**Option A**), `certificates/custom`; **`CertificateController`**. Add **`sync`** when implementing **`LETSENCRYPT_PER_TENANT_FQDN.md`**. |

### 10.2 pbx3spa

| File | Current state | Change |
|------|----------------|--------|
| **`src/router/index.js`** | No certificates route. | **Add** a child route under AppLayout, e.g. `{ path: 'certificates', name: 'certificates', component: CertificatesView }`, and **import** CertificatesView. |
| **`src/layouts/AppLayout.vue`** | Nav has Firewall, Asterisk Files, Logs, Backup, etc. | **Add** a nav link for Certificates (e.g. `<router-link to="/certificates" ...>Certificates</router-link>`) inside the `auth.can('admin')` block, in a sensible place (e.g. near Firewall/Backup). |

### 10.3 pbx3 (backend / Asterisk)

| File | Current state | Change |
|------|----------------|--------|
| **`pbx3-1/opt/pbx3/scripts/installer.sh`** | Only adds `asterisk`/`www-data` to `ssl-cert` (lines 62–65). No LE or custom cert dirs. | **Extend** so it creates `/opt/pbx3/etc/identity/` and `/opt/pbx3/etc/ssl/custom/` (or equivalent) if you want them at install time. **LE** prompts / flow per **`TLS_AND_CERTIFICATES.md`** and **`LETSENCRYPT_PER_TENANT_FQDN.md`** (multi-SAN when implemented). |
| **`pbx3-1/opt/pbx3/etc/asterisk/configs/http.conf`** | Static file with fixed snakeoil paths (lines 15–16). | Either **(a)** turn it into a **generated** file from a template that gets the "active" cert path (custom → LE → snakeoil), or **(b)** keep the file and have a **new** "cert-apply" script (and LE deploy hook) **rewrite** only the `tlscertfile` / `tlsprivatekey` lines so Asterisk follows the same selection order. |
| **`pbx3-1/opt/pbx3/etc/asterisk/templates/pjsip_transport.tmpl`** | Contains commented TLS block with snakeoil paths (lines 25–26). `[transport-wss]` has no cert lines. | If WSS is to use the same active cert, **add** (or uncomment and parameterise) `cert_file` / `priv_key_file` in the WSS section and use a placeholder (e.g. `$cert_file`, `$priv_key_file`) that the generator fills. |
| **`pbx3-1/opt/pbx3/php/classes/GenClass`** | `genPjsipTransport()` (around 334–368) only substitutes `$externip`; there's a ToDo to "deal with cert/key location". | **Implement** that: read the active cert path (from a small file written by API/syshelper, or from existing identity/le-domain + custom logic), and substitute cert/key paths into the template so generated `pjsip_transport.conf` uses the selected cert. |

### 10.4 pbx3 nginx reference (docs/deploy)

| File | Current state | Change |
|------|----------------|--------|
| **`pbx3/workingdocs/nginx-api-site-reference.conf`** | Same snakeoil + commented LE as pbx3api. | **Update** to match the chosen pattern (e.g. include for active cert or note that the real config is generated), so deploy/docs stay in sync with `pbx3-api.conf`. |

**Summary:** pbx3api = nginx config + api.php. pbx3spa = router + AppLayout. pbx3 = installer.sh, http.conf (or its generator), pjsip_transport.tmpl + GenClass, and the nginx reference doc. New code (CertificateController, CertificatesView, syshelper calls, cert-apply/reload scripts, LE deploy hook) is separate; this list is only existing code that must be changed.

---

## 11. What else to consider

- **Nginx config mechanics:** Nginx cannot conditionally choose cert paths by "if file exists" in config. So **selection order** (custom → LE → snakeoil) must be implemented by something that **writes** the active paths into the config (or an include file) when certs change. Options: (a) API (or a small script) writes an include snippet with `ssl_certificate` / `ssl_certificate_key` pointing at the chosen path after custom install/remove or LE deploy hook; (b) pbx3 installer / deploy hook always rewrites the snippet. Define who writes the snippet and where it lives (e.g. `/etc/nginx/snippets/pbx3-ssl.conf` or under pbx3api).

- **Asterisk config when custom cert changes:** When the user installs or removes the purchased cert via the API, **Asterisk** (http.conf, pjsip TLS) must be updated to use the same selection order. **`apply-active-cert.sh`** (see **pbx3/workingdocs/TLS_AND_CERTIFICATES.md**) should run after custom install/remove so Asterisk matches nginx. Otherwise only nginx would switch and Asterisk would still use the old cert.

- **Creating the custom cert directory:** On first custom install, `/opt/pbx3/etc/ssl/custom/` may not exist (installer might not create it). The API or syshelper should run `mkdir -p` for that path before writing fullchain.pem and privkey.pem.

- **Permissions after custom install:** After writing custom cert files, syshelper should set safe permissions (e.g. fullchain 644, privkey 600) and ownership so nginx and Asterisk can read. Document the chosen ownership (e.g. root:root with world-read for fullchain, root-only for key, or a shared group).

- **Purchased cert = fullchain:** Many CAs provide cert + chain (intermediates). Accept a single **fullchain** PEM (cert + intermediates concatenated) so TLS works correctly. UX: "Upload fullchain.pem (certificate + chain) and privkey.pem."

- **Custom cert expiry in the panel:** Optionally return `expires_at` for the installed custom cert (via `openssl x509 -enddate -noout`) in GET `/certificates/custom` so the panel can show "Expires: YYYY-MM-DD" and remind users to renew.

- **How the API gets PEM content to disk:** API receives multipart or JSON with cert/key. Laravel writes to a temp path (e.g. `storage_path('app/temp/')` or `/tmp`) then syshelper **moves** (and chowns) to the final path — same pattern as Firewall (temp file, syshelper mv). Do not stream content to syshelper; use temp file + mv.

- **Reload failure after install/remove:** If nginx or Asterisk reload fails after writing or removing the custom cert, report the error to the user and leave the files as-is (do not auto-revert). Admin can fix config or remove the cert manually.

- **Backup/restore:** Ensure instance backup (and restore) includes `/opt/pbx3/etc/ssl/custom/` and `/opt/pbx3/etc/identity/le-domain` so restored systems get the same cert state. May already be covered if backup includes `/opt/pbx3/etc/`; confirm and document.

- **Rate limiting (optional):** POST `/certificates/letsencrypt/renew` could be rate-limited (e.g. once per 10 minutes) to avoid abuse. Lower priority.

- **Verification after implementation:** Confirm (a) active source is correct for each state (snakeoil, LE only, custom only, after custom remove); (b) browser shows the expected cert over HTTPS; (c) invalid custom cert returns 422 with clear message; (d) renew failure is shown in the panel.

- **Firewall and port 80 for Let's Encrypt:** We use **HTTP-01** (individual cert per hostname). **Port 80 is only needed during** issuance or renewal. **Implemented:** `le-renew-with-80.sh` opens port 80 (Shorewall managed rule), runs certbot renew, then closes 80. "Renew now" (POST `/certificates/letsencrypt/renew`) and cron (twice daily) both call this script so we have control of port 80. See **pbx3/workingdocs/TLS_AND_CERTIFICATES.md**.

- **DNS for LE:** User creates one **A record** (and optionally AAAA) for this host's FQDN pointing to this server's IP. No TXT, no DNS API. Panel and docs state this clearly.

---

## 12. Open decisions

- **LE setup help:** Panel shows inline: "A record for this host's FQDN; run pbx3 installer with FQDN and LE email; port 80 reachable during issuance/renewal." Optional link to https://letsencrypt.org/docs/challenge-types/#http-01-challenge .

- **Custom cert path:** Confirm `/opt/pbx3/etc/ssl/custom/` and that pbx3api nginx config (or snippet) implements selection order: custom → LE → snakeoil (no “mode” file; file presence only).
- **Renew now:** Blocking (wait for certbot to finish) vs async (start and return; frontend polls status). Simpler: blocking with a 60s timeout; if certbot hangs, return 504.
- **Multiple custom certs:** Out of scope for v1; one purchased cert only. Future: multiple named certs for different services.

---

## 13. References

- **`TLS_AND_CERTIFICATES.md`** — Canonical overview (**this repo**).
- **`LETSENCRYPT_PER_TENANT_FQDN.md`** — Option A phases, firewall, prerequisites (**this repo**).
- **`APACHE_CONFIG_TO_PBX3API.md`** — TLS ownership (**this repo**).
- **https://letsencrypt.org/docs/challenge-types/#http-01-challenge** — HTTP-01.
- **pbx3spa** `workingdocs/SINGLE_PANEL_SCREENS.md` — panel index.
- **pbx3spa** `workingdocs/PANEL_PATTERN.md` — UI patterns.
- **pbx3api** `docs/SYSCOMMANDS_VIA_SYSHELPER.md` — privileged commands.
