# Greenfield fleet instance — install PBX3 then adopt into fleet

**Scope:** **AWS EC2 only** (Ubuntu 24.04). This is not a bare-metal or Azure/GCP guide.  
**Audience:** A human operator at a terminal — **Mac (or Linux ops workstation) + SSH into a new EC2**.  
**Path:** Launch EC2 → install pbx3 stack → DNS/LE → fleet onboard (**new KSUID**).  
**Not this doc:** Replacing a failed node with the **same KSUID** → **`REBUILD_INSTANCE_RUNBOOK.md`**.

**Related (deeper reference):** checklist **`NEW_INSTANCE_CHECKLIST.md`** § A · fleet theory **`INSTANCE_ONBOARDING.md`** · Mac ops day-to-day **`OPERATOR_MAC_SETUP.md`** · package narrative **`INSTALL_SEQUENCE_UBUNTU.md`** · S3/IAM org bucket **`OPS_S3_RUNBOOK.md`**.

**Lab tip (2026-08):** Release debs in git at repo root: **`pbx3_0.0.4-3_all.deb`**, **`pbx3cagi_1.0.0-8_all.deb`**. Adjust filenames when newer.

---

## 0 — Prerequisites (complete before launching EC2)

Do not start EC2 install until every row below is true. Tools and accounts live on the **operator machine** unless noted.

### 0.1 Platform and AWS account

| Prerequisite | Why | How to obtain / verify |
|--------------|-----|------------------------|
| **AWS account** with rights to create **EC2**, **IAM** (roles/policies/instance profiles), **EIP**, and **security groups** | Launch, profile attach, fleet S3 IAM | AWS Console sign-up or corporate account; console IAM user/SSO with admin or scoped admin |
| **Existing fleet S3 org bucket** (e.g. lab `08jzwn-pbx3`) | Onboard joins a fleet; does not invent a first-fleet | See **`OPS_S3_RUNBOOK.md`** (bucket + catalog). New first fleet is a separate bootstrap |
| **AWS region** chosen (lab default `us-east-1`) | Every CLI flag and EIP lives there | `export AWS_DEFAULT_REGION=us-east-1` |
| **Ubuntu 24.04 LTS** AMI in that region | Package target (Noble) | EC2 console → Launch → Ubuntu Server 24.04, or SSM AMI parameters |

This guide assumes you've already created an EC2 instance (`t4g.medium` is a common lab shape) and an Elastic IP.

### 0.2 Operator workstation tools

