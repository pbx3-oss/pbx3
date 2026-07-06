# Self-service fleet node rebuild — design (S8.9)

**Status:** Design draft (2026-07-06).  
**Audience:** Product, operators, implementers.  
**Depends on:** **S8.1–S8.4** (shipped), **`REBUILD_INSTANCE_RUNBOOK.md`** (manual reference path).  
**Goal:** Customer initiates **“rebuild this instance”** from the SPA with minimal touch; new EC2 restores from S3 and rejoins the fleet without Mac SSH or tribal scripts.

**Manual baseline:** Two full lab rebuilds validated (2026-07-05/06): `fetch-latest-instance-backup.sh` → `restore-backup-zip.sh` → `onboard-fleet-instance.sh` → `pbx3:fleet-preflight` → SPA smoke. DNS/LE cutover deferred as routine ops.

---

## Vision

```text
Customer (SPA)  →  Fleet orchestrator  →  AWS (launch + IAM)
                         ↓                      ↓
                   Job status API         New EC2 (fleet AMI)
                                               ↓
                                         First-boot: S3 restore
                                               ↓
                                         Preflight + ready for DNS
```

The **new node** performs data restore and health checks. A **control-plane service** (not the browser, not the node’s instance role alone) performs AWS lifecycle actions the node cannot safely do.

---

## Principles

| # | Principle |
|---|-----------|
| 1 | **S3 remains source of record** for rebuild payload (`instances/{ksuid}/backups/{stamp}/backup.zip`). |
| 2 | **Same KSUID, same FQDN** — rebuild replaces EC2; catalog row persists. |
| 3 | **SPA is UI only** — no AWS root keys, no SSH from the browser. |
| 4 | **Node never holds ops IAM** — instance profile is `pbx3-node-{shortuid}`; onboard/IAM association uses orchestrator credentials. |
| 5 | **Idempotent jobs** — relaunch or retry must not corrupt catalog or double-attach IAM blindly. |
| 6 | **Blue/green preferred** — new IP smoke test before DNS cutover (matches lab drill). |

---

## Responsibility matrix

| Step | Who | How (target) |
|------|-----|----------------|
| Preconditions (backup exists) | Orchestrator | S3 `HeadObject` / list `backups/`; fail job early |
| Launch EC2 | Orchestrator | Launch template + fleet-ready AMI; SG, key, subnet from fleet config |
| Attach IAM profile to **new** instance id | Orchestrator | Same logic as **`onboard-fleet-instance.sh`** § IAM (disassociate from old instance if replacing) |
| Patch AMI / install stack | **AMI** (pre-baked) | No install on first boot if AMI current |
| Fetch + restore backup | **Node** (first-boot) | `aws s3 cp` + `restore-backup-zip.sh --full` + `sqlite_message.sql` |
| Hostname sync | **Node** | `sync-hostname-from-globals.sh` (inside restore) |
| Write `pbx3api/.env` fleet block | **Node** or orchestrator | Prefer node after IAM metadata live; template from env/UserData |
| S3 smoke + preflight | **Node** | `pbx3:fleet-preflight` |
| Update catalog `meta.json` (ec2 id, IP) | Orchestrator or node | Node can write if role allows; orchestrator safer for job state |
| DNS A record → new IP | Orchestrator (Route53) or **customer** | v1: wizard step; v2: optional Route53 API |
| LE Certificates Sync | **API** on node | SPA button or orchestrator calls authenticated API after DNS green |
| Retire old EC2 | Orchestrator / customer | After cutover confirmation |

**Never on node:** `associate-iam-instance-profile` using ops admin creds baked into UserData.

---

## Architecture

### Components

| Component | Repo (proposed) | Role |
|-----------|-----------------|------|
| **Fleet-ready AMI** | ops / image pipeline | Ubuntu 24.04 arm64, `apt` current, `ssmtp`, `pbx3` + `pbx3api`, throwaway DB, `/up` 200, **no** fleet `.env` |
| **`pbx3-first-boot-rebuild.sh`** | **pbx3** `opt/pbx3/scripts/` | One-shot restore from S3; logs; writes status JSON |
| **cloud-init unit** | AMI | Runs first-boot script; reads UserData env |
| **Fleet orchestrator** | new: **pbx3-directory** service or **pbx3api** module | Jobs API, AWS SDK, reuses onboard IAM helpers |
| **SPA Rebuild panel** | **pbx3spa** | Wizard + job progress |
| **Launch template / CFN** | **pbx3-directory** `infra/` (optional) | Parameterized launch for MSPs without orchestrator v1 |

### Job state machine

```text
pending → launching → waiting_up → restoring → configuring → preflight
    → awaiting_dns → awaiting_certs → completed | failed
```

Expose `GET /fleet/rebuild-jobs/{id}` (orchestrator) and optional `GET /api/rebuild-status` on node (local JSON) for debugging.

---

## Fleet-ready AMI (extends S8.2)

