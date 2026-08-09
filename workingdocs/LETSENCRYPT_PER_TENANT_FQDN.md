# Let's Encrypt and per-tenant FQDN (Option A — full specification)

**Status (2026-08-06):** **Not the SBC-fleet default.** Product/lab **SBC fleet** uses **no tenant public A records** and **instance-only** node LE — lock in **`TLS_AND_CERTIFICATES.md` §0**. This file remains the **solo / direct-to-node** path (phones resolve tenant FQDN → node; multi-SAN HTTP-01). Firewall **`pbx3_inline_fqdn`** / `fqdninspect` still apply on fleet for SIP STRING match (not LE/DNS).

**Purpose:** Plan how to support **per-tenant FQDNs** (`{tenant_shortuid}.{globals.domain}`) with TLS certificates when the node is the phone-facing hostname (solo/direct).

**Adopted strategy (solo/direct only):** **Option A** (multi-SAN HTTP-01 — one cert: node + all tenant FQDNs). **Short overview:** **`TLS_AND_CERTIFICATES.md`**. **Certificates panel / API detail:** **`CERTIFICATES_PANEL_AND_API.md`**. **This file** is the **detailed** design: options comparison, firewall **pbx3_inline_fqdn**, prerequisites (**§11**), implementation phases (**§12**).

**Context:** Read **`TLS_AND_CERTIFICATES.md`** (especially **§0**), **`CERTIFICATES_PANEL_AND_API.md`**, and mobility **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §7. The **cluster** table already has `fqdn` and `fqdninspect`; the API Tenant model exposes `fqdn`.

---

## 1. Goal

- **Tenant FQDN:** Each tenant has a stable FQDN: `{tenant_shortuid}.{globals.domain}` (e.g. `abc12xyz.pbx3.com` when **`globals.domain`** is `pbx3.com`). Phones and other endpoints **find the tenant by this domain name** (provisioning, SIP, API).
- **Tenant mobility:** A future supertask will export/import tenants between nodes. When a tenant moves, its FQDN should resolve to the **new** node; DNS must be updated (or already point to a load balancer that routes by tenant).
- **TLS:** Connections to `{tenant_shortuid}.{globals.domain}` must use a certificate that is valid for that hostname (no browser/phone cert mismatch).

**Out of scope for this doc:** The exact supertask design, DNS automation (who creates A/CNAME for tenant FQDNs), or load balancers. This doc focuses on **certificate strategy** on a single node that may host many tenants.

---

## 2. Current state (single cert per node)

| Item | Current behaviour |
|------|-------------------|
| **LE scope** | One FQDN per node, stored in `/opt/pbx3/etc/identity/le-domain` (e.g. `node1.pbx3.com`). |
| **Cert path** | `/etc/letsencrypt/live/<fqdn>/` (fullchain.pem, privkey.pem). |
| **Challenge** | HTTP-01 only; port 80 opened only during issuance/renewal. No DNS API. |
| **nginx** | Single server block on 44300, `server_name _;`, one `include snippets/pbx3-ssl-active.conf` (one cert). |
| **Asterisk** | http.conf and PJSIP TLS use the same single cert. |
| **Tenant FQDN** | Schema: `cluster.fqdn` exists; not yet used for LE or virtual hosting. |

So today, if a phone connected to `abc12xyz.pbx3.com` (tenant FQDN) but the cert was for `node1.pbx3.com`, the client would see a **certificate name mismatch** unless we change strategy.

---

## 3. Assumptions

- **Base domain:** There is a single base domain for tenant hostnames, e.g. `pbx3.com`, so tenant FQDNs are `{shortuid}.pbx3.com`. (If per-customer domains are needed, the options below still apply per base domain.)
- **DNS:** For any option, each tenant FQDN must eventually resolve to the correct node (A record or CNAME). Who creates these (manual, API, supertask) is a separate concern.
- **One node, many tenants:** A node can host multiple tenants; each may have its own FQDN. We need either one cert that covers all those FQDNs, or multiple certs with SNI.

---

## 4. Viable options

### Option A: Single cert with multiple SANs (all tenant FQDNs + node FQDN)

**Idea:** One certificate that includes the **node FQDN** and **every tenant FQDN** on this node (e.g. `node1.pbx3.com`, `abc12xyz.pbx3.com`, `def99uvw.pbx3.com`). Same cert for nginx and Asterisk; no SNI needed.

**Mechanics:**

- Certbot (or lego) with multiple `-d` flags:  
  `certbot certonly --standalone -d node1.pbx3.com -d abc12xyz.pbx3.com -d def99uvw.pbx3.com -m admin@example.com`
- **HTTP-01:** Each `-d` hostname must resolve to this server; port 80 is opened; certbot serves the challenge for each. So all tenant FQDNs must point to this node before issuance/renewal.
- **Storage:** Keep a list of FQDNs (node + tenants) in a file or derive from DB (e.g. `globals.fqdn` + `SELECT fqdn FROM cluster WHERE fqdn IS NOT NULL`). Cert lives in one path, e.g. `/etc/letsencrypt/live/node1.pbx3.com/` (certbot uses the first `-d` as the live dir name).
- **When to re-issue:** Whenever a tenant is **added** or **removed** (or their FQDN changes), the cert must be re-issued with the new SAN list. So: new tenant → set `cluster.fqdn` → run a script that requests a new cert with updated domain list → apply-active-cert.
- **Renewal:** `certbot renew` (cron / **Renew now**) keeps the **same** SANs as the cert on disk; it does not read the DB. After tenant add/remove or backup restore, use **Sync certificate** (`le-sync-cert-sans.sh`) to replace the cert with the current FQDN list.

