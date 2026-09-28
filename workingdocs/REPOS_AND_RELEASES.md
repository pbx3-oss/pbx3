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

**OSS org:** `github.com/pbx3-oss/…` — product + SBC **public** (transfer **done** 2026-09-28). Gatekeeper remains inside **`pbx3/pbx3-directory/`** (no separate repo for now).

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
| **Golden floor (2026-09-28)** | **0.0.6-9** | `fa6a78d` | tip | tip | **1.0.0-23** (`14fc295`+) | #0q OCLO/BLF shortuid; dual-arch cagi. Install when rolling homes. |
| **Golden floor (2026-09-27)** | **0.0.6-8** | (prior) | tip | tip | **1.0.0-22** | CoS profiles. |
| *Next umbrella (`PBX3 Lab YYYY.MM`)* | pin deb | tag/SHA | tag/SHA | tag/SHA | pin deb | Cut only for Lab/AMI/public story — see **Release doctrine** |

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
| **pbx3cagi** | **Deb-first** — new floor when the binary moves; rare is good. **`Architecture: all`** with **amd64 + arm64** AGI binaries (build: lab `.213` amd64 + `.148`/golden arm64 — see **`pbx3cagi/README.md` § Packaging**). **Git regress window:** keep **last three** release `.deb`s force-added on `main`; drop the oldest when adding a new one. |
| **pbx3** | **Release / AMI / try-it floors** as `.deb` (pin + Depends). **Between floors:** tip / rsync under `/opt/pbx3` is first-class (lab + hotfix). Do not invent `0.0.x-N` for every patch. Tip SHAs → ops **`TODO_OPS.md`**. **Next UFW floor:** tip Phases 1–4 ship as **`0.0.6-1`** (skip packaging unshipped 0.0.5-7/8 drafts). |
| **pbx3api** | Clone-at-tag / tip; optional `.deb` deferred (**TODO #6** / try-it D6). |

Detail: **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** § Public GitHub org vs packages.

---

## Release doctrine (locked 2026-09-28)

Two clocks. Do not invent a third.

| Clock | What | Where recorded |
|-------|------|----------------|
| **Floor** (rare) | Installable pins: **`pbx3_*.deb`**, **`pbx3cagi_*.deb`** | debian changelog + force-added deb on that repo’s `main`; optional git tag on the release commit |
| **Tip** (often) | Hotfixes / lab HEAD for any repo | Private ops tip ledger (**`TODO_OPS.md`**) — SHAs + which hosts. **Not** a new deb for every patch. |

**pbx3api / pbx3spa / pbx3-docs / SBC:** tip or git tag when useful; **no** `.deb` until a real apt/AMI need (api D6 stayed deferred 2026-09-28 — Composer/Laravel churn).

### A — Ship a floor (pbx3 or pbx3cagi)

1. Land the code on `main` and tip-prove if it matters (golden / lab).
2. Bump that repo’s `debian/changelog`.
3. Build the `_all.deb` (cagi: dual-arch per **`pbx3cagi/README.md` § Packaging**; pbx3: `cd pbx3-1 && dpkg-buildpackage -us -uc -b` on a noble builder, e.g. lab `.148`).
4. Commit changelog + `git add -f` the new deb; push.
5. **Cagi only:** keep **last three** debs tracked; `git rm --cached` the oldest.
6. Optional: `git tag -a pbx3-0.0.6-9 -m "…" && git push origin tag` (same pattern for cagi).
7. Install on the homes that should move to the floor; note hosts in **`TODO_OPS.md`**.

### B — Tip between floors (any repo)

1. Merge/push `main` as usual.
2. Deploy via existing path (rsync `/opt/pbx3`, api tip, spa Pages/`npm run dev`, etc.).
3. Update **`TODO_OPS.md`**: tip SHA(s) + which host is hot. No debian bump.

### C — Named product / Lab / AMI bundle (umbrella — only when you need a public story)

Use when advertising a Lab pin, cutting an AMI, or telling outsiders “use this set.” Skip for ordinary lab weeks.

1. Choose a label: **`PBX3 Lab YYYY.MM`** (CalVer month is enough).
2. Fill one row in the **Compatibility matrix** above with concrete pins:
   - `pbx3` deb version (+ optional git tag)
   - `pbx3cagi` deb version (+ optional git tag)
   - `pbx3api` / `pbx3spa` / docs: **git tag or short SHA** (tag preferred if you ask others to clone)
3. Optional: GitHub Release on **`pbx3-docs`** or org profile README that links the matrix row + install pages (don’t duplicate artefact blobs into a fourth place).
4. Point try-it / AMI build scripts at those pins only — not at floating `main`.

### D — What not to do

- New `0.0.x-N` for every tip hotfix.
- One SemVer for the whole product that increments when spa or docs change.
- Packaging **pbx3api** just for symmetry with pbx3/cagi.
- Recording tip SHAs only in chat — ops **`TODO_OPS.md`** is the tip ledger.

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
# pbx3-directory is already under pbx3/pbx3-directory/
```

---

## Related docs

| Doc | Contents |
|-----|----------|
| **OPEN_SOURCE_GITHUB_SETUP.md** | Org creation, teams, branch protection, Pages/CORS |
| **USER_GUIDES_MKDOCS_CONTENT_MAP.md** | **pbx3-docs** content map |
| **AGENT_HANDOFF.md** | Product stub (behavior + read-order) |
| **SESSION_END_CHECKLIST.md** | Product stub → private ops session checklist |