Align with **`REBUILD_INSTANCE_RUNBOOK.md`** Phase 1, baked into the image:

| Item | In AMI |
|------|--------|
| `apt update && apt upgrade` | At **image build** time (rebuild AMI on schedule) |
| `ssmtp` + `chmod +x /etc/ssmtp` | Yes |
| `pbx3` deb (pinned version) | Yes |
| `pbx3api` tree at `/opt/pbx3api` | Yes (or pull tagged release at build) |
| `installer.sh` (both) | Run once at bake; throwaway `globals` |
| `PBX3_ORG_BUCKET` in `.env` | **No** until first-boot |
| IAM instance profile | **No** at bake; attached at launch |
| `restore-backup-zip.sh`, `sync-hostname-from-globals.sh` | Yes (package ≥ 0.0.3-21) |

**Image naming:** `pbx3-fleet-ubuntu24.04-arm64-{pbx3_version}` per org or shared golden image.

---

## First-boot contract (UserData / cloud-init)

Orchestrator passes (example):

```bash
PBX3_REBUILD_MODE=1
PBX3_ORG_BUCKET=08jzwn-pbx3
PBX3_INSTANCE_KSUID=3DmAsxePTWQZgynBYXE8obIRqEE
PBX3_BACKUP_STAMP=latest          # or explicit 20260706T001010Z
PBX3_JOB_CALLBACK_URL=https://… # optional
PBX3_BOOTSTRAP_TOKEN=…          # one-time HMAC, optional
AWS_DEFAULT_REGION=us-east-1
```

**Launch requirement:** EC2 must start with instance profile **`pbx3-node-{shortuid}`** already associated (launch template), **or** orchestrator associates profile before first-boot script runs S3 download.

**First-boot sequence** (`pbx3-first-boot-rebuild.sh`):

1. Wait for instance metadata IAM role (retry loop).
2. Resolve backup path (`latest` → newest `PRE` under `instances/{ksuid}/backups/`).
3. Download to `/opt/pbx3/bkup/pbx3bak.{epoch}.zip`.
4. `restore-backup-zip.sh --full`.
5. `sqlite3 … < sqlite_message.sql`.
6. Write fleet block to `/opt/pbx3api/.env` if not restored (mirror onboard template).
7. `php artisan config:clear` + `pbx3:fleet-preflight`.
8. Write `/var/lib/pbx3/rebuild-status.json` (`phase`, `ok`, `errors`, `public_ip`, `stamp`).
9. Optional: POST callback to orchestrator.

**Do not** run `reloader.sh`.

---

## Orchestrator API (sketch)

Auth: MSP admin (Sanctum) or service token — **not** instance role.

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/fleet/instances/{ksuid}/rebuild` | Start job; body: `{ backup_stamp?, instance_type?, subnet_id?, replace_existing_ec2? }` |
| `GET` | `/fleet/rebuild-jobs/{job_id}` | Status, phases, errors, new instance id/IP |
| `POST` | `/fleet/rebuild-jobs/{job_id}/confirm-dns` | Operator confirms DNS updated (manual v1) |
| `POST` | `/fleet/rebuild-jobs/{job_id}/cancel` | Abort if still launching |

Implementation options:

- **A.** Extend **pbx3api** on a central MSP host (only if that host has AWS creds — unusual).
- **B.** Small **fleet-orchestrator** service next to directory ops (preferred): PHP/Laravel or Go, shares `onboard-common.sh` logic ported to AWS SDK.
- **C.** **Step Functions** + Lambda for AWS-only shops; SPA talks to API Gateway.

Reuse from existing tooling:

- IAM: **`onboard-fleet-instance.sh`** / **`lib/onboard-common.sh`**
- Preflight checks: **`FleetPreflightService`**
- S3 layout: **`OPS_S3_RUNBOOK.md`**

---

## SPA panel (sketch)

**Route:** `/fleet/instances/{id}/rebuild` or Instance settings → **Rebuild from backup**.

| Step | UI |
|------|-----|
| 1. Confirm | Instance label, FQDN, KSUID; latest backup stamp + size; recovery point warning |
| 2. Options | Instance type (default `t4g.small`), backup stamp (default latest), blue/green vs replace |
| 3. Launch | Progress bar bound to job API |
| 4. Restore | “Restoring from S3…” (node phase) |
| 5. Verify | Preflight checklist (green/red) |
| 6. DNS | Show new public IP; copy button; optional Route53 auto if configured |
| 7. Certificates | Link to Certificates panel → **Sync**; or trigger API |
| 8. Done | Retire old instance reminder |

**Login during rebuild:** Direct API URL `https://{new_ip}:44300/api` (documented); no Vite proxy required.

---

## Deployment modes

### Mode 1 — MSP orchestrator (target)

Customer uses SPA only. Orchestrator runs in MSP AWS account with permission to launch customer EC2 (cross-account role) or single-account fleet.