**Pros:**

- One cert, one key; nginx/Asterisk config unchanged (same snippet, one cert path).
- No DNS API; HTTP-01 only.
- Phones get a valid cert for their tenant FQDN (it’s in the SAN list).

**Cons:**

- Let's Encrypt limit **50 SANs per certificate** (as of current policy). If a node has >50 tenants with FQDNs, you need either multiple certs + SNI or a different approach.
- Re-issue on every tenant add/remove (or batch periodically). Rate limits (50 certs per week per domain) may matter if tenants churn a lot.
- Renewal must know the current tenant list; renewal script reads from DB or from a maintained file.

**Changes required:**

- **pbx3:** Script that builds domain list (node + all tenant FQDNs from cluster table), runs certbot with multiple `-d`. Call it from API when adding/removing tenant FQDN and from cron for renewal. `le-domain` could become `le-domains` (one FQDN per line) or keep node as primary and add a separate “tenant FQDN list” source.
- **Certificates panel (optional):** Show “Cert covers: node1.pbx3.com, abc12xyz.pbx3.com, …” and “Add tenant FQDN” flow that triggers re-issue.
- **Tenant panel:** When setting `cluster.fqdn` to `{shortuid}.{globals.domain}`, trigger cert re-issue (or queue it). Ensure DNS is created (manual or later automation).

---

### Option B: Wildcard cert per base domain (`*.{globals.domain}`)

**Idea:** One certificate with SAN `*.pbx3.com` (and optionally `pbx3.com`). Covers **all** tenant FQDNs that match the pattern `{shortuid}.pbx3.com`, and the node FQDN if it’s under the same domain (e.g. `node1.pbx3.com`).

**Mechanics:**

- **DNS-01 challenge:** Required for wildcards. Certbot/lego creates a TXT record `_acme-challenge.pbx3.com` (or per-name); LE validates; then you get `*.pbx3.com`.
- **DNS API:** You need a DNS provider that supports API updates (e.g. Route53, Name.com, Cloudflare). Credentials (or IAM) must be available on the node (or on a central “cert server” that distributes the cert).
- **Storage:** Single cert in e.g. `/etc/letsencrypt/live/pbx3.com/` (or similar). Same apply-active-cert pattern; nginx/Asterisk use this one cert.
- **Renewal:** Standard certbot/lego renewal; DNS-01 again. No need to know tenant list; new tenants automatically covered.

**Pros:**

- One cert covers all current and **future** tenants; no re-issue when adding/removing tenants.
- No port 80 needed for challenge.
- Simple operational model once DNS API is in place.

**Cons:**

- **DNS API and credentials** — The baseline **TLS_AND_CERTIFICATES.md** (HTTP-01, no DNS API) and **CERTIFICATES_PANEL_AND_API.md** explicitly avoided DNS API for simplicity. This is a design shift.
- Security: credentials must be stored and possibly rotated; lock down who can run certbot/lego with those credentials.
- Wildcard covers only **one level** of subdomain: `*.pbx3.com` covers `abc12xyz.pbx3.com` but not `foo.abc12xyz.pbx3.com`. For `{shortuid}.{globals.domain}` you’re fine.

**Changes required:**

- **pbx3:** Add DNS-01 support (certbot with DNS plugin or lego with DNS provider). Store credentials securely; document in installer/handoff.
- **TLS_AND_CERTIFICATES.md / CERTIFICATES_PANEL_AND_API.md:** Update to allow wildcard + DNS-01 as an option (or replace current “one hostname, HTTP-01” with “wildcard when DNS API configured”).
- **Certificates panel:** Optional “Configure wildcard” flow (domain + DNS API choice + credentials). First cert and renewal use DNS-01.

---

### Option C: Multiple certs per node (one per tenant FQDN) + SNI

**Idea:** Each tenant FQDN gets its **own** certificate in `/etc/letsencrypt/live/{tenant_fqdn}/`. Nginx and Asterisk use **SNI** (Server Name Indication) to select the correct cert for each connection.

**Mechanics:**

- When a tenant is given an FQDN (e.g. set `cluster.fqdn`), run certbot for that FQDN only:  
  `certbot certonly --standalone -d abc12xyz.pbx3.com -m admin@example.com`  
  (or via a webroot that routes by Host header). DNS for that FQDN must point to this node; port 80 opened for the challenge.
- **Nginx:** Either (1) multiple `server { server_name abc12xyz.pbx3.com; ssl_certificate .../abc12xyz.pbx3.com/fullchain.pem; ... }` blocks, or (2) a single listen with `ssl_reject_handshake off` and a `map $ssl_server_name $cert_path` (or similar) to pick cert. Nginx supports multiple certs per listen via SNI.
- **Asterisk:** PJSIP and HTTP can use TLS SNI (multiple certs); config must list all tenant cert paths or be generated from cluster table.
- **Renewal:** `certbot renew` renews **all** certs under `/etc/letsencrypt`; deploy hook runs apply-active-cert (which must then write nginx/Asterisk config that includes **all** current certs, not just one).

**Pros:**

- Clean separation: add/remove tenant doesn’t change other tenants’ certs.
- No SAN limit; no re-issue of a giant cert when tenant list changes.
- HTTP-01 only; no DNS API.

**Cons:**

