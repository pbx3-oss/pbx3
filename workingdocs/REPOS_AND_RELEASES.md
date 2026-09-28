# PBX3 repositories and releases

**Purpose:** Single inventory of **git repos**, **deploy targets**, and **version coupling**. Update when tagging releases.

**Decision:** Stay **multi-repo** (not one amalgamated monorepo). Different languages, deploy paths, and release cadences. See **`OPEN_SOURCE_GITHUB_SETUP.md`** for org/teams/security.

**Local dev:** **`pbx3-master/`** is a **holding folder** (not a git repo). Clone the repos below into it side by side.

---

## Repository inventory

| Repo | Remote (2026-09-28) | Role | Deploy / host | Workingdocs |
|------|---------------------|------|---------------|-------------|
| **pbx3** | `github.com/pbx3-oss/pbx3` (**public**) | Node backend: SQLite, Asterisk gen, scripts, `.deb` | **Each PBX instance** (`apt install pbx3`) | `pbx3/workingdocs/` |
| **pbx3api** | `github.com/pbx3-oss/pbx3api` (**public**) | Laravel API + nginx installer | **Each instance** (`/opt/pbx3api`, `:44300`) | `pbx3api/workingdocs/` |
| **pbx3spa** | `github.com/pbx3-oss/pbx3spa` (**public**) | Admin SPA (Vue 3 + Vite) | **GitHub Pages** (central; not on node AMIs) | `pbx3spa/workingdocs/` |
| **pbx3cagi** | `github.com/pbx3-oss/pbx3cagi` (**public**) | Asterisk AGI (C) | **Each instance** (with Asterisk) | `pbx3cagi/workingdocs/` |
| **pbx3-directory** | *inside **pbx3** repo* (`pbx3-directory/`) | Fleet catalog, S3 ops scripts, registrar | **Org S3** + Mac ops; not on call path | `pbx3/pbx3-directory/docs/` |
| **pbx3-docs** | `github.com/pbx3-oss/pbx3-docs` (**public**) | Operator/installer MkDocs site | **GitHub Pages** `https://pbx3-oss.github.io/pbx3-docs/` (`docs.pbx.com` TBD) | N/A — see **`USER_GUIDES_MKDOCS_CONTENT_MAP.md`** |
| **pbx3sbc** | `github.com/pbx3-oss/pbx3sbc` (**public**) | OpenSIPS edge | SBC host | `pbx3sbc/` docs |
| **pbx3sbc-admin** | `github.com/pbx3-oss/pbx3sbc-admin` (**public**) | Filament SBC admin | SBC host | `pbx3sbc-admin/workingdocs/` |
| **pbx3-ops** | `github.com/aelintra/pbx3-ops` (**private**) | Agent session handoffs, tip/lab gossip | Local clone **`~/GiT/pbx3-ops`**; not shipped | This repo |

**OSS org:** `github.com/pbx3-oss/…` — product + SBC **public** (transfer **done** 2026-09-28). Execution record (private): **`~/GiT/pbx3-ops/devdocs/oss-move/OSS_ORG_TRANSFER_PLAN.md`**.

**Stay under Aelintra (private):** **`pbx3-ops`**, **`sark-to-pbx3`**, **`sipplabs`**. Gatekeeper remains inside **`pbx3/pbx3-directory/`** (no separate repo for now).

**Not in git (holding folder):** `pbx3-master/` workspace root; transient exports (e.g. `tt_help_core.json` at workspace root).

---

## Branch policy

| Repo | Default branch | Notes |
|------|----------------|--------|
| pbx3, pbx3api, pbx3spa, pbx3cagi | **`main`** | Feature branches merge to `main`; deleted when done |

---

## Compatibility matrix (known-good)

**Rule:** A fleet node is “known good” when **package + API + (optional) SPA build** match a row below. Golden **08jzwn** is the reference node unless noted.

| Label | pbx3 package | pbx3 `main` | pbx3api `main` | pbx3spa `main` | pbx3cagi `main` | Notes |
|-------|--------------|-------------|----------------|----------------|-----------------|-------|
| **Golden dev (2026-07-02)** | **0.0.3-19** | `f6ac084` | `428209f` * | `5d00f3f` | `9768193` | \* API on golden may lag — **deploy pbx3api** for queue/trunk panel fixes |
| *Next tagged release* | TBD | tag | tag | tag | tag | Tag all repos when cutting a public release |

**Update this table** when:

- Golden gets a new **pbx3** deb
- You deploy **pbx3api** / **pbx3spa** to production Pages
- You cut an OSS **release** (git tags + changelog)

---

## Why multi-repo (not monorepo)

| Factor | Multi-repo (chosen) | Monorepo |
|--------|---------------------|----------|
| Deploy | deb / PHP / Pages / AGI ship independently | One clone, mixed CI |
| Toolchain | Debian, Laravel, Vue, C — separate builds | Heavy unified pipeline |
| Permissions | Grant access per component later | All-or-nothing |
| Your workflow | Already commit per repo; `pbx3-master` local layout | Large migration for little gain |

**Coordination:** Cross-cutting features (e.g. queue panel) = coordinated PRs in **pbx3api** + **pbx3spa** (+ **pbx3** if schema/scripts); track in **`TODO.md`** and this matrix.

---

## Packaging cadence (locked 2026-08-11)

Historical pain: bumping a fat **main** `.deb` for every biggish patch. Forerunner AGI changed rarely once stable — that cadence still fits **cagi**.

| Component | Cadence |
|-----------|---------|
| **pbx3cagi** | **Deb-first** — new floor when the binary moves; rare is good. |
| **pbx3** | **Release / AMI / try-it floors** as `.deb` (pin + Depends). **Between floors:** tip / rsync under `/opt/pbx3` is first-class (lab + hotfix). Do not invent `0.0.x-N` for every patch. Tip SHAs → ops **`TODO_OPS.md`**. **Next UFW floor:** tip Phases 1–4 ship as **`0.0.6-1`** (skip packaging unshipped 0.0.5-7/8 drafts). |
| **pbx3api** | Clone-at-tag / tip; optional `.deb` deferred (**TODO #6** / try-it D6). |

Detail: **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** § Public GitHub org vs packages.

---

## Local clone layout

```bash
mkdir pbx3-master && cd pbx3-master
git clone https://github.com/pbx3-oss/pbx3.git
git clone https://github.com/pbx3-oss/pbx3api.git
git clone https://github.com/pbx3-oss/pbx3spa.git
git clone https://github.com/pbx3-oss/pbx3cagi.git
git clone https://github.com/pbx3-oss/pbx3-docs.git
# Optional edge:
# git clone https://github.com/pbx3-oss/pbx3sbc.git
# git clone https://github.com/pbx3-oss/pbx3sbc-admin.git
# Private ops (session handoffs) — sibling of holding folder, not inside it:
# git clone https://github.com/aelintra/pbx3-ops.git ~/GiT/pbx3-ops
# pbx3-directory is already under pbx3/pbx3-directory/
```

---

## Related docs

| Doc | Contents |
|-----|----------|
| **OPEN_SOURCE_GITHUB_SETUP.md** | Org creation, teams, branch protection, Pages/CORS |
| **USER_GUIDES_MKDOCS_CONTENT_MAP.md** | Future **pbx3-docs** repo |
| **AGENT_HANDOFF.md** | Product stub (behavior + read-order); live session → **`~/GiT/pbx3-ops`** |
| **SESSION_END_CHECKLIST.md** | Stub → **`~/GiT/pbx3-ops/SESSION_END_CHECKLIST.md`** |
