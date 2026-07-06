# Operator Mac setup — SSH + AWS CLI

**Audience:** Human operators and **AI agents** running fleet scripts from a laptop (not from EC2).

**Use for:** `fetch-latest-instance-backup.sh`, `onboard-fleet-instance.sh`, registrar scripts, rebuild dry-runs, and manual S3/IAM ops.

**Related:** **`REBUILD_INSTANCE_RUNBOOK.md`**, **`INSTANCE_ONBOARDING.md`** § Operator pre-flight, **`OPS_S3_RUNBOOK.md`**.

---

## Golden rule

| Run from | Credentials | Tools |
|----------|-------------|--------|
| **Mac / ops workstation** | Operator IAM (admin or registrar user) | `aws`, `ssh`, `jq`, `pbx3-directory/tools/*` |
| **EC2 PBX node** | Instance profile (`pbx3-node-{shortuid}`) only | `php artisan`, backup create, **not** IAM/catalog scripts |

**Never** run `onboard-fleet-instance.sh`, `register-instance.sh`, or `apply-backup-lifecycle-rule.sh` on the EC2 node or with the node’s AWS identity.

---

## Fleet reference (golden test fleet, us-east-1)

| Node | FQDN | KSUID (`globals.id`) | EC2 instance id |
|------|------|----------------------|-----------------|
| **Golden** | `08jzwn.pbx3.com` | `3DmAsxePTWQZgynBYXE8obIRqEE` | `i-02ec2b05b5baacb5d` |
| **Second** | `bzy54n.pbx3.com` | `3E3gAOVGBhvc6vEPTBIYCBPycIk` | `i-0bb601e7b1253c3f5` |

| Setting | Value |
|---------|--------|
| Org bucket | `08jzwn-pbx3` |
| Catalog | `s3://08jzwn-pbx3/catalog/instance-index.json` |
| Region | `us-east-1` |

Look up EC2 id from Mac when unsure:

```bash
# By public IP (DNS for node FQDN)
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=ip-address,Values=$(dig +short 08jzwn.pbx3.com | head -1)" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text
```

Or read catalog:

```bash
export PBX3_ORG_BUCKET=08jzwn-pbx3
aws s3 cp "s3://${PBX3_ORG_BUCKET}/catalog/instance-index.json" - \
  | jq '.instances[] | {label, fqdn, id}'
```

---

## SSH to golden (and other fleet nodes)

### Standard connection

| Item | Value |
|------|--------|
| User | `ubuntu` |
| Key (Jeff’s Mac) | `~/Documents/pemfiles/pbx3test.pem` |
| Host | `08jzwn.pbx3.com` (or node public IP) |
| Ports (SG) | **22** SSH, **44300** API, **80** LE |

```bash
KEY=~/Documents/pemfiles/pbx3test.pem
HOST=ubuntu@08jzwn.pbx3.com

chmod 400 "$KEY"    # if SSH complains about permissions

ssh -i "$KEY" -o BatchMode=yes -o ConnectTimeout=15 "$HOST" 'hostname'
```

Scripts (`onboard-fleet-instance.sh`) require **non-interactive** SSH (`BatchMode=yes`). If you get a password prompt, fix the key path or SG — the script will hang or fail.

### Verify SSH + PBX health (copy-paste)

```bash
KEY=~/Documents/pemfiles/pbx3test.pem
HOST=ubuntu@08jzwn.pbx3.com

# Identity from DB (source of truth for KSUID)
ssh -i "$KEY" -o BatchMode=yes "$HOST" \
  "sqlite3 /opt/pbx3/db/sqlite.db \"SELECT shortuid, fqdn, id FROM globals WHERE pkey='global';\""

# API up (on node)
ssh -i "$KEY" -o BatchMode=yes "$HOST" \
  "curl -k -sS -o /dev/null -w 'up %{http_code}\n' https://127.0.0.1:44300/up"
```

Expected: one line `08jzwn|08jzwn.pbx3.com|3DmAsxePTWQZgynBYXE8obIRqEE` and `up 200`.

### Remote git / artisan (e.g. deploy `s8build`, fleet preflight)

Repos on nodes are owned by root; use `sudo` for git in `/opt/pbx3api`:

```bash
ssh -i "$KEY" -o BatchMode=yes "$HOST" 'set -e
cd /opt/pbx3api
sudo git fetch origin
sudo git checkout s8build    # or main after merge
sudo git pull origin s8build
sudo php artisan config:clear
sudo php artisan pbx3:fleet-preflight'
```

### SSH troubleshooting

| Symptom | Fix |
|---------|-----|
| `Permission denied (publickey)` | Wrong key path; check `chmod 400` on `.pem`; confirm SG allows **22** from your IP |
| `Connection timed out` | SG or wrong IP; verify `dig +short 08jzwn.pbx3.com` |
| `Host key verification failed` | `ssh -o StrictHostKeyChecking=accept-new …` once, or new EC2 after rebuild |
| Script hangs on SSH | Password auth fallback — use `-i` key + `BatchMode=yes` |
| `sqlite3: not found` | Install `pbx3` package / incomplete node |

### AI agents (Cursor)

- SSH and `pbx3test.pem` require running shell commands **outside a restricted sandbox** (full permissions). Network-only is not enough for key file access.
- Always pass **absolute path** to `--ssh-key` in onboard scripts.
- Do **not** assume the agent can SSH without the user’s key at `~/Documents/pemfiles/pbx3test.pem`.

---

## AWS CLI on the Mac

### Session setup (every ops session)