- **Config generation:** Nginx and Asterisk config must be **dynamic** (generated from list of tenant FQDNs and their cert paths). apply-active-cert (or a sibling script) must write multiple server blocks or SNI map and reload.
- **Port 80 for HTTP-01:** When requesting a cert for a **new** tenant FQDN, that FQDN must resolve here and port 80 must serve the challenge for that Host. So nginx (or a stub) must route `Host: abc12xyz.pbx3.com` to the same webroot/certbot challenge dir — doable with a single server block `server_name _` and a shared webroot, as long as certbot can serve the right token for that hostname.
- More certs and more renewal work (certbot handles it, but deploy hook must regenerate config for all).

**Changes required:**

- **pbx3:** Script to request cert for one FQDN; maintain list of “certified” FQDNs (e.g. from DB). apply-active-cert (or new script) reads all tenant FQDNs with certs, writes nginx snippet or full server blocks with per-name cert paths, and Asterisk config with multiple certs/SNI.
- **pbx3api nginx:** Either include a generated snippet that defines multiple server blocks (one per tenant FQDN) or one block with SNI map. Reference: nginx `ssl_certificate` can be different per `server_name`.
- **Certificates panel / API:** “Request certificate for tenant FQDN” (per tenant); show list of tenant FQDNs and cert status. Renewal remains global (certbot renew).

---

### Option D: Tenant FQDN is CNAME to node; node cert only (no tenant in cert)

**Idea:** Tenant FQDN `{shortuid}.{globals.domain}` is a **CNAME** to the node FQDN (e.g. `node1.pbx3.com`). Phones resolve tenant FQDN → node; they connect to the node’s IP. TLS is the **node’s** cert only; the client connects to the resolved hostname (tenant FQDN), so the TLS handshake presents the node’s cert — **mismatch** unless the client is configured to accept (e.g. “connect by IP” or “ignore cert name”). Many phones and browsers will show a security warning.

**Verdict:** **Not recommended** if we want “phones find tenant by tenant FQDN” and **valid** TLS. Only viable if endpoints connect by node FQDN or IP and tenant is identified by other means (e.g. path, auth), in which case tenant FQDN is for display/DNS only, not for TLS. So we do **not** treat this as a primary option for “tenant FQDN for phones with valid cert.”

---

## 5. Comparison summary

| Option | Cert model | Challenge | Re-issue on tenant add/remove? | SAN limit | DNS API? | Config complexity |
|--------|------------|-----------|--------------------------------|-----------|----------|-------------------|
| **A** Multi-SAN | One cert, node + all tenant FQDNs | HTTP-01 | Yes (or at renewal) | 50 names | No | Low |
| **B** Wildcard | One cert `*.{globals.domain}` | DNS-01 | No | N/A | Yes | Low |
| **C** SNI | One cert per tenant FQDN | HTTP-01 | No (new cert only for new tenant) | N/A | No | High (dynamic nginx/Asterisk) |
| **D** CNAME only | Node cert only | — | No | — | No | Low (but cert mismatch) |

---

## 6. Purchased certificates (wildcard and individual)

The existing **selection order** (**CERTIFICATES_PANEL_AND_API.md** §3) is: **(1) Purchased (custom)** — if cert + key exist at `/opt/pbx3/etc/ssl/custom/`, use them; **(2) Let's Encrypt** — else if configured; **(3) Snakeoil**. Custom takes precedence; no mode toggle. That order is unchanged by the LE multi-SAN work.

**Purchased wildcard cert:** A customer who has a **commercial wildcard cert** (e.g. `*.mydomain.com`) can **install it as the custom cert** (Certificates panel → Purchased certificate → Install, upload fullchain + privkey). That single cert covers the node (default tenant) and all tenant FQDNs matching the pattern. Nginx and Asterisk use it for every hostname; no SNI or multi-path needed. **Fully accommodated** — no change to the proposed structure. LE multi-SAN is simply not used when custom is present.

**Single purchased multi-SAN cert:** Same: one cert with multiple SANs (e.g. from a commercial CA), installed via the same custom path. Covers all listed hostnames. **Fully accommodated.**

**Set of individual purchased certs:** If a customer wants to use **multiple separate certs** (e.g. one cert per tenant, or different CAs per hostname), the current design has **one** custom path. To support that we would need: **(a)** a **per-FQDN (or per-tenant) custom cert store** (e.g. `/opt/pbx3/etc/ssl/custom/<fqdn>/fullchain.pem` and `privkey.pem`), and **(b)** nginx and Asterisk config that use **SNI** to select the cert by Host (similar to Option C for LE). That is a **future extension** — not part of the current LE multi-SAN + single custom path design. Until then, customers who need multiple individual certs could (i) use one purchased wildcard or multi-SAN cert that covers all their tenant FQDNs, or (ii) use LE multi-SAN (**Sync certificate**) and not install a custom cert. So the proposed structure **does not block** purchased certs; wildcard and single multi-SAN purchased certs remain fully supported. Multiple individual purchased certs would require a later enhancement (multi-path custom store + SNI).

---

## 7. Recommendation (short)

**Product decision:** Implement **Option A** (multi-SAN, HTTP-01). The other options remain documented for comparison and future scale-out (e.g. &gt;50 SANs → consider B or C).

- **Small/medium per-node tenant count (e.g. &lt; 50), want to avoid DNS API:** **Option A** (multi-SAN). Straightforward extension of current design; add a script that builds domain list from node + `cluster.fqdn`, run certbot with multiple `-d`, re-issue when admin runs **Sync** or at initial setup (**§12**).
- **Many tenants or want zero re-issue on tenant churn:** **Option B** (wildcard + DNS-01) if you can adopt a DNS API and secure credentials.
- **Need &gt; 50 tenant FQDNs per node and no DNS API:** **Option C** (SNI + one cert per tenant). Highest implementation cost (dynamic nginx/Asterisk and cert-request flow per tenant).

