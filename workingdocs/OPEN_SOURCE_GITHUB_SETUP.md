## PBX3 open-source GitHub setup (checklist)

Use this when creating a **new GitHub organization** for PBX3 and preparing for outside contributors.

**Transfer execution plan (phases + checklists):** private ops **`~/GiT/pbx3-ops/devdocs/oss-move/OSS_ORG_TRANSFER_PLAN.md`** — slug **`pbx3-oss`** (was `pbx3`, taken; not `fleetpbx` — FreePBX rhyme). **Executed 2026-09-28** (Phases 0–4): seven product/SBC repos **public** under `pbx3-oss`; harden + URL retarget done. Do not keep that plan in product repos.

### Organization model

- **One org for the project** (forge slug: **`pbx3-oss`** — locked; product name remains **PBX3**).
- **One GitHub account per human** (maintainers + contributors).
- Avoid shared personal accounts. If you need automation beyond Actions, use a **GitHub App** or a **bot user**.

### Repos (initial)

Inventory and version coupling: **`workingdocs/REPOS_AND_RELEASES.md`**. **Policy: multi-repo** (not one amalgamated monorepo). Full transfer matrix: private **`~/GiT/pbx3-ops/devdocs/oss-move/OSS_ORG_TRANSFER_PLAN.md`**.

**Private under Aelintra (unchanged):** `pbx3-ops`, `sark-to-pbx3`, `sipplabs`. See **`TODO.md`** · **`REPOS_AND_RELEASES.md`**.

Transfer set (all **public** under org **`pbx3-oss`** — done):

- `pbx3` — backend package + installer + workingdocs + **`pbx3-directory/`** (Gatekeeper stays nested — no extract now)
- `pbx3api` — API (Laravel) + nginx installer
- `pbx3spa` — admin SPA (Vue) + GitHub Pages deploy (S6.2)
- `pbx3cagi` — Asterisk AGI (C)
- `pbx3-docs` — operator MkDocs site
- `pbx3sbc` / `pbx3sbc-admin` — edge + Filament admin

### Teams and permissions (minimal, scalable)

- **maintainers**: admin on core repos
- **core**: write on core repos
- **triage**: issues/labels only

### Branch protection (per repo)

On the default branch (usually `main`):

- Require **pull requests** (no direct pushes)
- Require **1 approval** (raise later if needed)
- Require **status checks** (tests/lint) to pass
- Block force-push

### Required baseline security

- Require **2FA** for org members
- Enable **Dependabot alerts** + **security updates**
- Add a minimal `SECURITY.md` (“how to report vulnerabilities privately”)

### AI-assisted operator (OSS face)

- **Lock:** **`workingdocs/AI_ASSISTED_OPERATOR_REQUIREMENTS.md`** — **§0:** CLI/MkDocs decks lead; AI is thin optional co-pilot (**not a panacea**). Same installers; human gates; no browser ops IAM; stepwise checks (A11).
- **MkDocs:** classical Installation nav first; AI-assisted pages are parallel siblings. Fleet → Agent-assisted onboard/rebuild.
- **Per public repo:** thin root **`AGENTS.md`**. Org/README: classical clone/docs **before** any AI blurb.

### Contributor-facing files (per repo)

- **Workingdocs (TODO suggested #1 — done; light peel 2026-08-09):** Product/design **locks and active requirements** stay in-repo (agent locality). Agent **session** handoffs + **research/audits/tippy lab** → private **`aelintra/pbx3-ops`** (`~/GiT/pbx3-ops`, including **`devdocs/`**). See **`TODO.md`** · **`workingdocs/README.md`**.
- **`LICENSE` (landed 2026-08-09):** Product license is **Apache License 2.0** for all product repos (`pbx3`, `pbx3api`, `pbx3spa`, `pbx3cagi`, SBC/SBC admin). Root `LICENSE` is the clean Apache-2.0 text (not the httpd composite). Packaging copyright: **Aelintra Telecom Limited** (`debian/copyright` where present; composer/`package.json` `license` fields). Cross-link: Lab packaging § in **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** · **`TODO.md`**. Ops stance: **License ops** below.
- **Customer migrate (TODO #3 — done 2026-08-09):** Migrate entrypoints stripped from pbx3; private ETL remains under Aelintra. Product keeps shortuid normalize repair only.
- `CONTRIBUTING.md` (how to run tests/lint, PR expectations; point at License ops + DCO when public)
- `CODE_OF_CONDUCT.md` (Contributor Covenant is fine)
- `CODEOWNERS` (optional but useful once multiple maintainers exist)

### License ops (Apache-2.0) — locked stance 2026-08-12

Not legal advice. How we **operate** Apache-2.0 so it does not fight git or scare third-party contribs.

| Topic | Stance |
|-------|--------|
| **Modified-file notices** | **Do not** require a hand-stamped “this file was changed” banner on every edit. **Git history + PRs** are the record of modification. Optional short copyright/SPDX headers where already used are fine; do not invent a second changelog workflow. |
| **Attribution / NOTICE** | Ship root **`LICENSE`** in every repo and in packaged artefacts (debs, release tarballs). Add a root **`NOTICE`** when a distribution bundles third-party material that needs call-outs; keep it short; grow it when needed — not preemptively empty ceremony. |
| **Third-party contribs** | Welcomed when repos are public. Prefer **DCO** (`Signed-off-by` on commits) + **`CONTRIBUTING.md`** (“you must have rights to what you submit”) over a heavy CLA at first. Escalate to CLA only if corporate inbound later demands it. Maintainers still review/merge; open source ≠ unfiltered merge. |
| **Trademark** | Apache-2.0 does **not** grant trademark rights. Product/org names (**PBX3**, **Aelintra**, …) stay separate from the code license; forks must not imply endorsement. |
| **GPL / heritage** | Do not ship **GPLv2-only** sources inside Apache product trees. Private migrate ETL stays under Aelintra. Runtime neighbours (Asterisk, OpenSIPS) are separate programs — do not fold their sources into these repos without a deliberate license plan. |

**Why open source anyway:** Apache-2.0 is a normal choice for community PRs (inbound ≈ outbound + patent grant). The “CLA risk” and “modify every file” talking points are real on paper; DCO + git + NOTICE is how most Apache-2.0 projects actually run.

### Releases and automation

- Prefer **GitHub Actions** for CI/release tasks.
- If you need cross-repo automation, prefer a **GitHub App** over a shared account.
- Keep secrets in **GitHub Environments** (with optional approvals) when you start deploying.

### GitHub Pages for `pbx3spa` (S6.2)

- **Custom domain (locked 2026-09-28):** **`https://app.pbx3.com`** → GitHub Pages (`pbx3-oss/pbx3spa`). DNS: CNAME `app` → `pbx3-oss.github.io`.
- **Product path:** one shared SPA. Builders/operators open **`app.pbx3.com`**, point it at **their** catalog (runtime / `?catalog=`). They do **not** need their own Pages host.
- Treat bare `*.github.io/pbx3spa` as fallback only.
- CORS for that shared origin:
  - Each fleet org bucket must allow origin `https://app.pbx3.com`
  - Each PBX node API must allow the same origin
- Deploy (maintainers only): **`pbx3spa`** Actions workflow **`pages.yml`** (Node 24 → `dist/` → Pages).

### Repo-specific note (this workspace)

`pbx3-master/` is a holding folder. The git repos are `pbx3/`, `pbx3api/`, `pbx3spa/`.