| Tool | Why | How to obtain | Quick verify |
|------|-----|---------------|--------------|
| **AWS CLI v2** | Launch EC2, EIP, IAM, S3 catalog, onboard script | [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (macOS installer or `brew install awscli`) · config via `aws configure` or [SSO](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html) | `aws --version` · `aws sts get-caller-identity` |
| **SSH client** + **OpenSSH `scp`** | Log into EC2; copy release `.deb`s | macOS/Linux built-in (`ssh`, `scp`) | `ssh -V` |
| **`jq`** | Catalog / JSON checks; some fleet scripts | `brew install jq` (Mac) · [jq downloads](https://jqlang.github.io/jq/download/) | `jq --version` |
| **`curl`** | Health checks, public IP probe | Usually preinstalled | `curl --version` |
| **`dig` or `host`** | DNS A record check before LE | macOS: often present; else `brew install bind` | `dig -v` or `host -V` |
| **`git`** | Clone source trees on the **Mac** (authenticated). Node may clone **pbx3api** if that repo is reachable | [git-scm](https://git-scm.com/downloads) · `xcode-select --install` on Mac | `git --version` |
| **Terminal / shell** (bash or zsh) | Run this document’s blocks | System terminal | — |

Full Mac session checklist (SSH keys, common hangs, agent tips): **`OPERATOR_MAC_SETUP.md`**.

### 0.3 AWS credentials (ops identity — not the node role)

```bash
export AWS_DEFAULT_REGION=us-east-1
# optional: export AWS_PROFILE=your-ops-profile
# optional: aws sso login --profile your-ops-profile

aws sts get-caller-identity
```

**Pass:** prints `Account` + `Arn`.

**Fail if** `Arn` contains `assumed-role/pbx3-node-` — that is an **EC2 instance** identity. Switch to Mac/ops login (`aws configure` or SSO).  
**Never** run `onboard-fleet-instance.sh` or catalog register scripts *as* the node role.

Ops identity needs at least: create/attach IAM policies & instance profiles, associate IAM profile to EC2, read/write the **fleet catalog** and (during smoke) exercise S3 under registrar powers. See **`OPERATOR_MAC_SETUP.md`** and **`INSTANCE_ONBOARDING.md`**.

### 0.4 EC2 SSH key pair

| Prerequisite | Why | How to obtain |
|--------------|-----|---------------|
| **Key pair** in the target region | First SSH login as `ubuntu` | AWS Console → EC2 → **Key pairs** → Create, **or** `aws ec2 create-key-pair …` · save the private `.pem` once |
| **Private key file** on disk, mode `400` | `ssh -i` / onboard `--ssh-key` | Wherever you store EC2 private keys · `chmod 400 {path to your pemfiles}/your-key.pem` |

```bash
KEY_FILE={path to your pemfiles}/your-key.pem
chmod 400 "$KEY_FILE"
test -r "$KEY_FILE" && echo "key readable"
```

### 0.5 Operator source trees (Mac) — where “pbx3-master” comes from

**There is no monorepo.** GitHub has separate repositories (`pbx3`, `pbx3cagi`, `pbx3api`, …). The path  
`~/GiT/pbx3-master/` is **not** created by AWS, EC2, or this install — and it is **not** a git clone of anything.

It is an optional **local parent folder** some operators keep for sibling checkouts (Cursor workspace, hand documentation). You invent that folder name; `pbx3-master` is only an example.

| Prerequisite | Why | How to obtain |
|--------------|-----|---------------|
| **`pbx3` git clone on Mac** | Release `.deb` + fleet tools (`onboard-fleet-instance.sh`) | [github.com/aelintra/pbx3](https://github.com/aelintra/pbx3) · `main` · **private today** — authenticate as yourself on the Mac |
| **`pbx3cagi` git clone on Mac** | Release `pbx3cagi_*.deb` | [github.com/aelintra/pbx3cagi](https://github.com/aelintra/pbx3cagi) · `main` · **private today** |
| **Built `.deb` files on Mac** | Copied to the node with `scp` (§4) | Prefer **committed release debs** at each repo root (e.g. `pbx3_0.0.4-3_all.deb`, `pbx3cagi_1.0.0-8_all.deb`) |

**Why not `git clone` on the EC2 for packages?** While **`pbx3`** and **`pbx3cagi`** remain private, equipping every new instance with deploy keys just to fetch debs is heavier than `scp` from a Mac that already has the clones. When those repos are public, this guide can switch to on-node clone.

**Create your own holding folder and clones** (adjust names/paths as you like):

```bash
# 1) Empty parent dir — name is arbitrary (example matches lab Cursor root)
mkdir -p ~/GiT/pbx3-master
cd ~/GiT/pbx3-master

# 2) Separate git clones (each is its own repo; parent is NOT git)
#    Use credentials GitHub already accepts on this Mac (SSH or HTTPS + token).
git clone https://github.com/aelintra/pbx3.git
git clone https://github.com/aelintra/pbx3cagi.git

cd pbx3 && git checkout main && git pull --ff-only
cd ../pbx3cagi && git checkout main && git pull --ff-only

# 3) Point env vars at the clones
export PBX3_REPO=~/GiT/pbx3-master/pbx3
export CAGI_REPO=~/GiT/pbx3-master/pbx3cagi
export PBX3_DEB="${PBX3_REPO}/pbx3_0.0.4-3_all.deb"
export CAGI_DEB="${CAGI_REPO}/pbx3cagi_1.0.0-8_all.deb"

test -f "$PBX3_DEB" \
  && test -f "$CAGI_DEB" \
  && test -x "${PBX3_REPO}/pbx3-directory/tools/onboard-fleet-instance.sh" \
  && echo "packages + onboard tool ok"
```

After this, **`$PBX3_REPO`**, **`$CAGI_REPO`**, **`$PBX3_DEB`**, and **`$CAGI_DEB`** are the paths later steps use. If you already clone elsewhere, set those vars to your paths and ignore the `pbx3-master` name.
### 0.6 DNS and identity you will supply

| Prerequisite | Why | How to obtain |
|--------------|-----|---------------|
| **FQDN** for the new node (or plan to use installer-generated `*.pbx3.com`) | LE and SPA URLs | DNS host (name.com, Route53, corporate DNS) where you can create an **A** record to the EIP |
| **Email** for Let’s Encrypt | certbot registration | Any operator email |
| **Site name** (friendly label) | `globals.sitename` / Home | Your choice string |

### 0.7 What the EC2 AMIs will install (no Mac action)

On the instance itself you will use Ubuntu packages (`apt`), **`ssmtp`**, then our debs. No pre-install of Asterisk on the AMI is required — **`pbx3`** pulls Asterisk and friends as dependencies.

### 0.8 Prerequisite smoke test (Mac — copy once)

```bash
export AWS_DEFAULT_REGION=us-east-1
aws --version
aws sts get-caller-identity   # no pbx3-node- in Arn
command -v ssh scp jq curl git
ssh -V
jq --version

export PBX3_REPO=~/GiT/pbx3-master/pbx3   # set in §0.5 — not created by this step
export CAGI_REPO=~/GiT/pbx3-master/pbx3cagi
test -f "${PBX3_REPO}/pbx3_0.0.4-3_all.deb"
test -f "${CAGI_REPO}/pbx3cagi_1.0.0-8_all.deb"
test -x "${PBX3_REPO}/pbx3-directory/tools/onboard-fleet-instance.sh"
```

If any command fails, stop and fix that prerequisite before launching an instance.

---

## 1 — What success looks like

| Check | Target |
|-------|--------|
| API | `curl -k https://127.0.0.1:44300/up` → **200** |
| Identity | `globals.id` (KSUID), `shortuid`, `fqdn` set; catalog row `id` = same KSUID |
| TLS | HTTPS on **44300** with LE (not only snakeoil) for `globals.fqdn` |
| Fleet | IAM instance profile attached; `PBX3_ORG_BUCKET` set; **`trunks.pkey=Egress`** present; `pbx3:fleet-preflight` green (incl. **Egress qualify Avail** when SBC answers OPTIONS) |
| SPA | Instance appears in fleet catalog picker after refresh |

Order matters: **install and prove `/up` before onboard.** Onboard does **not** recreate the DB, but it **does** write fleet `.env`, register the catalog row, and **seed the mandatory Egress trunk** (then genAst + runLinker + Asterisk restart). Magrathea domain/dispatcher cutover is still a separate edge step.

---

## 2 — Fill this worksheet first

Copy into a text file and replace every `…`. You will paste these into later steps.

```bash
# --- AWS / EC2 ---
export AWS_DEFAULT_REGION=us-east-1
export INSTANCE_ID=i-…                 # after launch
export KEY_NAME=…                      # EC2 key pair name
export KEY_FILE={path to your pemfiles}/your-key.pem
export SG_ID=sg-…                      # or create one in step 3
export SUBNET_ID=subnet-…              # optional if default VPC is fine

# --- Host identity (pick one style) ---
# Style A — custom hostname / brand FQDN (e.g. lab):
export INSTANCE_FQDN=pbx3.example.com
export SSH_HOST=ubuntu@pbx3.example.com   # or ubuntu@PUBLIC_IP until DNS works

# Style B — package-generated shortuid under an apex (installer default pattern):
# export DOMAIN_TLD=pbx3.com
# INSTANCE_FQDN and shortuid come out of installer.sh (read them after §7)

# --- Packages + onboard tools (§0.5) ---
export PBX3_REPO=~/GiT/pbx3-master/pbx3
export CAGI_REPO=~/GiT/pbx3-master/pbx3cagi
export PBX3_DEB="${PBX3_REPO}/pbx3_0.0.4-3_all.deb"
export CAGI_DEB="${CAGI_REPO}/pbx3cagi_1.0.0-8_all.deb"

# --- Fleet (existing org bucket — do NOT create a new bucket per node) ---
export PBX3_ORG_BUCKET=08jzwn-pbx3      # lab fleet; use your fleet’s bucket
export LE_EMAIL=you@example.com
export SITE_NAME='My new node'         # friendly label (globals.sitename)
```

---

## 3 — Mac: launch EC2 (Ubuntu 24.04)

Prefer **ARM** (`t4g.*`) for lab fleets unless you already standardized on x86. Allocate an **Elastic IP** early so DNS can stick to one address.

### 3.1 Security group (inbound)

| Port | Why |
|------|-----|
| **22/tcp** | SSH |
| **80/tcp** | Let’s Encrypt HTTP-01 |
| **44300/tcp** | pbx3api HTTPS |
| SIP / RTP as required | Phones / SIP test (optional at install day) |

Outbound **443** required for apt + S3 + LE.

Example (adjust CIDR — do not leave SSH world-open in production):

```bash
# Create SG (skip if reusing an existing SG_ID)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)

export SG_ID=$(aws ec2 create-security-group \
  --group-name pbx3-node-greenfield \
  --description 'PBX3 greenfield node' \
  --vpc-id "$VPC_ID" \
  --query GroupId --output text)

MY_IP=$(curl -sS https://checkip.amazonaws.com)/32
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --ip-permissions \
  "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${MY_IP}}]" \
  "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]" \
  "IpProtocol=tcp,FromPort=44300,ToPort=44300,IpRanges=[{CidrIp=${MY_IP}}]"
```

### 3.2 Launch instance

Use current Ubuntu 24.04 AMI for your arch/region (console or SSM parameter). Example shape:

```bash
# AMI: pick from AWS console “Ubuntu Server 24.04 LTS” for arm64 or x86_64
export AMI_ID=ami-…   # fill from console / SSM

aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t4g.medium \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=pbx3-greenfield}]' \
  --query 'Instances[0].InstanceId' --output text
# → set INSTANCE_ID=i-…

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

export PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "INSTANCE_ID=$INSTANCE_ID PUBLIC_IP=$PUBLIC_IP"
```

### 3.3 (Recommended) Elastic IP

```bash
export ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)
aws ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOC_ID"
export PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "EIP PUBLIC_IP=$PUBLIC_IP"
```

### 3.4 SSH works?

```bash
export SSH_HOST=ubuntu@${PUBLIC_IP}
ssh -i "$KEY_FILE" -o BatchMode=yes -o ConnectTimeout=15 "$SSH_HOST" 'hostname; uname -m'
```

---

## 4 — Mac: copy packages onto the node

```bash
scp -i "$KEY_FILE" "$PBX3_DEB" "$CAGI_DEB" "${SSH_HOST}:/tmp/"
```

Release `.deb`s come from your Mac clones (authenticated to private GitHub). The node does not need `git` access to `pbx3` / `pbx3cagi` for install.

If a `.deb` is missing from the clone, rebuild on a Linux builder or copy packages from an existing fleet node that already runs the same release. **Do not invent random debs.**

---

## 5 — Node: OS prep

```bash
ssh -i "$KEY_FILE" -t "$SSH_HOST"
# --- all following until DNS/LE/onboard are ON THE NODE unless labelled Mac ---

sudo apt update
sudo apt upgrade -y

# Mail relay before pbx3 (installer chmods ssmtp paths)
sudo apt install -y ssmtp
sudo chmod +x /etc/ssmtp

# Helpers used below (git only if you will clone pbx3api from GitHub on this host)
sudo apt install -y sqlite3 curl ca-certificates git
```

---

## 6 — Node: install pbx3 + pbx3cagi packages

```bash
cd /tmp
ls -la pbx3_*.deb pbx3cagi_*.deb

sudo apt install -y ./pbx3_0.0.4-3_all.deb ./pbx3cagi_1.0.0-8_all.deb

dpkg-query -W pbx3 pbx3cagi
# expect:
# pbx3	0.0.4-3
# pbx3cagi	1.0.0-8
```

`apt install` does **not** run the full product installer. DB is still empty.

---

## 7 — Node: first-run `installer.sh` (creates DB + identity)

### Style A — you already know the FQDN (fixed hostname)

```bash
sudo INSTANCE_FQDN="${INSTANCE_FQDN}" \
  INSTANCE_SITENAME="${SITE_NAME}" \
  /opt/pbx3/scripts/installer.sh
```

You can also hard-code:

```bash
sudo INSTANCE_FQDN=pbx3.example.com \
  INSTANCE_SITENAME='Lab node' \
  /opt/pbx3/scripts/installer.sh
```

### Style B — generate shortuid under an apex

```bash
sudo DOMAIN_TLD=pbx3.com \
  INSTANCE_SITENAME="${SITE_NAME}" \
  /opt/pbx3/scripts/installer.sh
```

When interactive, answer domain / site-name prompts if asked.

**Rules:**

- First run (no `/opt/pbx3/db/sqlite.db`) creates the DB and **new KSUID**.
- **Do not** re-run `reloader.sh` afterward for routine install.
- **Do not** set `PBX3_ORG_BUCKET` yet (onboard does that).

Record identity:

```bash
sqlite3 /opt/pbx3/db/sqlite.db \
  "SELECT shortuid, fqdn, id FROM globals WHERE pkey='global';"
```

Copy that line into your worksheet. Catalog and S3 path **`instances/{id}/`** use the **KSUID** (`id`).

---

## 8 — Node: install pbx3api

pbx3api has no `.deb` — deploy under `/opt/pbx3api`, then run its installer.

```bash
# If the repo is reachable from the node (deploy key or public HTTPS):
sudo rm -rf /opt/pbx3api
sudo git clone https://github.com/aelintra/pbx3api.git /opt/pbx3api
cd /opt/pbx3api
sudo git checkout main
sudo git pull --ff-only origin main

# Private and no node credentials: copy a clone from the Mac instead, e.g.
#   scp -i "$KEY_FILE" -r /path/to/pbx3api "${SSH_HOST}:/tmp/pbx3api"
#   then on the node: sudo mv /tmp/pbx3api /opt/pbx3api

# Drop nginx default if it will fight for :80 (LE / ACME)
sudo rm -f /etc/nginx/sites-enabled/default

sudo /opt/pbx3api/scripts/installer.sh
```

If DB path were nonstandard (not needed for normal packages):

```bash
sudo PBX3_SQLITE_PATH=/opt/pbx3/db/sqlite.db /opt/pbx3api/scripts/installer.sh
```

Composer / config clean (safe anytime):

```bash
cd /opt/pbx3api
sudo composer install --no-dev
sudo php artisan config:clear
```

---

## 9 — Node: prove the stack (before DNS / fleet)

```bash
curl -k -sS -o /dev/null -w "%{http_code}\n" https://127.0.0.1:44300/up
# expect 200

sudo systemctl is-active nginx php8.3-fpm asterisk
# all active (asterisk may still be settling)

# optional: logrotate ship package present
test -f /etc/logrotate.d/pbx3-asterisk-logs && echo logrotate ok
```

If nginx complains about duplicate `default_server` on port 80:

```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
# re-run pbx3api installer pieces if needed:
# sudo /opt/pbx3api/scripts/install-nginx-site.sh
```

**Stop here if not 200.** Onboard will not fix a broken API.

---

## 10 — DNS: point FQDN at this node

On whatever hosts DNS for `INSTANCE_FQDN` (name.com, Route53, …):

| Name | Type | Value |
|------|------|--------|
| Host / A for `INSTANCE_FQDN` | **A** | `PUBLIC_IP` (or EIP) |

Until DNS propagates, LE and browser HTTPS using the name will fail. Check:

```bash
# On Mac or node
dig +short "$INSTANCE_FQDN"
# must equal PUBLIC_IP / EIP
```

If you used Style B and only have shortuid so far:

```bash
sqlite3 /opt/pbx3/db/sqlite.db "SELECT fqdn FROM globals WHERE pkey='global';"
# create A for that exact name
```

---

## 11 — Node: first Let’s Encrypt certificate

Port **80** must reach this host from the public internet. DNS A must already match.

```bash
sudo /opt/pbx3/scripts/le-instance-bootstrap.sh "$LE_EMAIL"
```

Staging (rate-limit safe):

```bash
sudo PBX3_LE_STAGING=1 /opt/pbx3/scripts/le-instance-bootstrap.sh "$LE_EMAIL"
```

Apply is part of the script path; smoke:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" "https://${INSTANCE_FQDN}:44300/up"
# 200 preferred (trust store may still warn on staging)
```

SPA alternative: open API SPA → **Certificates → Get certificate** after snakeoil login is acceptable.

---

## 12 — Mac: adopt into fleet (`onboard-fleet-instance.sh`)

Run from **Mac / ops workstation**, **not** from the EC2 node role.

```bash
# shell variables from §2 still set on Mac
export PBX3_ORG_BUCKET=08jzwn-pbx3
export AWS_DEFAULT_REGION=us-east-1

cd "${PBX3_REPO}/pbx3-directory/tools"
chmod +x onboard-fleet-instance.sh register-instance.sh

./onboard-fleet-instance.sh \
  --instance-id "$INSTANCE_ID" \
  --ssh "$SSH_HOST" \
  --ssh-key "$KEY_FILE" \
  --region "$AWS_DEFAULT_REGION" \
  --org-bucket "$PBX3_ORG_BUCKET"
# optional: --sbc-egress-host sbc.pbx3.com   (default)
# optional: PBX3_SBC_EGRESS_FAILOVER_HOST=… for EgressFailover
# unusual: --skip-egress-seed   (leaves fleet dial-plane incomplete)
```

Optional: after a local backup exists on the node, add `--smoke-backup`.

**What this script does:**

1. SSH-reads **`globals`** (shortuid / fqdn / KSUID)  
2. Creates/scopes **node S3 writer** IAM + **instance profile** `pbx3-node-{shortuid}`  
3. Attaches profile to **this** `$INSTANCE_ID`  
4. Writes **`register-instance.sh`** catalog row (`catalog/instance-index.json`)  
5. Configures node `/opt/pbx3api/.env` (`PBX3_ORG_BUCKET`, fleet mode, egress host, cleans empty static AWS keys)  
6. Seeds **`trunks.pkey=Egress`** (host from `PBX3_SBC_EGRESS_HOST` / `--sbc-egress-host`), runs **genAst** + **runLinker** + **Asterisk restart**  
7. Sets SIP capture fleet mode + log cron as applicable  
8. S3 smoke + catalog verify  

Do **not** put `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (even empty) in `.env` — empty strings block instance-role credentials.

Edge note: seed makes the **node** ready to dial toward `sbc.pbx3.com`. Magrathea **domain / dispatcher / setid** for this FQDN remains an SBC-side step.

---

## 13 — Node: sign-off commands

SSH again and run:

```bash
# Fleet env + mandatory Egress trunk (seeded by onboard)
grep -E '^(PBX3_ORG_BUCKET|PBX3_FLEET_MODE|PBX3_DIRECTORY_BACKUP_UPLOAD|PBX3_SBC_EGRESS_HOST)=' /opt/pbx3api/.env
sqlite3 /opt/pbx3/db/sqlite.db "SELECT pkey, active, host FROM trunks WHERE pkey='Egress';"
# expect: Egress|YES|sbc.pbx3.com  (or your --sbc-egress-host)

# Instance role visible (wait ~30s after profile attach if empty)
curl -sS http://169.254.169.254/latest/meta-data/iam/security-credentials/
# expect pbx3-node-{shortuid}

cd /opt/pbx3api
sudo php artisan config:clear
sudo php artisan pbx3:fleet-preflight
# all green
```

Create and see an S3 backup (once bucket + role work):

```bash
# Create backup via SPA Backup panel, or your standard artisan path if available
sudo php artisan pbx3:upload-backup   # if a local zip already exists under /opt/pbx3/bkup/
# panel should list local+S3 / source=both after upload
```

Optional log ship smoke:

```bash
sudo php artisan pbx3:logs-s3-upload --limit=2
```

### Mac: catalog row visible

```bash
export PBX3_ORG_BUCKET=08jzwn-pbx3
aws s3 cp "s3://${PBX3_ORG_BUCKET}/catalog/instance-index.json" - \
  | jq --arg id "$(ssh -i "$KEY_FILE" "$SSH_HOST" \
      "sqlite3 /opt/pbx3/db/sqlite.db \"SELECT id FROM globals WHERE pkey='global';\"")" \
    '.instances[] | select(.id==$id)'
```

SPA: refresh catalog / instance picker — new shortuid should appear.

---

## 14 — Lab tenants (if this node will host them)

Fleet boxes **must not invent node-only tenants** not present in the catalog. See **`LAB_FLEET_TENANTS.md`** and:

```bash
# Mac
cd "${PBX3_REPO}/pbx3-directory/tools"
./reconcile-node-tenants.sh --help
```

---

## Failure cheat sheet

| Symptom | Likely fix |
|---------|------------|
| `/up` not 200 | pbx3api installer, nginx site, PHP-FPM; re-read §8–§9 |
| LE certbot fails | DNS A not to this EIP; SG port 80; another process on 80 |
| Onboard: SSH hangs | `chmod 400` key; SG 22 from Mac; use `BatchMode=yes` path |
| Onboard: wrong AWS id | Mac must not use `pbx3-node-*` role |
| Preflight S3 red | IAM attach lag (~30–60s); empty AWS keys in `.env`; wrong `PBX3_ORG_BUCKET` |
| Preflight **Egress trunk** missing | Onboard skipped seed (`--skip-egress-seed`) or old onboard script — re-run current `onboard-fleet-instance.sh` or `seed-fleet-egress-trunk.sh` + genAst + runLinker + Asterisk restart |
| Preflight **Egress qualify** Unknown/Unavail | Trunk may need a few qualify cycles; confirm `pjsip show aor Egress` Avail; check SBC OPTIONS path |
| SPA missing instance | `register-instance` / catalog step failed; re-run with only catalog skip flags carefully |
| Want same KSUID as a dead node | Wrong doc — use **`REBUILD_INSTANCE_RUNBOOK.md`** |

---

## Command order (one page)

| # | Where | Command / action |
|---|--------|------------------|
| 0 | Mac | §0 Prerequisites: AWS CLI, ops credentials, key, debs, tools (`sts` smoke) |
| 1 | Mac | Worksheet variables (§2) |
| 2 | Mac | Launch EC2 + SG + EIP; SSH smoke |
| 3 | Mac | `scp` `pbx3` + `pbx3cagi` debs → `/tmp` |
| 4 | Node | `apt update/upgrade`; `ssmtp` |
| 5 | Node | `apt install ./pbx3_*.deb ./pbx3cagi_*.deb` |
| 6 | Node | `INSTANCE_FQDN=… /opt/pbx3/scripts/installer.sh` |
| 7 | Node | Record `globals` KSUID / shortuid / fqdn |
| 8 | Node | Deploy pbx3api → `/opt/pbx3api`; `scripts/installer.sh` |
| 9 | Node | `curl -k …/up` → 200 |
| 10 | DNS | **A** `globals.fqdn` → EIP |
| 11 | Node | `le-instance-bootstrap.sh email` |
| 12 | Mac | `onboard-fleet-instance.sh` (IAM, catalog, `.env`, **auto-seed Egress + genAst/runLinker/Asterisk restart**, S3 smoke) |
| 13 | Node | `php artisan pbx3:fleet-preflight` green (incl. Egress trunk + qualify); SPA catalog refresh |

That is the full greenfield install + fleet adopt path.
