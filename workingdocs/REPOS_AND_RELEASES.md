# PBX3 repositories and releases

**Purpose:** Single inventory of **git repos**, **deploy targets**, and **version coupling**. Update when tagging releases or moving to the OSS GitHub org.

**Decision:** Stay **multi-repo** (not one amalgamated monorepo). Different languages, deploy paths, and release cadences. See **`OPEN_SOURCE_GITHUB_SETUP.md`** for org/teams/security.

**Local dev:** **`pbx3-master/`** is a **holding folder** (not a git repo). Clone the repos below into it side by side.

---

## Repository inventory

| Repo | Remote today (2026-07) | Role | Deploy / host | Workingdocs |
|------|------------------------|------|---------------|-------------|
| **pbx3** | `github.com/aelintra/pbx3` | Node backend: SQLite, Asterisk gen, scripts, `.deb` | **Each PBX instance** (`apt install pbx3`) | `pbx3/workingdocs/` |
| **pbx3api** | `github.com/aelintra/pbx3api` | Laravel API + nginx installer | **Each instance** (`/opt/pbx3api`, `:44300`) | `pbx3api/workingdocs/` |
| **pbx3spa** | `github.com/aelintra/pbx3spa` | Admin SPA (Vue 3 + Vite) | **GitHub Pages** (central; not on node AMIs) | `pbx3spa/workingdocs/` |
| **pbx3cagi** | `github.com/aelintra/pbx3cagi` | Asterisk AGI (C) | **Each instance** (with Asterisk) | `pbx3cagi/workingdocs/` |
| **pbx3-directory** | *inside **pbx3** repo* (`pbx3-directory/`) | Fleet catalog, S3 ops scripts, registrar | **Org S3** + Mac ops; not on call path | `pbx3/pbx3-directory/docs/` |
| **pbx3-docs** | *planned* | Operator/installer MkDocs site | **GitHub Pages** (`docs.pbx.com` TBD) | N/A — see **`USER_GUIDES_MKDOCS_CONTENT_MAP.md`** |

**Target org (OSS):** e.g. `github.com/pbx3/{pbx3,pbx3api,pbx3spa,pbx3cagi,pbx3-docs}` — transfer from `aelintra` when org exists; update remotes in local clones.

**Before transfer:** extract **SARK V6 → pbx3 migration** (`db_legacy_sql`, migrate helpers, etc.) into a **separate repo that remains under `aelintra`** — see **`TODO.md`** *SARK migration → separate Aelintra repo*. Do not move that bridge with the OSS product tree.

**Not in git:** `pbx3-master/` workspace root; transient exports (e.g. `tt_help_core.json` at workspace root).

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

## Local clone layout

```bash
mkdir pbx3-master && cd pbx3-master
git clone https://github.com/aelintra/pbx3.git
git clone https://github.com/aelintra/pbx3api.git
git clone https://github.com/aelintra/pbx3spa.git
git clone https://github.com/aelintra/pbx3cagi.git
# pbx3-directory is already under pbx3/pbx3-directory/
```

After org move: replace `aelintra` with `pbx3` (or chosen org slug).

---

## Related docs

| Doc | Contents |
|-----|----------|
| **OPEN_SOURCE_GITHUB_SETUP.md** | Org creation, teams, branch protection, Pages/CORS |
| **USER_GUIDES_MKDOCS_CONTENT_MAP.md** | Future **pbx3-docs** repo |
| **AGENT_HANDOFF.md** | Agent entry; git layout reminder |
| **SESSION_END_CHECKLIST.md** | End-of-session handoff updates |
