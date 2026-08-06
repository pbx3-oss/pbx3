# Install a node, then adopt it (simple)

**Audience:** Someone who needs a working PBX3 box and (optionally) in a fleet — without reading 600 lines first.

**Two acts only:**

| Act | What you get | Stop when |
|-----|----------------|-----------|
| **1 — Install the node** | Live API + identity + TLS | `https://…:44300/up` is **200** and you can log into Admin |
| **2 — Adopt into fleet** *(if you have a fleet)* | Catalog row + S3 role + Egress trunk | SPA shows the instance and `pbx3:fleet-preflight` is green |

Copy-paste and edge cases live in **`GREENFIELD_FLEET_INSTANCE_INSTALL.md`**. Rebuild same KSUID → **`REBUILD_INSTANCE_RUNBOOK.md`**. SBC domain/dispatcher cutover is *not* part of install or adopt.

Lab package names (2026-08): **`pbx3_0.0.4-4`** (admin bootstrap) when built · else **`0.0.4-3`** + scp `bootstrap-admin-user.sh`. CAGI: **`pbx3cagi_1.0.0-8_all.deb`**.

---

## What you need (before anything)

Fill this once. Empty cells = stop and get them. Do not invent a new S3 bucket per node.

| Have it? | Thing | What it is |
|:--------:|-------|------------|
| ☐ | **AWS account + permissions** | Launch EC2, EIP, security groups; for Act 2 also IAM + write fleet S3 catalog |
| ☐ | **Ops AWS login** (Mac/Linux laptop) | `aws sts get-caller-identity` works; must **not** be `pbx3-node-…` |
| ☐ | **SSH key + `.pem` file** (`chmod 400`) | Same key pair as the EC2 |
| ☐ | **AWS CLI v2, ssh, scp, jq** on the laptop | Day-to-day tools |
| ☐ | **GitHub access** to private **`pbx3`** + **`pbx3cagi`** | Debs live at each repo root on `main` (today) |
| ☐ | **Ubuntu 24.04 EC2** | Prefer ARM `t4g.*`; open inbound **22**, **80**, **44300**; outbound **443** |
| ☐ | **Elastic IP** (recommended) | Sticky public IP for DNS/LE |
| ☐ | **FQDN you control** | DNS **A** for **`{opaque-shortuid}.{apex}`** (set at install; not a vanity name like `kildare.pbx3.com`) |
| ☐ | **Email for Let’s Encrypt** | Any real mailbox you read |
| ☐ | **Friendly site name** | Human **Name** on Admin Home (e.g. “Kildare”) — not the hostname |
| ☐ | **(Act 2 only) existing fleet org bucket** | e.g. lab `08jzwn-pbx3` — first-ever fleet is a *different* bootstrap |
| ☐ | **(Act 2 only) fleet service token** | Same shared secret as gatekeeper — how to **find** it is under Act 2; not inventing a new per-node value |

You will also need network access so the **node** can reach apt, LE, and (Act 2) S3.

---

## Questions you will be asked (prepare answers)

Answer these *before* you start. The install does not invent them for you (except shortuid when you leave FQDN unset — usually you *set* FQDN).

| When | Question | Provide | Example |
|------|----------|---------|---------|
| You / DNS | Apex + opaque host | **DOMAIN_TLD**; FQDN becomes `{shortuid}.{apex}` after install | `pbx3.com` → e.g. `08jzwn.pbx3.com` |
| You / Home | What do humans call this site? | **Site name** (Name) | `Kildare` |
| LE | Who owns this cert? | **Email** | `ops@example.com` |
| Admin SPA | installer will ask (or set env) | **Email + password you invent** | env or interactive; min 8 chars |
| AWS | Where does it live? | **Region**, **instance id**, key name | `us-east-1`, `i-08a…`, `aelsip` |
| SSH | How do I get in? | **`ubuntu@IP` or FQDN** + path to **`.pem`** | `ubuntu@3.93.253.1` |
| Packages | Which releases? | Paths to the two **`.deb`** files on the laptop | `…/pbx3_0.0.4-4_all.deb`, `…/pbx3cagi_1.0.0-8_all.deb` |
| Act 2 | Which fleet? | **`PBX3_ORG_BUCKET`** | `08jzwn-pbx3` |
| Act 2 | Gatekeeper ↔ node | **`PBX3_FLEET_SERVICE_TOKEN`** on Mac when running onboard (same value as gatekeeper `.env`) | required for Fleet Create tenant / move |
| Act 2 | Which SBC host for dial-out? | Usually leave default | `sbc.pbx3.com` |

**On the node, `installer.sh` may prompt (if you did not set env):**

| Prompt | What to type |
|--------|----------------|
| Domain apex / TLD | e.g. `pbx3.com` — installer mints opaque shortuid; FQDN = `{shortuid}.{apex}` |
| Site name | Friendly **Name** (e.g. Kildare) — not the hostname |
| **Admin email** | SPA login email (any RFC-ish address; need not receive mail) |
| **Admin password** (+ confirm) | At least **8** characters — this *is* your SPA password |