---

## 8. Tenant FQDN and migration

- **Setting tenant FQDN:** Convention: `cluster.fqdn = {shortuid}.{globals.domain}` (e.g. derived from tenant shortuid + **`globals.domain`**). API/SPA can enforce this or allow override. Apex comes from **`globals.domain`** (API **`domain`** on sysglobals).
- **DNS for tenant FQDN:** For **HTTP-01** (Options A and C), each tenant FQDN must resolve to the **node** that hosts that tenant (A or CNAME). When a tenant is **migrated**, DNS must be updated so the same FQDN now points to the **new** node (supertask or manual). For **wildcard** (Option B), no per-tenant DNS for cert; but routing (which node serves which tenant) may still need A/CNAME or a load balancer that routes by hostname.
- **Export/import:** Tenant export includes `cluster.fqdn`; on import, the new node may need to (A) add this FQDN to its multi-SAN cert, (B) already have wildcard, or (C) request a new cert for this FQDN and regenerate SNI config. So the cert strategy affects what the “land tenant” step does after import.

---

## 9. Firewall FQDN inspection (iptables string match)

When **fqdninspect** is enabled, the firewall uses **iptables string matching** on inbound SIP (port 5060) so that only packets that contain the expected FQDN in the SIP payload (e.g. in Via or Contact, as `sip:<fqdn>`) are accepted. This reduces robo‑dialler / brute‑force attempts that don’t know the correct hostname. This only applies to **unencrypted** SIP (TCP/UDP 5060); TLS SIP is separate.

### 9.1 Shorewall INLINE FQDN format (single FQDN)

Historical Shorewall INLINE FQDN form (single FQDN):

```
INLINE(ACCEPT) net $FW tcp 5060 ; -m string --algo bm --to 1000 --string "sip:$FQDN"
INLINE(ACCEPT) net $FW udp 5060 ; -m string --algo bm --to 1000 --string "sip:$FQDN"
```

- **INLINE** injects raw iptables rules into Shorewall.
- **-m string --algo bm --to 1000** matches the first 1000 bytes of the packet for the given string.
- **--string "sip:$FQDN"** ensures the SIP message contains the expected FQDN (e.g. in Via/Contact as `sip:node1.pbx3.com`). So only traffic that “claims” the right hostname is allowed through.

### 9.2 Current pbx3 behaviour (single FQDN)

- **pbx3** ships **pbx3_inline_fqdn** as comment-only; when **globals.fqdninspect** is YES, **NetHelperClass::copyFirewallTemplates()** overwrites it.
- NetHelper reads **globals** (fqdn, fqdninspect, bindport) and writes **two** INLINE rules (TCP and UDP) using **bindport** and the **fqdn** string. Note: current pbx3 code uses the raw FQDN string **without** the `"sip:"` prefix (some older rules used `"sip:$FQDN"`); for correct matching of SIP headers, the string should be **`sip:<fqdn>`**.
- File is written under `/etc/shorewall/pbx3_inline_fqdn` (or the configured Shorewall dir); **rules** includes `INCLUDE pbx3_inline_fqdn`.

### 9.3 What’s needed for multiple tenant FQDNs

We need to allow SIP that contains **any** of the valid FQDNs: every **cluster.fqdn** (non-null). The **default tenant** holds the node FQDN; other tenants hold **`{shortuid}.{globals.domain}`**. So:

- **One INLINE(ACCEPT) rule per FQDN**, for both TCP and UDP on the SIP port(s), with string **`sip:<that_fqdn>`**.
- Example: if node is `node1.pbx3.com` and tenants have `abc12xyz.pbx3.com`, `def99uvw.pbx3.com`, then the generated **pbx3_inline_fqdn** should contain (conceptually):
  - `INLINE(ACCEPT) net $FW tcp 5060 ; -m string --algo bm --to 1000 --string "sip:node1.pbx3.com"`
  - `INLINE(ACCEPT) net $FW udp 5060 ; -m string --algo bm --to 1000 --string "sip:node1.pbx3.com"`
  - same for `sip:abc12xyz.pbx3.com` (tcp + udp)
  - same for `sip:def99uvw.pbx3.com` (tcp + udp)
- **Who generates:** The same place that today writes **pbx3_inline_fqdn** (e.g. **NetHelperClass::copyFirewallTemplates()** in pbx3) should:
  1. Read **globals.fqdninspect**, **globals.bindport** (SIP port; source of truth for INLINE rules, typically 5060). **Globals** do not hold FQDN; they hold **`domain`** (SQL: **`globals.domain`**, the instance apex) and **fqdninspect** (global for now).
  2. If fqdninspect is enabled, read all **cluster.fqdn** (non-null). Default tenant’s fqdn = node FQDN; others = tenant FQDNs.
  3. Build the full list of FQDNs: all cluster.fqdn values, deduplicated.
  4. Write **pbx3_inline_fqdn** with two lines (TCP, UDP) per FQDN, each with string **`sip:<fqdn>`**, using **--to 1000** and port from **globals.bindport** (source of truth; typically 5060).
  5. If fqdninspect is disabled, write the file as comment-only (current behaviour).
- **When to regenerate:** Whenever **fqdninspect** is toggled (sysglobals) or any tenant is created/updated/deleted, run the FQDN inline update script and **automatically restart Shorewall** (decision 5).

**Note:** iptables string matching is the reason we keep using iptables/Shorewall for this bit rather than nftables; nftables has different syntax and may not have the same string module. So this stays as an INLINE iptables rule under Shorewall.

---

## 10. Code blocks (panels, modules) to change

