# PBX3 user guides — MkDocs content map

**Purpose:** One-page plan for **published** documentation (MkDocs Material + GitHub Pages), separate from **`workingdocs/`**.

| Layer | Audience | Location | Role |
|-------|----------|----------|------|
| **User guides** | Installers, MSP ops, PBX administrators | Future **`pbx3-docs`** repo → MkDocs `docs/` | How-to: install, configure, operate — **not for developers** |
| **Workingdocs** | Developers + AI agents | `pbx3` / `pbx3api` / `pbx3spa` / `pbx3-directory` **`workingdocs/`** | Handoffs, audits, TODO, architecture — **not published as-is** |

**Reference implementation:** **`~/Git/sail6-docs`** — `mkdocs-material`, `.github/workflows/ci.yml` → `mkdocs gh-deploy --force` → GitHub Pages.

**Product docs repo:** **`pbx3-docs/`** (holding-folder sibling under `pbx3-master/`). Promote stable pages when operator-facing behaviour is shipped — do **not** mirror `workingdocs/`.

**Site URL (when ready):** `docs.pbx.com` or `{org}.github.io/pbx3-docs` — separate from admin SPA (`app.pbx.com`).

**Local review:** `cd pbx3-docs && mkdocs serve` (see `pbx3-docs/README.md`).

---

## Audience tags

| Tag | Who | Typical tasks |
|-----|-----|----------------|
| **Installer** | Builds nodes, DNS, TLS, fleet/S3, SSH | Package install, `installer.sh`, LE, onboard second node |
| **Admin** | Day-to-day PBX operator via SPA | Tenants, extensions, trunks, routes, backup, certificates UI |
| **Both** | Installers who also operate; MSP leads | Overview, commit/reboot, restore |

**Exclude from MkDocs:** API controller names, Laravel patterns, Cursor handoffs, audit prototypes, branch state, schema migration essays.

---

## Proposed MkDocs navigation

```text
Home                          ← same top-level schematic as “What is PBX3?”
├── Getting started
│   ├── What is PBX3?         ← system schematic (instances · SBC · Gatekeeper · S3); hero of intro
│   ├── Solo trial (one node, no fleet)
│   └── Sign in to the admin UI
├── Installation (Installer)
│   ├── Requirements (Ubuntu 24.04)
│   ├── Install pbx3 and pbx3api
│   ├── First-run installer
│   ├── Upgrade a package
│   └── Restore from backup
├── TLS and certificates (Both)
│   ├── Overview (custom → LE → snakeoil)
│   ├── First Let's Encrypt certificate
│   ├── Sync when tenants change
│   └── Purchased (custom) certificate
├── Admin guide (Admin)
│   ├── Home dashboard (status, commit, start/stop)
│   ├── Tenants
│   ├── Extensions
│   ├── Trunks and outbound routes
│   ├── Inbound routes (DDI)
│   ├── Queues, IVRs, and agents
│   ├── Timers and class of service
│   ├── Backup and restore
│   ├── Firewall
│   ├── Network and site name
│   ├── Instance globals
│   ├── Certificates panel
│   ├── Logs
│   └── Help messages (field hints)
├── Fleet operations (Installer)
│   ├── Fleet overview (catalog + S3)
│   ├── Onboard a second instance
│   ├── Rebuild a fleet node from S3
│   ├── Agent-assisted onboard / rebuild (interim)
│   ├── Backups in the org bucket
│   └── Tenant move (high level)
├── Cloud / S3 reference (Installer)
│   ├── Org bucket layout and CORS
│   ├── Node IAM (writer role)
│   ├── Control host (gatekeeper on EC2)
│   └── SPA catalog URL and Pages CORS
└── Troubleshooting (Both)
    ├── Cannot log in
    ├── Certificate / HTTPS errors
    ├── Commit stays dirty
    └── Backup not visible in SPA
```

---

## Page inventory (promote from workingdocs)

Status: **seeded in `pbx3-docs/`** (2026-07-15) — operator drafts from runbooks; lab URLs included. Expect human edit pass. Live: https://aelintra.github.io/pbx3-docs/