Prefer env vars (avoids prompts) — see Act 1 step 5.

---

## Act 1 — Install the node

Do in order. Stop if a check fails.

1. **Laptop:** clone `pbx3` + `pbx3cagi` on `main`; confirm both debs exist.  
2. **Cloud:** Ubuntu 24.04 EC2 + SG + EIP; SSH works as `ubuntu`.  
3. **Laptop → node:** `scp` both debs to `/tmp`.  
4. **Node:** `apt update` / upgrade; install debs (`pbx3` then `pbx3cagi`); install **`ssmtp`** if the package complains.  
5. **Node:** run the package installer with apex, site **Name**, and **admin SPA credentials**:

   ```bash
   sudo DOMAIN_TLD=pbx3.com INSTANCE_SITENAME='Kildare' \
     PBX3_ADMIN_EMAIL=ops@example.com PBX3_ADMIN_PASSWORD='choose-a-strong-password' \
     /opt/pbx3/scripts/installer.sh
   ```

   FQDN becomes `{opaque-shortuid}.pbx3.com` — do **not** set vanity `INSTANCE_FQDN=kildare.pbx3.com` (rejected unless `PBX3_ALLOW_VANITY_FQDN=1` lab debt). See **`FLEET_NAMING_LOCK.md`**.

   Or omit `PBX3_ADMIN_*` and answer the **Admin email / password** prompts on a real TTY.  
   Package **≥ 0.0.4-4** no longer seeds `admin@pbx3.com` with an unknown hash.

6. **Node:** deploy **pbx3api** to `/opt/pbx3api` and run its `installer.sh` (see full guide if you do not have a lab deploy habit yet).  
7. **Prove Act 1 (local):**

   ```bash
   curl -k -sS -o /dev/null -w "%{http_code}\n" https://127.0.0.1:44300/up
   # expect: 200

   sqlite3 /opt/pbx3/db/sqlite.db \
     "SELECT id, shortuid, fqdn, sitename FROM globals WHERE pkey='global';"
   # record KSUID (id), shortuid, fqdn — never invent these
   ```

8. **DNS:** **A** record for that `fqdn` → EIP. Wait until public DNS matches.  
9. **Node:** LE — `le-instance-bootstrap.sh your@email` (or SPA → Certificates after first login).

### Admin SPA user (install time + recovery)

**New install (package ≥ 0.0.4-4):** `installer.sh` calls `bootstrap-admin-user.sh` and either:

- uses **`PBX3_ADMIN_EMAIL` / `PBX3_ADMIN_PASSWORD`** (optional **`PBX3_ADMIN_NAME`**), or  
- prompts interactively when the DB has **zero** users.

There is **no** factory SPA password. Remember what you set.

**Boxes already installed** (including pre-0.0.4-4 with seeded `admin@pbx3.com` / unknown password) — set a known password on the node:

```bash
# copy bootstrap-admin-user.sh from the pbx3 repo if your package is still older, then:
sudo PBX3_ADMIN_EMAIL=admin@pbx3.com PBX3_ADMIN_PASSWORD='choose-a-strong-password' \
  /opt/pbx3/scripts/bootstrap-admin-user.sh --reset
```

(If the email is different, use that address, or let sole-user fallback apply when only one row exists.)

Break-glass alternate (any package age):

```bash
cd /opt/pbx3api
sudo -u www-data env HOME=/tmp php artisan tinker --execute='
$u = App\Models\User::query()->first();
$u->password = "choose-a-strong-password";
$u->save();
echo "ready: ".$u->email."\n";
'
```

Then open `https://<fqdn>:44300` with that email/password. More users: SPA **Users** (requires an admin session).

10. **Done Act 1** when `/up` is 200, cert works, and Admin SPA login works with the user above.

Solo / evaluation users (**Rule 6**) can stop here. No fleet required.

---

## Act 2 — Adopt into fleet

Only after Act 1 is proven. Solo nodes skip this entire act.

### Fleet service token (required for Fleet Create / move)

Gatekeeper calls node `POST /api/fleet/*` with bearer **`PBX3_FLEET_SERVICE_TOKEN`**.  
This is **not** SPA email login, not the AWS role, not Sanctum. It is **not shown in the SPA** (ops secret).  
**One value for the whole fleet** — same string on control/gatekeeper, every fleet node, and usually SBC admin.

**Find the token** (use the first source that works; do not invent a second token):

```bash
# 1) Prefer control / gatekeeper host (authoritative for the fleet)
ssh ubuntu@YOUR-CONTROL-HOST \
  "grep -E '^PBX3_FLEET_SERVICE_TOKEN=' /etc/pbx3-gatekeeper/.env | head -1"

# 2) Lab: local gatekeeper tree on Mac (if that is how this lab runs GK)
grep -E '^PBX3_FLEET_SERVICE_TOKEN=' \
  ~/GiT/pbx3-master/pbx3/pbx3-directory/gatekeeper/.env 2>/dev/null | head -1

# 3) Any already-onboarded fleet sibling node (golden etc.)
ssh -i /path/to/key.pem ubuntu@SIBLING-FQDN-OR-IP \
  "grep -E '^PBX3_FLEET_SERVICE_TOKEN=' /opt/pbx3api/.env | head -1"
```