Below is the set of **panels, API controllers, backend scripts, and helpers** that need to be touched to implement **Option A (multi-SAN)** plus **firewall FQDN inspection for multiple tenant FQDNs**. Order is by layer (pbx3 → pbx3api → pbx3spa).

### 10.1 pbx3 (backend)

| Block | Path / location | Change |
|-------|------------------|--------|
| **le-first-cert.sh** | `pbx3-1/opt/pbx3/scripts/le-first-cert.sh` | Extend to support **multiple domains**: accept either one FQDN (current) or a list (e.g. from a file or space-separated args). Run `certbot certonly --standalone -d fqdn1 -d fqdn2 ... -m email`. Write **first** FQDN to `le-domain` (so cert path remains `/etc/letsencrypt/live/<first_fqdn>/`). Alternatively: add **le-first-cert-multi.sh** that takes domain list + email and leaves le-first-cert.sh as-is for single FQDN. |
| **le-renew-with-80.sh** | `pbx3-1/opt/pbx3/scripts/le-renew-with-80.sh` | No change if certbot renewal config (created at first run with multiple `-d`) already lists all SANs; `certbot renew` will renew that cert. Ensure deploy hook (apply-active-cert.sh) still runs. |
| **apply-active-cert.sh** | `pbx3-1/opt/pbx3/scripts/apply-active-cert.sh` | No change: continues to read **le-domain** (single “primary” FQDN) for cert path; multi-SAN cert lives in that one directory. |
| **NetHelperClass::copyFirewallTemplates()** | `pbx3-1/opt/pbx3/php/classes/NetHelperClass` | **Change:** (1) Read **globals** (fqdninspect, bindport); no FQDN in globals. (2) If fqdninspect enabled, query **cluster** for all non-null **fqdn**. (3) Build list: all cluster.fqdn (default tenant = node FQDN). (4) Write **pbx3_inline_fqdn** with **two lines per FQDN** (TCP, UDP), string **`sip:<fqdn>`** (not raw fqdn), port from **globals.bindport** (source of truth; typically 5060), `--to 1000`. (5) If fqdninspect disabled, write comment-only. |
| **Firewall / syshelper trigger** | — | Today the API does **not** run copyFirewallTemplates; only pbx3’s `restartFirewall()` does. To keep the inline file in sync when tenant or sysglobals change from the panel, either: **(a)** Add a **script** on pbx3 (e.g. `update-fqdn-inline.sh`) that runs the PHP NetHelper copyFirewallTemplates (or replicates the logic in shell + sqlite3) and have the API call it via syshelper before/after firewall restart; or **(b)** Firewall panel “Restart” calls that script then shorewall restart. So: **FirewallController** (see below) or a new syscommand that “refreshes FQDN inline then restarts” may be needed. |

### 10.2 pbx3api (API)

| Block | Path / location | Change |
|-------|------------------|--------|
| **CertificateController** | `app/Http/Controllers/CertificateController.php` | **setup:** Accept **optional** list of extra FQDNs (e.g. `domains[]` or body with `fqdn` + `tenant_fqdns[]`). Build full list from GET tenants (all cluster.fqdn), call **le-first-cert-multi.sh** (or extended le-first-cert) with that list so the issued cert is multi-SAN. **letsencrypt (GET):** Continue to use le-domain for “primary” and path; optionally return **domains** (list of SANs) by reading from DB (globals.fqdn + cluster.fqdn) or from cert. **renew:** No change; certbot renew renews the multi-SAN cert. Optionally add **POST /certificates/letsencrypt/sync** that (1) builds domain list from globals + cluster, (2) re-issues cert with that list (same as setup but “already configured” path), for use when a tenant FQDN is added/removed. |
| **TenantController** | `app/Http/Controllers/TenantController.php` | **On create:** set **cluster.fqdn = shortuid + "." + globals.domain** (**`domain`** from GET sysglobals); **immutable** (no update of fqdn). **After create/update/delete:** call update-fqdn-inline script (writes file + **automatic Shorewall restart**). No auto cert sync (manual only). |
| **SysglobalController** | `app/Http/Controllers/SysglobalController.php` | If **sysglobals** exposes **`domain`** (instance apex; consider readonly in API) and **fqdninspect**: after update, call syshelper to run **update-fqdn-inline** (writes file + automatic Shorewall restart). |
| **FirewallController** | `app/Http/Controllers/FirewallController.php` | **ipv4restart / ipv6restart:** Before `shorewall restart`, call syshelper to run the **FQDN inline update script** (so the file reflects current globals + cluster.fqdn). That way “Restart firewall” from the panel always writes the latest tenant list into pbx3_inline_fqdn. |
| **New syscommand or script** | e.g. `syscommands` or new route | Optional: **“Refresh firewall FQDN inline”** (no restart) so tenant/sysglobals save can update the file without restarting Shorewall; admin can restart later. Or fold into existing firewall restart. |

### 10.3 pbx3spa (SPA / panels)

| Block | Path / location | Change |
|-------|------------------|--------|
| **CertificatesView** | `src/views/CertificatesView.vue` | **Option A multi-SAN:** (1) **Setup:** Either keep single “Hostname (FQDN)” for **node** only and add copy like “Tenant FQDNs are added from Tenant panel and included in cert at next renewal/sync,” or add a “Sync cert with tenant list” button that calls the new sync endpoint so the cert is re-issued with node + all tenant FQDNs. (2) **Status:** Show “Cert covers: &lt;list of domains&gt;” from GET letsencrypt if API returns **domains** (SAN list). (3) **Renew now:** Unchanged. |
| **TenantDetailView** | `src/views/TenantDetailView.vue` | Add **FQDN** (and optionally **FQDN inspect**) to the form: show as **read-only derived** (shortuid + "." + base_domain); no edit or save of cluster.fqdn. Optionally show hint: “e.g. {shortuid}.pbx3.com”. If base domain is configurable (sysglobals or config), show it so user can follow convention. |
| **tenantAdvanced.js** | — | If FQDN is in the “advanced” section, No change; FQDN is a stored, read-only display field. |
| **TenantCreateView** | `src/views/TenantCreateView.vue` | API sets **cluster.fqdn** = **`{shortuid}.{globals.domain}`** on create (immutable). Optional hint in SPA. |