| # | MkDocs page | Audience | Source workingdoc (promote / distill) | Priority | Notes |
|---|-------------|----------|-------------------------------------|----------|-------|
| 1 | What is PBX3? | Both | Distill `FLEET_SYSTEM_OVERVIEW.md` (topology diagrams) + `pbx3/docs/index.md`; Rule 1 call path vs control plane | P1 | **Lead with one schematic:** instances (Asterisk+API), SBC (SIP edge), Gatekeeper (control), org S3 (catalog/backups). Solo = one box; fleet = full picture. No Laravel / workingdocs. SPA + API + node in prose below the figure. |
| 2 | Solo trial | Admin | `pbx3-directory/docs/DESIGN_RULES.md` § Rule 6; `pbx3spa/DEV_ENVIRONMENT.md` § solo only | P1 | No S3/catalog required; not local `npm run dev` |
| 3 | Sign in to the admin UI | Admin | `pbx3spa/DEV_ENVIRONMENT.md` § prod pattern only | P1 | Instance URL / fleet picker; omit Vite proxy |
| 4 | Requirements | Installer | `INSTALL_SEQUENCE_UBUNTU.md` § Prerequisites | P1 | Ubuntu 24.04; appliance mindset |
| 5 | Install pbx3 and pbx3api | Installer | `INSTALL_SEQUENCE_UBUNTU.md` | P1 | Operator rules table → admonitions |
| 6 | First-run installer | Installer | `INSTALL_SEQUENCE_UBUNTU.md` § operator rules | P1 | When to run / not run `reloader.sh` |
| 7 | Upgrade a package | Installer | `INSTALL_SEQUENCE_UBUNTU.md`; `DEBIAN_PACKAGE_IMPROVEMENTS.md` (trim) | P2 | postinst, normalize identity |
| 8 | Restore from backup | Both | `INSTALL_SEQUENCE_UBUNTU.md` § backup restore; `DB_RESTORE_REGRESSION_CHECKLIST.md` (operator slice) | P1 | globals patch, Sync not Renew, help SQL |
| 9 | TLS overview | Both | `TLS_AND_CERTIFICATES.md` §1–3 only | P1 | No script source walkthrough |
| 10 | First LE certificate | Installer | `CERTIFICATES_PANEL_AND_API.md`; `TLS_IMPLEMENTATION_STEPS.md` (operator steps) | P1 | DNS + port 80; panel or bootstrap script |
| 11 | Sync when tenants change | Admin | `LETSENCRYPT_PER_TENANT_FQDN.md` § operator flow | P1 | New tenant → DNS → Sync |
| 12 | Purchased certificate | Admin | `CERTIFICATES_PANEL_AND_API.md` § custom | P2 | Upload / install / remove |
| 13 | Home dashboard | Admin | `STAKEHOLDER_DEMO_SCRIPT.md` § Home | P2 | PBX status, commit, start/stop/reboot |
| 14 | Tenants | Admin | `STAKEHOLDER_DEMO_SCRIPT.md` § Tenants | P2 | Create tenant, FQDN, DNS hint |
| 15 | Extensions | Admin | Demo script + `EXTENSION_PROVISIONING_QUICKSTART.md` (operator slice) | P2 | Create extension; omit AMI internals |
| 16 | Trunks and routes | Admin | Demo script § Trunks / Routes | P2 | SIP trunk create; outbound route |
| 17 | Inbound routes | Admin | Demo script § DDI | P2 | |
| 18 | Queues, IVRs, agents | Admin | Demo script § ACD | P2 | CoS assignment **not** documented until SPA ships |
| 19 | Timers and class of service | Admin | Demo script; CoS rules panel only | P3 | Partial CoS — rules CRUD only today |
| 20 | Backup and restore | Admin | `SINGLE_PANEL_SCREENS.md` § Backup; demo script | P1 | SPA workflow; S3 index mention for fleet |
| 21 | Firewall | Admin | `SINGLE_PANEL_SCREENS.md` § Firewall | P2 | IPv4/IPv6; save + restart |
| 22 | Network and site name | Admin | `NETWORK_SYSGLOBALS_OVERLAP.md` | P2 | Site name editable; hostname read-only |
| 23 | Instance globals | Admin | Demo script; trim identity fields | P3 | What operators may change |
| 24 | Certificates panel | Admin | `CERTIFICATES_PANEL_AND_API.md` (UI only) | P1 | |
| 25 | Logs | Admin | `SINGLE_PANEL_SCREENS.md` § Logs | P3 | View / download |
| 26 | Help messages | Admin | Demo script § Help | P3 | Editing `tt_help_core` hints |
| 27 | Fleet overview | Installer | `pbx3-directory/docs/FLEET_SYSTEM_OVERVIEW.md`; `DESIGN_RULES.md` § topology | P2 | Catalog + bucket; not developer phases |
| 28 | Onboard a second instance | Installer | `INSTANCE_ONBOARDING.md`; `NEW_INSTANCE_CHECKLIST.md`; `onboard-fleet-instance.sh` | P2 | Script-first; IAM preflight summary |
| 28a | Rebuild a fleet node from S3 | Installer | `REBUILD_INSTANCE_RUNBOOK.md` (operator steps only) | P2 | Same KSUID/FQDN; S3 restore; no agent prose |
| 28b | **Agent-assisted onboard / rebuild (interim)** | Installer | Distill **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4 + kickoff in **`REBUILD_INSTANCE_RUNBOOK.md`**; greenfield: checklist + onboard script | **P2** | **Interim equivalent of parked S10.7 / S8.9 orchestrator** — human + AI agent (Cursor/etc.) on Mac with AWS CLI + SSH; approval gates for terminate/DNS/IAM. **Not** `AGENT_HANDOFF` session blocks. Frame: until control-plane cloud adapter ships. |
| 29 | Backups in org bucket | Installer | `OPS_S3_RUNBOOK.md` § backups (operator) | P3 | High level; detail in Cloud / S3 |
| 30 | Tenant move | Installer | `TENANT_MIGRATION_RUNBOOK.md` (high level); Fleet Jobs when promoting | P3 | Panel path after S8/S10 |
| 30a | Org bucket layout and CORS | Installer | `OPS_S3_RUNBOOK.md` (operator slices); `S3_LAYOUT_PROPOSAL.md` distill | P2 | **Reference AWS**; call out S3-compatible (Rule 9) |
| 30b | Node IAM (writer role) | Installer | `OPS_S3_RUNBOOK.md` § node IAM / `apply-node-s3-writer-policy.sh` | P2 | No `tenants/*` blanket; preflight deny probe |
| 30c | Control host (gatekeeper on EC2) | Installer | `CONTROL_HOST.md`; LE on control | P2 | Dynamic IP / SG `/32` refresh; not product coupling to EC2 |
| 30d | SPA catalog URL and Pages CORS | Installer | `OPS_S3_RUNBOOK.md` §9; `DESIGN_RULES.md` § SPA hosting | P2 | Pages origin + bucket CORS + node API CORS |
| 31 | Cannot log in | Both | New (symptoms → checks) | P2 | API URL, TLS, Sanctum, clock |
| 32 | Certificate errors | Both | `TLS_AND_CERTIFICATES.md` troubleshooting slice | P2 | |
| 33 | Commit stays dirty | Admin | New | P3 | Generator / pending changes |
| 34 | Backup not in SPA | Installer | Fleet S3 + IAM (`IMPLEMENTATION_PLAN` § S8 driver) | P3 | |

