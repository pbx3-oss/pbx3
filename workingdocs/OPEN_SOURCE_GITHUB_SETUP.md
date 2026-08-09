## PBX3 open-source GitHub setup (checklist)

Use this when creating a **new GitHub organization** for PBX3 and preparing for outside contributors.

### Organization model

- **One org for the project** (neutral name, e.g. `pbx3`).
- **One GitHub account per human** (maintainers + contributors).
- Avoid shared personal accounts. If you need automation beyond Actions, use a **GitHub App** or a **bot user**.

### Repos (initial)

Inventory and version coupling: **`workingdocs/REPOS_AND_RELEASES.md`**. **Policy: multi-repo** (not one amalgamated monorepo).

**Before transferring repos out of `aelintra`:** extract SARK migration code into an **Aelintra-owned** repo (stays behind). See **`TODO.md`** *SARK migration → separate Aelintra repo*.

- `pbx3` — backend package + installer + workingdocs + **`pbx3-directory/`**
- `pbx3api` — API (Laravel) + nginx installer
- `pbx3spa` — admin SPA (Vue) + GitHub Pages deploy (S6.2)
- `pbx3cagi` — Asterisk AGI (C)

Optional later:

- `pbx3-docs` — consolidated website/docs if you want a separate public site

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

### Contributor-facing files (per repo)

- **`LICENSE` (decision locked 2026-08-08):** Product license is **Apache License 2.0** for all product repos (`pbx3`, `pbx3api`, `pbx3spa`, `pbx3cagi`, Magrathea/SBC admin as applicable). **Next (TODO suggested #2):** add the Apache-2.0 `LICENSE` file on each repo. Prefer a simple CLA or DCO once outside contributions start. Cross-link: Lab packaging § in **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** · **`TODO.md`**.
- **Workingdocs (TODO suggested #1 — done):** Product/design docs stay in-repo (curated). Agent **session** handoffs → private **`aelintra/pbx3-ops`** (`~/GiT/pbx3-ops`). See **`TODO.md`** *Workingdocs hygiene*.
- **SARK (TODO #3):** Strip unused SARK leftovers from pbx3 — ETL already in **`aelintra/sark-to-pbx3`** — before public/org transfer.
- `CONTRIBUTING.md` (how to run tests/lint, PR expectations)
- `CODE_OF_CONDUCT.md` (Contributor Covenant is fine)
- `CODEOWNERS` (optional but useful once multiple maintainers exist)

### Releases and automation

- Prefer **GitHub Actions** for CI/release tasks.
- If you need cross-repo automation, prefer a **GitHub App** over a shared account.
- Keep secrets in **GitHub Environments** (with optional approvals) when you start deploying.

### GitHub Pages for `pbx3spa` (S6.2)

- Treat the `github.io` URL as **staging**.
- Prefer a **custom domain** (e.g. `app.pbx.com`) so the public URL survives repo/org moves.
- Remember CORS implications:
  - S3 catalog bucket must allow the SPA origin.
  - Each PBX node API must allow the SPA origin.

### Repo-specific note (this workspace)

`pbx3-master/` is a holding folder. The git repos are `pbx3/`, `pbx3api/`, `pbx3spa/`.