```bash
export PBX3_ORG_BUCKET=08jzwn-pbx3
export AWS_DEFAULT_REGION=us-east-1

# Optional named profile (uncomment and set a real profile name):
# export AWS_PROFILE=your-ops-profile
# aws sso login --profile your-ops-profile

aws sts get-caller-identity
```

**Pass:** JSON with `Account` and `Arn`.

**Fail patterns:**

| `Arn` contains | Meaning |
|----------------|---------|
| `assumed-role/pbx3-node-` | You are using **EC2 instance role** credentials — switch to Mac ops login |
| Command fails / no credentials | Run `aws configure` or SSO login |

Golden test account example: `arn:aws:iam::334063106996:root` — acceptable for ops.

### List backups (step 0 preflight)

```bash
export PBX3_ORG_BUCKET=08jzwn-pbx3
KSUID=3DmAsxePTWQZgynBYXE8obIRqEE

aws s3 ls "s3://${PBX3_ORG_BUCKET}/instances/${KSUID}/backups/"
```

Lines starting with `PRE` are archive folders (`20260706T001010Z/`).  
**Ignore** the standalone `policy.json` file line — it is **not** a backup stamp.

Latest stamp (human):

```bash
aws s3 ls "s3://${PBX3_ORG_BUCKET}/instances/${KSUID}/backups/" \
  | awk '/ PRE / { gsub(/\//, "", $2); print $2 }' | sort | tail -1
```

Prefer **`fetch-latest-instance-backup.sh`** — it selects the newest `PRE` prefix correctly.

### Inspect one archive

```bash
STAMP=20260706T001010Z
aws s3 ls "s3://${PBX3_ORG_BUCKET}/instances/${KSUID}/backups/${STAMP}/"
aws s3 cp "s3://${PBX3_ORG_BUCKET}/instances/${KSUID}/backups/${STAMP}/manifest.json" -
```

### Fetch backup to Mac

```bash
cd pbx3/pbx3-directory/tools
chmod +x fetch-latest-instance-backup.sh

ZIP=$(./fetch-latest-instance-backup.sh \
  --instance-id "$KSUID" \
  --output-dir /tmp/pbx3-rebuild-dryrun)

ls -lh "$ZIP"
shasum -a 256 "$ZIP"   # compare to manifest.json artifacts[0].sha256
```

Capture **stdout only** — the script prints the file path on the last line; progress goes to stderr.

### Onboard dry-run (Mac → golden or lab node)

```bash
cd pbx3/pbx3-directory/tools

./onboard-fleet-instance.sh \
  --instance-id i-02ec2b05b5baacb5d \
  --ssh ubuntu@08jzwn.pbx3.com \
  --ssh-key ~/Documents/pemfiles/pbx3test.pem \
  --region us-east-1 \
  --dry-run
```

Use the **target EC2 instance id** (golden id above for golden; **new** id after rebuild).

### AWS troubleshooting

| Symptom | Fix |
|---------|-----|
| `AccessDenied` on `s3://08jzwn-pbx3/...` | Ops identity lacks bucket policy; use account admin or registrar IAM |
| `AccessDenied` on `iam:CreatePolicy` | Same — onboard needs IAM admin on Mac |
| `PutLifecycleConfiguration` denied on node | Lifecycle is **Mac-only** — node role cannot set bucket lifecycle (`OPS_S3_RUNBOOK.md`) |
| `invalid stamp: 20:23:00` | Parsed `policy.json` line as stamp — use fixed `fetch-latest-instance-backup.sh` on `s8build` |
| Upload works on node but catalog scripts fail | Expected — node role is scoped to `instances/{ksuid}/*`, not full registrar |

### What runs where (summary)

| Action | Mac (ops AWS) | EC2 (instance role) |
|--------|---------------|---------------------|
| List/download any instance backup | ✓ (admin read) | ✓ own prefix only |
| `fetch-latest-instance-backup.sh` | ✓ | ✗ |
| `onboard-fleet-instance.sh` | ✓ | ✗ |
| `register-instance.sh` / catalog | ✓ | ✗ |
| `apply-backup-lifecycle-rule.sh` | ✓ | ✗ |
| Create backup + S3 upload | ✗ (or manual trigger) | ✓ |
| `pbx3:fleet-preflight` | via SSH | ✓ on node |

---

## Optional: `~/.pbx3/fleet.yaml`

```yaml
org_bucket: 08jzwn-pbx3
region: us-east-1
ssh_user: ubuntu
ssh_key: ~/Documents/pemfiles/pbx3test.pem
org_id: example-org
environment: production
```

Then shorten onboard to:

```bash
./onboard-fleet-instance.sh --instance-id i-02ec2b05b5baacb5d --ssh ubuntu@08jzwn.pbx3.com
```

(`org_bucket` and `ssh_key` load from file if flags omitted.)

---

## Quick session checklist (agents)

1. `export PBX3_ORG_BUCKET=08jzwn-pbx3 AWS_DEFAULT_REGION=us-east-1`
2. `aws sts get-caller-identity` — not `pbx3-node-*`
3. `aws s3 ls …/backups/` — at least one `PRE` stamp
4. `ssh -i ~/Documents/pemfiles/pbx3test.pem -o BatchMode=yes ubuntu@08jzwn.pbx3.com 'curl -k -s -o /dev/null -w %{http_code} https://127.0.0.1:44300/up'` → `200`
5. Run tool from `pbx3/pbx3-directory/tools/` on branch **`s8build`** (or `main` after merge)