**Priority:** P1 = first publish set (install + TLS + login + backup). P2 = admin walkthrough + fleet intro + Cloud / S3 reference. P3 = later.

---

## Explicitly not in MkDocs

| Keep in workingdocs only | Why |
|--------------------------|-----|
| `AGENT_HANDOFF.md`, `SESSION_HANDOFF.md`, `TODO.md` | Dev/agent state |
| `*_AUDIT_PROTOTYPE.md`, `PANEL_PATTERN.md`, `PROJECT_PLAN.md` | Implementation |
| `COS_AUDIT_PROTOTYPE.md`, permissions Phase F | Incomplete or dev-only |
| `PBX3API_INSTALLER_NGINX_ADDITIONS.md`, middleware investigations | Developer |
| Full `LETSENCRYPT_PER_TENANT_FQDN.md` §12 phases | Engineering checklist |
| `npm run dev`, Vite proxy, `.env.development` | Developer local setup (`DEV_ENVIRONMENT.md`) |
| `OPEN_SOURCE_GITHUB_SETUP.md`, Track B hardening | Org/process |

**API reference:** Keep **`pbx3api/docs/general.md`** as developer/API digest. MkDocs may link one **“API overview”** page (what the API is for); do not publish full route tables in user guides.

---

## Implementation phases

| Phase | Deliverable | Repo |
|-------|-------------|------|
| **0 — Map** | This file | `pbx3/workingdocs/` ✓ |
| **1 — Shell** | `pbx3-docs` repo: `mkdocs.yml` (top-level **`nav:`**), theme, CI `gh-deploy`, Home + nav + stubs; **What is PBX3?** schematic | `pbx3-docs/` ✓ (local; Pages when remote exists) |
| **2 — P1 pages** | Home + **What is PBX3?** (schematic first) + Install + TLS + login + backup (rows 1, 4–8, 9–11, 3, 20) — **rewrite** for operators, not raw copy | `pbx3-docs` |
| **3 — Admin guide** | Demo-script-aligned chapters (rows 13–26) | `pbx3-docs` |
| **4 — Fleet** | Overview + onboard + rebuild + **agent-assisted interim (28b)** (rows 27–30, 28a–28b) when promoting fleet chapter | `pbx3-docs` |
| **4b — Cloud / S3** | Reference AWS EC2 + S3 guides (rows 30a–30d); Rule 9 framing (S3-compatible OK) | `pbx3-docs` |
| **5 — Maintenance** | When workingdoc operator steps change, update MkDocs in same release; no auto-sync until CI copy script is worth it |

**MkDocs config fixes (when creating repo):** Move **`nav`** out of `extra:` (bug in current `pbx3/mkdocs.yml` / sail6 template). Set `repo_url`, `edit_uri`, `site_url`. Pin `mkdocs-material` version in CI like sail6-docs.

---

## Cross-references

| Doc | Role |
|-----|------|
| `pbx3spa/workingdocs/WORKINGDOCS_RATIONALIZATION_PLAN.md` | Agent workingdocs rules; MkDocs out of scope for agents |
| `pbx3/workingdocs/TODO.md` | Open item: stand up `pbx3-docs` |
| `pbx3-directory/docs/SELF_SERVICE_REBUILD_DESIGN.md` § Mode 4 | **Source of truth** for agent-assisted rebuild (interim S10.7); promote as MkDocs **28b** |
| `pbx3-directory/docs/IMPLEMENTATION_PLAN.md` § S10.7 | Parked orchestrator; points at Mode 4 / this map |
| `pbx3spa/workingdocs/PROJECT_PLAN.md` | Product plan pointer |
| `~/Git/sail6-docs` | Layout and CI reference |
