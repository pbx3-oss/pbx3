## PBX3 open-source GitHub setup (checklist)

Use this when creating a **new GitHub organization** for PBX3 and preparing for outside contributors.

### Organization model

- **One org for the project** (neutral name, e.g. `pbx3`).
- **One GitHub account per human** (maintainers + contributors).
- Avoid shared personal accounts. If you need automation beyond Actions, use a **GitHub App** or a **bot user**.

### Repos (initial)

Inventory and version coupling: **`workingdocs/REPOS_AND_RELEASES.md`**. **Policy: multi-repo** (not one amalgamated monorepo).

**Before transferring repos out of `aelintra`:** keep private migrate ETL under Aelintra (already extracted). See **`TODO.md`**.

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

- **Workingdocs (TODO suggested #1 — done; light peel 2026-08-09):** Product/design **locks and active requirements** stay in-repo (agent locality). Agent **session** handoffs + **research/audits/tippy lab** → private **`aelintra/pbx3-ops`** (`~/GiT/pbx3-ops`, including **`devdocs/`**). See **`TODO.md`** · **`workingdocs/README.md`**.
- **`LICENSE` (landed 2026-08-09):** Product license is **Apache License 2.0** for all product repos (`pbx3`, `pbx3api`, `pbx3spa`, `pbx3cagi`, Magrathea/SBC admin). Root `LICENSE` is the clean Apache-2.0 text (not the httpd composite). Packaging copyright: **Aelintra Telecom Limited** (`debian/copyright` where present; composer/`package.json` `license` fields). Prefer a simple CLA or DCO once outside contributions start. Cross-link: Lab packaging § in **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** · **`TODO.md`**.
- **Customer migrate (TODO #3 — done 2026-08-09):** Migrate entrypoints stripped from pbx3; private ETL remains under Aelintra. Product keeps shortuid normalize repair only.
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