### 10.4 Summary table

| Layer | Component | Purpose of change |
|-------|-----------|--------------------|
| pbx3 | le-first-cert.sh (or new multi script) | Issue cert with multiple SANs (node + tenant FQDNs). |
| pbx3 | NetHelperClass::copyFirewallTemplates | Write one INLINE rule per FQDN with `sip:<fqdn>`. |
| pbx3 | Script + API call path | Refresh pbx3_inline_fqdn from API (tenant/sysglobals/firewall restart). |
| pbx3api | CertificateController | Setup/sync with domain list from DB; optionally return SAN list. |
| pbx3api | TenantController | On create set cluster.fqdn; after save run update-fqdn-inline + auto Shorewall restart; no auto cert sync. |
| pbx3api | SysglobalController / FirewallController | Expose **domain**, **fqdninspect**; after sysglobals PUT or firewall Restart run update-fqdn-inline + auto Shorewall restart. |
| pbx3spa | CertificatesView | Show “Cert covers” list; **Sync certificate** action. |
| pbx3spa | TenantDetailView | Show **derived** tenant FQDN (shortuid.base_domain) as read-only. |

---

## 11. Prerequisites and when to start

**Gate (panels):** The large SPA/API panel integration that previously lived on a side branch is **merged to `main`** (pbx3spa / pbx3api, 2026). You may start this build **from `main`** once the **prerequisite checklist** in the table below is satisfied. Still avoid mixing half-finished LE work with unrelated large refactors — use a **feature branch from `main`** for the work in **§12**.

**Before or at the start of Phase 1, ensure:**

| Item | Where | Notes |
|------|--------|------|
| **globals.domain** | pbx3 schema (`globals` table) + installer | Instance apex (e.g. `pbx3.com`), set at install. Column **`domain`** already exists; installer writes it. Optional: make **`domain`** readonly via API after bootstrap. |
| **Default tenant fqdn = node FQDN** | pbx3 installer or bootstrap | At install, set the **default** tenant’s **cluster.fqdn** to the node FQDN (e.g. `{default_tenant_shortuid}.{globals.domain}`, or a separate install prompt for “node FQDN” that is written to default tenant). So the node has a stable FQDN for the cert and firewall from first boot. |
| **Sysglobals exposes domain, fqdninspect** | pbx3api Sysglobal model + GET sysglobals | API must return **`domain`** and **fqdninspect** so CertificateController and TenantController can build domain list and set tenant fqdn on create. **`fqdninspect`** is currently in **`$hidden`** — unhide for panels if needed. |
| **Tenant create returns shortuid** | pbx3api TenantController | New tenant must get **shortuid** (and id) on create so **cluster.fqdn** = **shortuid + "." + globals.domain** can be set. Already the case if tenant create follows tenant-scoped pattern. |

**Branch:** Create a **feature branch from `main`** for LE multi-SAN / per-tenant FQDN work; merge back via PR when each phase is verified.

---

## 12. Implementation plan

Ordered by dependency: pbx3 first (scripts and FQDN inline), then pbx3api (API and syshelper calls), then pbx3spa (panels). Each phase ends with a short verification step.

**Decisions (product):**

- **4. Cert sync:** **Manual only** — re-issue only when admin clicks **Sync certificate** on Certificates panel (avoids LE rate limits).
- **5. Firewall restart:** **Automatic** — after updating the FQDN inline file (on tenant create/update/delete or when sysglobals **fqdninspect** / **`domain`** change), automatically run Shorewall restart so new rules apply immediately.
- **6. Where FQDNs live:** **Globals** do **not** hold per-tenant FQDN; they hold **`domain`** (instance apex, e.g. `pbx3.com`, SQL **`globals.domain`**) and **fqdninspect**. **FQDNs** live in **tenants**: each tenant has **cluster.fqdn**. The **default tenant** (node-owned) holds the **node FQDN** (e.g. `node1.pbx3.com`); store it there. **Globals** own **fqdninspect** (check/don’t check SIP for FQDN); global for now.
- **7. New tenant FQDN:** **Self-defining** = **`{shortuid}.{globals.domain}`**. Set **cluster.fqdn = shortuid + "." + globals.domain** on tenant create; **immutable** thereafter. Display in tenant views as read-only.
- **8. fqdninspect:** **Global only** (in globals). May become per-tenant later (move to cluster); that can be done later.

**Domain list: API-only, from tenants.** All panels use the API only. **Domain list** = all **cluster.fqdn** (non-null) from **GET tenants** — i.e. every tenant’s stored FQDN (default tenant = node FQDN; others = **`{shortuid}.{globals.domain}`**). No FQDN in globals. **GET sysglobals** provides **`domain`** (for tenant create: set **cluster.fqdn = shortuid + "." + globals.domain**) and **fqdninspect**. On the pbx3 side, the firewall script reads **cluster.fqdn** for all tenants (and globals.fqdninspect, globals.bindport) and writes one INLINE rule per FQDN.

