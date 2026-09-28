# Agent notes (PBX3)

This repository is part of **PBX3**. Prefer **MkDocs + in-repo runbooks** over inventing procedures.

## Operator assist

- Public posture: `workingdocs/AI_ASSISTED_OPERATOR_REQUIREMENTS.md`
- Kickoffs: docs site → Getting started → **AI-assisted operations** / Installation → **AI-assisted install**
- Run **shipped** installers (`scripts/install-home-host.sh`, `pbx3-directory/tools/`, …). Do not create a parallel install path.

## Human gates

Ask before: VM launch/terminate, DNS cutover, production LE, IAM/long-lived keys, destructive tenant/DB wipes, unpaid spend, force-push on shared remotes.

Never put ops IAM or deploy secrets in the admin SPA or browser.

## Truth

- Design rules: `pbx3-directory/docs/DESIGN_RULES.md`
- Package / clone inventory: `workingdocs/REPOS_AND_RELEASES.md`
- Operator docs: separate repo `pbx3-docs` (MkDocs)