Export on the **ops laptop before onboard** (replace with the exact value after `=`):

```bash
export PBX3_FLEET_SERVICE_TOKEN='paste-the-token-value-only'
# confirm it is set (prints length, not the secret):
python3 -c "import os; t=os.environ.get('PBX3_FLEET_SERVICE_TOKEN',''); print('token_len', len(t))"
```

Onboard (package tools on `main` ≥ **309bb18**) writes that into the new node’s `/opt/pbx3api/.env`.

**Missed it / create-tenant error** `Fleet service token not configured (PBX3_FLEET_SERVICE_TOKEN)` — set on the node, then clear config:

```bash
# on node — TOKEN must match gatekeeper exactly
TOKEN='paste-the-token-value-only'
ENV=/opt/pbx3api/.env
if grep -q '^PBX3_FLEET_SERVICE_TOKEN=' "$ENV" 2>/dev/null; then
  sudo sed -i "s|^PBX3_FLEET_SERVICE_TOKEN=.*|PBX3_FLEET_SERVICE_TOKEN=${TOKEN}|" "$ENV"
else
  echo "PBX3_FLEET_SERVICE_TOKEN=${TOKEN}" | sudo tee -a "$ENV" >/dev/null
fi
cd /opt/pbx3api && sudo php artisan config:clear
# if still failing: sudo systemctl reload php*-fpm   (match your php version)
grep -E '^PBX3_FLEET_SERVICE_TOKEN=.' /opt/pbx3api/.env >/dev/null && echo "token_line_present"
```

First-ever fleet only: generate once when controlling gatekeeper is installed (`openssl rand -hex 32`), put in `/etc/pbx3-gatekeeper/.env`, restart gatekeeper — then use that value everywhere. See **`CONTROL_HOST.md`**.

### Run adopt

1. **Laptop (ops AWS identity + token in env as above):** from the `pbx3` clone:

   ```bash
   export PBX3_FLEET_SERVICE_TOKEN   # already set above; required
   export AWS_DEFAULT_REGION=us-east-1

   cd /path/to/pbx3/pbx3-directory/tools
   ./onboard-fleet-instance.sh \
     --instance-id i-… \
     --ssh ubuntu@your.fqdn.or.ip \
     --ssh-key /path/to/key.pem \
     --region us-east-1 \
     --org-bucket your-org-bucket
   ```

2. **Node — prove Act 2:**

   ```bash
   grep -E '^(PBX3_ORG_BUCKET|PBX3_FLEET_MODE|PBX3_FLEET_SERVICE_TOKEN)=' /opt/pbx3api/.env
   # FLEET_SERVICE_TOKEN line must be present (value non-empty); do not paste secrets into tickets
   sqlite3 /opt/pbx3/db/sqlite.db "SELECT pkey, host FROM trunks WHERE pkey='Egress';"
   cd /opt/pbx3api && sudo php artisan pbx3:fleet-preflight
   # all green
   ```

3. **Fleet Admin:** refresh catalog — shortuid appears.  
4. **Edge (when you want Fleet Create tenant / multi-node SIP):** Instances → **Provision edge** with **IP** URI  
   `sip:YOUR.PUBLIC.IP:5060` (not the FQDN — SBC rejects DNS-name backends). Setid must be set before tenant create.  
5. **Done Act 2** (+ edge) when catalog has the instance, preflight green, and (if needed) setid is set for tenant home.

---

## Done definition (one screen)

| Act | Done means |
|-----|------------|
| **1** | `/up` → 200 · KSUID/shortuid/fqdn set · DNS + LE · **first admin created** · SPA login works |
| **2** | Onboard finished · fleet service token in node `.env` · `Egress` · preflight green · instance in catalog · setid if tenants/SBC |

---

## If you’re stuck

| Symptom | Where to go |
|---------|-------------|
| Need every command expanded | **`GREENFIELD_FLEET_INSTANCE_INSTALL.md`** |
| Checkbox form of fleet new-node | **`NEW_INSTANCE_CHECKLIST.md`** § A |
| Replace dead EC2, keep KSUID | **`REBUILD_INSTANCE_RUNBOOK.md`** |
| Mac tooling / SSH hangs | **`OPERATOR_MAC_SETUP.md`** |
| First org bucket ever | **`OPS_S3_RUNBOOK.md`** (not this page) |
| SPA “Unauthorized” / no password | New install: re-run bootstrap with email/password. Existing: `bootstrap-admin-user.sh --reset` (see **Admin SPA user**) |
| Fleet create: **PBX3_FLEET_SERVICE_TOKEN** | Act 2 § **Fleet service token** — find on gatekeeper, `export` for onboard, or paste onto node + `config:clear` |
| Fleet Create: setid / Provision edge | Backend URI must be **`sip:IP:5060`**, not FQDN; Instances → Provision edge |
| Fleet Create: Cluster CLID | Digits only (or leave empty); no `+` |