### Phase 1 — pbx3 backend (cert multi-SAN + firewall FQDN inline)

| Step | Task | Details |
|------|------|---------|
| **1.1** | Multi-domain first-cert script | Add **le-first-cert-multi.sh** (or extend **le-first-cert.sh**) that accepts multiple FQDNs (e.g. from args or a file) plus email. Run `certbot certonly --standalone -d fqdn1 -d fqdn2 ... -m email` (open 80, certbot, write **first** FQDN to `le-domain`, apply-active-cert, close 80). Ensure certbot creates renewal config with all SANs so `certbot renew` later renews the same cert. |
| **1.2** | NetHelperClass::copyFirewallTemplates | Change to: read **globals** (fqdninspect, bindport); if fqdninspect enabled, query **cluster** for all **fqdn** (non-null); build list = all tenant FQDNs (default tenant’s fqdn = node FQDN); write **pbx3_inline_fqdn** with two lines per FQDN (TCP, UDP), string **`sip:<fqdn>`**, port from **globals.bindport**, `--to 1000`. If fqdninspect disabled, write `#` only. Use the INLINE FQDN format above. |
| **1.3** | FQDN inline update script | Add script (e.g. **update-fqdn-inline.sh**) that invokes the logic in step 1.2. After writing the file, **restart Shorewall** (automatic firewall restart per decision 5). Script callable as root or via sudo. Install under `/opt/pbx3/scripts/`. |
| **1.4** | Verify Phase 1 | On a dev node: (1) Set default tenant’s fqdn (node FQDN) and one other tenant’s fqdn; set globals.fqdninspect YES; run the update script; confirm pbx3_inline_fqdn contains two INLINE rules per FQDN with `sip:<fqdn>` and Shorewall restarted. (2) Run le-first-cert-multi with those FQDNs; confirm cert shows both SANs. |

### Phase 2 — pbx3api (cert API + firewall refresh)

| Step | Task | Details |
|------|------|---------|
| **2.1** | CertificateController — domain list helper | Build domain list **via API only**: **GET tenants**; take every tenant’s **fqdn** (non-null). Domain list = [t.fqdn for each tenant]. (Default tenant’s fqdn = node FQDN; others = **`{shortuid}.{globals.domain}`**.) No FQDN in sysglobals; sysglobals has **`domain`** and **fqdninspect** only. Used by setup, sync, and GET response. |
| **2.2** | CertificateController::setup (multi-SAN) | Build domain list as in 2.1 (all tenant fqdns from GET tenants). Call **le-first-cert-multi.sh** with that list + email (via syshelper). Keep 409 when already configured. |
| **2.3** | CertificateController::letsencrypt (GET) — return domains | Return configured, domain (primary), expires_at, issuer; add **domains** (array) = all tenant fqdns from GET tenants. |
| **2.4** | CertificateController — sync endpoint | Add **POST /certificates/letsencrypt/sync**: build domain list as in 2.1; if LE already configured, run re-issue script with current list. **Manual only** (no auto sync on tenant save); document LE rate limits. |
| **2.5** | FirewallController — refresh FQDN before restart | In **ipv4restart** / **ipv6restart**, call syshelper to run **update-fqdn-inline** (which writes file and **restarts Shorewall**). So panel “Restart” uses current tenant FQDN list. |
| **2.6** | TenantController — FQDN on create + refresh + auto restart | On tenant **create**: set **cluster.fqdn = shortuid + "." + globals.domain** (**`domain`** from GET sysglobals); **immutable** (do not allow update of fqdn). After **create**, **update**, or **delete**, call syshelper to run **update-fqdn-inline** (script writes file and **automatically restarts Shorewall** per decision 5). |
| **2.7** | SysglobalController | Expose **`domain`** (consider readonly) and **fqdninspect**. After successful PUT (e.g. fqdninspect changed), call syshelper to run **update-fqdn-inline** (writes file + **automatic Shorewall restart**). |
| **2.8** | Verify Phase 2 | From API: (1) POST certificates/letsencrypt/setup (domain list = all tenant fqdns); confirm 200 and cert has multiple SANs. (2) GET certificates/letsencrypt; confirm **domains** = tenant fqdns. (3) Create a tenant; confirm cluster.fqdn set to **shortuid + "." + globals.domain** and update-fqdn-inline ran and Shorewall restarted. (4) Firewall panel Restart; confirm script runs and Shorewall restarts. |

### Phase 3 — pbx3spa (Tenant FQDN + Certificates UI)

| Step | Task | Details |
|------|------|---------|
| **3.1** | TenantDetailView — FQDN (read-only, immutable) | Show **FQDN** in the tenant view (e.g. Identity or Settings) as **read-only**: **shortuid + "." + base_domain** (base_domain from sysglobals). No need to edit or save cluster.fqdn for now; the rule is derived. Label e.g. “Tenant FQDN” with hint “Derived from shortuid + base domain (for cert and firewall).” |
| **3.2** | TenantCreateView | API sets **cluster.fqdn = shortuid + "." + globals.domain** on create. SPA may show hint: "FQDN will be **{shortuid}.{globals.domain}** (immutable)." No editable FQDN field. |
| **3.3** | CertificatesView — show “Cert covers” | When GET certificates/letsencrypt returns **domains**, display a line or list: “Cert covers: domain1, domain2, …”. If API doesn’t return domains yet, skip or show primary domain only until Phase 2 is done. |
| **3.4** | CertificatesView — **Sync certificate** | Button calls **POST /certificates/letsencrypt/sync**. Solo copy: re-issue for node + tenant FQDNs that resolve here. |
| **3.5** | Verify Phase 3 | In browser: (1) Open a tenant; confirm FQDN (cluster.fqdn) is shown as read-only. (2) Create a tenant; confirm FQDN set. (3) Certificates panel: confirm “Cert covers” list and Sync button; run Sync (manual only) and confirm cert re-issued. |

