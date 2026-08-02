# Install a node, then adopt it (simple)

**Audience:** Someone who needs a working PBX3 box and (optionally) in a fleet — without reading 600 lines first.

**Two acts only:**

| Act | What you get | Stop when |
|-----|----------------|-----------|
| **1 — Install the node** | Live API + identity + TLS | `https://…:44300/up` is **200** and you can log into Admin |
| **2 — Adopt into fleet** *(if you have a fleet)* | Catalog row + S3 role + Egress trunk | SPA shows the instance and `pbx3:fleet-preflight` is green |

Copy-paste and edge cases live in **`GREENFIELD_FLEET_INSTANCE_INSTALL.md`**. Rebuild same KSUID → **`REBUILD_INSTANCE_RUNBOOK.md`**. SBC domain/dispatcher cutover is *not* part of install or adopt.

Lab package names (2026-08): **`pbx3_0.0.4-3_all.deb`**, **`pbx3cagi_1.0.0-8_all.deb`**.

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
| ☐ | **FQDN you control** | DNS **A** record → that public IP (e.g. `kildare.pbx3.com`) |
| ☐ | **Email for Let’s Encrypt** | Any real mailbox you read |
| ☐ | **Friendly site name** | Shown in Admin Home (e.g. “AEL Nodes”) |
| ☐ | **(Act 2 only) existing fleet org bucket** | e.g. lab `08jzwn-pbx3` — first-ever fleet is a *different* bootstrap |

You will also need network access so the **node** can reach apt, LE, and (Act 2) S3.

---

## Questions you will be asked (prepare answers)

Answer these *before* you start. The install does not invent them for you (except shortuid when you leave FQDN unset — usually you *set* FQDN).

| When | Question | Provide | Example |
|------|----------|---------|---------|
| You / DNS | What hostname is this node? | Full **FQDN** | `kildare.pbx3.com` |
| You / Home | What do humans call this site? | **Site name** | `AEL Nodes` |
| LE | Who owns this cert? | **Email** | `ops@example.com` |
| Admin SPA | First login (no default password is created) | **Email + password you invent** | `ops@example.com` + strong secret |
| AWS | Where does it live? | **Region**, **instance id**, key name | `us-east-1`, `i-08a…`, `aelsip` |
| SSH | How do I get in? | **`ubuntu@IP` or FQDN** + path to **`.pem`** | `ubuntu@3.93.253.1` |
| Packages | Which releases? | Paths to the two **`.deb`** files on the laptop | `…/pbx3_0.0.4-3_all.deb`, `…/pbx3cagi_1.0.0-8_all.deb` |
| Act 2 | Which fleet? | **`PBX3_ORG_BUCKET`** | `08jzwn-pbx3` |
| Act 2 | Which SBC host for dial-out? | Usually leave default | `sbc.pbx3.com` |

**On the node, `installer.sh` may prompt (if you did not set env):**

| Prompt | What to type |
|--------|----------------|
| Domain apex / TLD | Prefer **not** using the prompt — set full FQDN instead (next section). Default alone is `pbx3.com`. |
| Site name | Your friendly label |

Prefer env vars (avoids domain/TLD prompts) — see the command in **Act 1 step 5**.

---

## Act 1 — Install the node

Do in order. Stop if a check fails.

1. **Laptop:** clone `pbx3` + `pbx3cagi` on `main`; confirm both debs exist.  
2. **Cloud:** Ubuntu 24.04 EC2 + SG + EIP; SSH works as `ubuntu`.  
3. **Laptop → node:** `scp` both debs to `/tmp`.  
4. **Node:** `apt update` / upgrade; install debs (`pbx3` then `pbx3cagi`); install **`ssmtp`** if the package complains.  
5. **Node:** run the package installer with your FQDN and site name:

   ```bash
   sudo INSTANCE_FQDN=kildare.pbx3.com INSTANCE_SITENAME='AEL Nodes' \
     /opt/pbx3/scripts/installer.sh
   ```

   Replace the FQDN and site name with yours (from the answers sheet).

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

### First admin user (required — no default password)

The package does **not** create an Admin SPA account. You invent email + password and create the first `admin` on the **node** over SSH (this is **not** the EC2 PEM and **not** fleet login).

```bash
# SSH to the node first, then:
cd /opt/pbx3api

# optional: new box should print 0
sudo -u www-data php artisan tinker --execute="echo App\Models\User::count();"

sudo -u www-data php artisan tinker --execute="
\$u = App\Models\User::create([
  'name' => 'Admin',
  'email' => 'ops@example.com',
  'password' => 'choose-a-strong-password',
  'abilities' => ['admin'],
  'portable' => false,
]);
echo \$u->id.' '.\$u->email.PHP_EOL;
"
```

Replace `ops@example.com` and `choose-a-strong-password` with yours. Then open `https://<fqdn>:44300` and log in with that email/password.

**Reset a forgotten password** (on the node):

```bash
cd /opt/pbx3api
sudo -u www-data php artisan tinker --execute="
\$u = App\Models\User::where('email', 'ops@example.com')->first();
\$u->password = 'new-strong-password';
\$u->save();
echo 'updated '.\$u->email.PHP_EOL;
"
```

After the first admin exists, create more users from SPA **Users** (API register already requires an admin token).

10. **Done Act 1** when `/up` is 200, cert works, and Admin SPA login works with the user above.

Solo / evaluation users (**Rule 6**) can stop here. No fleet required.

---

## Act 2 — Adopt into fleet

Only after Act 1 is proven.

1. **Laptop (ops AWS identity):** from the `pbx3` clone:

   ```bash
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
   grep -E '^(PBX3_ORG_BUCKET|PBX3_FLEET_MODE)=' /opt/pbx3api/.env
   sqlite3 /opt/pbx3/db/sqlite.db "SELECT pkey, host FROM trunks WHERE pkey='Egress';"
   cd /opt/pbx3api && sudo php artisan pbx3:fleet-preflight
   # all green
   ```

3. **Fleet Admin:** refresh catalog — shortuid appears.  
4. **Done Act 2.** (Wiring this FQDN on Magrathea / domain → dispatcher is still a later edge step if you need multi-node SIP via SBC.)

---

## Done definition (one screen)

| Act | Done means |
|-----|------------|
| **1** | `/up` → 200 · KSUID/shortuid/fqdn set · DNS + LE · **first admin created** · SPA login works |
| **2** | Onboard finished · `Egress` row · preflight green · instance in catalog |

---

## If you’re stuck

| Symptom | Where to go |
|---------|-------------|
| Need every command expanded | **`GREENFIELD_FLEET_INSTANCE_INSTALL.md`** |
| Checkbox form of fleet new-node | **`NEW_INSTANCE_CHECKLIST.md`** § A |
| Replace dead EC2, keep KSUID | **`REBUILD_INSTANCE_RUNBOOK.md`** |
| Mac tooling / SSH hangs | **`OPERATOR_MAC_SETUP.md`** |
| First org bucket ever | **`OPS_S3_RUNBOOK.md`** (not this page) |
| SPA “Unauthorized” / no password | See **First admin user** under Act 1 |