### Mode 2 — Launch template + node self-restore

Orchestrator v0: SPA generates **CloudFormation / launch template link** with UserData filled; operator clicks AWS console; node self-restores; SPA polls preflight when customer enters new API URL.

Lower automation, no AWS creds in product — good **Phase B** milestone.

### Mode 3 — Manual runbook (today)

**`REBUILD_INSTANCE_RUNBOOK.md`** — reference implementation for support and regression.

---

## Security

| Risk | Mitigation |
|------|------------|
| AWS keys in SPA | Orchestrator server-side only |
| UserData leaks KSUID | KSUID is not secret; optional signed bootstrap token for callback |
| Rogue node claims catalog | Callback requires token; catalog writes use orchestrator identity |
| IAM privilege escalation | Node role unchanged (`pbx3-node-*` S3 writer); orchestrator uses separate ops role |
| Restore from wrong backup | Job pins `backup_stamp`; preflight asserts `globals.id` |

---

## Phased delivery

| Phase | Deliverable | Customer touch |
|-------|-------------|----------------|
| **B1** | `pbx3-first-boot-rebuild.sh` + systemd; doc in **`REBUILD_INSTANCE_RUNBOOK.md`** § Automated | Launch template + UserData; no SPA |
| **B2** | Fleet AMI build pipeline; **`INSTANCE_ONBOARDING.md`** AMI section | Pick AMI at launch |
| **B3** | Orchestrator MVP: `POST rebuild` + IAM + launch only | Semi-auto |
| **B4** | Node first-boot integrated; job polls preflight | Low |
| **B5** | SPA rebuild wizard | Lowest (except DNS confirm v1) |
| **B6** | Route53 + LE Sync automation | Optional |

**Suggested order:** B1 → B2 → B3 → B4 → B5 → B6.

---

## Blue/green vs in-place

| | Blue/green (recommended) | In-place replace |
|--|--------------------------|------------------|
| Flow | New EC2 + new IP → test → DNS → retire old | Terminate old → launch new same name |
| Risk | Lower | Higher (no rollback IP) |
| IAM | Move profile at cutover | Move at launch |
| Matches lab drill | Yes | Partially |

Default SPA option: **blue/green** with explicit “Cut over DNS” step.

---

## Mapping to shipped S8 artifacts

| Manual step | Automation owner |
|-------------|------------------|
| `fetch-latest-instance-backup.sh` | Node (`aws s3 cp` equivalent) |
| `restore-backup-zip.sh` | Node |
| `onboard-fleet-instance.sh` | Orchestrator (IAM + `.env`); node preflight |
| `pbx3:fleet-preflight` | Node + job gate |
| Mac SSH | Eliminated for rebuild path |
| DNS / LE | Wizard or Route53 (Phase B6) |

---

## Out of scope (v1 automation)

- Full Terraform fleet per customer
- Multi-region failover
- Tenant migration (see **`TENANT_MIGRATION_RUNBOOK.md`**, S8.5–S8.6)
- Automatic termination of old EC2 without explicit confirm
- Building `pbx3` deb inside first-boot (AMI must carry package)

---

## Open decisions

| # | Question | Options |
|---|----------|---------|
| 1 | Orchestrator hosting | Central MSP service vs per-org Lambda |
| 2 | AWS cross-account | Single account only v1 vs STS assume-role |
| 3 | `.env` fleet block writer | Node first-boot vs orchestrator over SSM |
| 4 | Backup stamp selection | Latest only v1 vs picker in SPA |
| 5 | `ssmtp` / package deps | Bake in AMI only vs add to `pbx3` Depends (see runbook) |
| 6 | S8.7 stop/start interaction | Maintenance mode flag in catalog during rebuild job |

---

## Related docs

| Doc | Use |
|-----|-----|
| **`REBUILD_INSTANCE_RUNBOOK.md`** | Manual path; Phase 1 AMI prerequisites |
| **`OPERATOR_MAC_SETUP.md`** | Legacy ops; orchestrator replaces for rebuild |
| **`INSTANCE_ONBOARDING.md`** | Greenfield + fleet-ready AMI |
| **`IMPLEMENTATION_PLAN.md`** § S8.9 | Program tracking |
| **`OPS_S3_RUNBOOK.md`** | Backup layout, IAM policy |
| **`NEW_INSTANCE_CHECKLIST.md`** | Greenfield vs rebuild |

---

## Exit criteria (S8.9)

- [ ] Operator can rebuild from SPA **or** one launch-template click without SSH.
- [ ] New node restores **latest** (or chosen) S3 backup and passes **`pbx3:fleet-preflight`** without manual `onboard-fleet-instance.sh`.
- [ ] IAM association to new instance id is automatic and idempotent.
- [ ] Job status visible in SPA until preflight green.
- [ ] Documented DNS/LE handoff (automated or one confirm click).
- [ ] Regression: repeat golden lab drill using only orchestrator + first-boot (no Mac scripts).