### Phase 4 — Integration and docs

| Step | Task | Details |
|------|------|---------|
| **4.1** | Cron / renewal | Confirm **le-renew-with-80.sh** (and cron) still runs `certbot renew`; with multi-SAN cert the renewal config already has all domains, so no change. Deploy hook apply-active-cert.sh unchanged. |
| **4.2** | Tenant move runbook | Document in this doc or a short runbook: when moving a tenant (export/import), on **destination** after import run cert sync (or add tenant FQDN and Sync) so cert includes the new tenant; switch DNS; on **source** remove tenant and run cert sync so source cert no longer includes that FQDN. |
| **4.3** | Handoff | Update **pbx3spa/workingdocs/SESSION_HANDOFF.md** and **pbx3/workingdocs/AGENT_HANDOFF.md**: list per-tenant FQDN + multi-SAN cert and firewall FQDN inline as done; point to **`LETSENCRYPT_PER_TENANT_FQDN.md`** and **`CERTIFICATES_PANEL_AND_API.md`** (this repo). |

### Optional / follow-on

- **globals.domain:** Stored at install. Expose via GET sysglobals as **`domain`**; API uses it on tenant create to set **cluster.fqdn = shortuid + "." + globals.domain**. **Globals** do not hold per-tenant FQDN; **fqdninspect** stays in globals, global for now.
- **Per-tenant fqdninspect (later):** Keep global for now; may move to cluster later so inspect is per-tenant.
- **Dedicated “Refresh FQDN inline” syscommand:** Expose a syscommand (e.g. POST syscommands/refresh-fqdn-inline) that only runs the update script, for use from scripts or support without restarting the firewall.

---

## 13. Impact on future tenant-scoped access

**Context:** Today only admins have access; there is no tenant-scoped security yet. The plan (see **pbx3spa/workingdocs/ADMIN_PANELS_AND_PERMISSIONS.md**) is to tighten this so that **tenant users** can only see and manage their own tenant’s data (row-level scope via “allowed clusters” and abilities). A possible addition is using the **tenant URL** (e.g. `https://abc12xyz.pbx3.com`) as the **access point** so that the hostname identifies the tenant and the session is scoped to that tenant.

**Impact of this work:**

- **No conflict.** The per-tenant FQDN + cert + firewall work does **not** implement auth or row-level scope. It only makes **tenant FQDNs** first-class: stored in `cluster.fqdn`, included in the certificate (multi-SAN), and allowed in the firewall. That is exactly what you need if you later want “tenant URL = access point.”
- **Enables tenant-URL access.** If end users are given a URL like `https://abc12xyz.pbx3.com`:
  - **TLS** will already be valid for that hostname (we’re adding it to the cert).
  - The **API** can later use the **Host** header to resolve the tenant (`cluster.fqdn = request host`) and scope the session or all queries to that tenant. That’s an auth/middleware change; no change to cert or firewall.
  - The **SPA** can be served from that URL; the backend already has a single API and SPA entry point that can serve multiple hostnames (same nginx/Asterisk, same cert with many SANs). So this mod **enables** “one URL per tenant” without requiring it.
- **Nothing to undo.** We are not hardcoding “one global admin URL” or ignoring the Host header. We’re adding tenant FQDNs to the data model, cert, and firewall. Future auth can:
  - Keep a single entry URL (e.g. node FQDN) and scope by user’s `allowed_clusters` from whoami, or
  - Use the tenant URL as the access point and derive tenant from Host, then enforce row-level scope for that tenant.
- **One thing to keep in mind:** When you add tenant-scoped users, the API will need to **resolve tenant from request context**: either from the user’s allowed clusters (current plan) or from **Host** when the request is to a tenant FQDN. So ensure the API can map `Host: abc12xyz.pbx3.com` → tenant (e.g. `SELECT id/shortuid FROM cluster WHERE fqdn = ?`). This mod does not add that; it just makes sure the hostname is valid and routable so that when you do add it, it works.

**Summary:** This work **supports** future tenant-only access and tenant-URL access. It does not implement them. It provides the right building blocks (tenant FQDN in schema, valid cert and firewall for that URL) and does not block or conflict with row-level scope or “tenant URL as access point.”

---

## 14. References (all repos)

| Document | Repo | Use |
|----------|------|-----|
| **TLS_AND_CERTIFICATES.md** | **pbx3** `workingdocs/` | Canonical TLS overview (**Option A**). |
| **CERTIFICATES_PANEL_AND_API.md** | **pbx3** `workingdocs/` | Certificates panel, API tables, nginx/Asterisk file checklist. |
| **TRUNK_ROUTE_MULTITENANCY.md** | **pbx3spa** `workingdocs/` | Tenant migration (export/import). |
| **full_schema.sql** | **pbx3** | `cluster.fqdn`; **`globals.domain`**, **globals.fqdninspect**. |
| **Tenant.php** | **pbx3api** | `fqdn` in `$fillable`. |
| Historical INLINE FQDN rule | reference | INLINE rule with `sip:$FQDN`. |
| **NetHelperClass** | **pbx3** `pbx3-1/opt/pbx3/php/classes/` | `copyFirewallTemplates()`. |
| **pbx3_inline_fqdn** | **pbx3** `pbx3-1/opt/pbx3/etc/shorewall/` | shipped template. |
