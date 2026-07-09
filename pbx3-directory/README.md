# pbx3-directory (project stub)

**Status:** Stub only — not a deployed service yet. Defines the **instance directory** (control-plane index) for **Model B** central admin.

**New here?** Read **`docs/FLEET_SYSTEM_OVERVIEW.md`** — plain-language, diagram-led introduction to the whole fleet (Instance / Tenant / SBC / S3). **Trunk/peering placement:** **`docs/FLEET_TRUNK_PEERING_DECISION.md`**. **DID assignment (central registry vs inroutes-only):** **`docs/DID_ASSIGNMENT_DESIGN.md`**.

**Product direction:** **pbx3spa** repo — **`workingdocs/CENTRAL_ADMIN_DIRECTION.md`**

**Current priority:** Branch **`directory`**. **Start:** **`docs/IMPLEMENTATION_PLAN.md`** (phases + ToDo) → **`docs/DESIGN_RULES.md`** → **`docs/S3_LAYOUT_PROPOSAL.md`** → **`docs/OPS_S3_RUNBOOK.md`** (bucket/IAM/CORS) → **`schema/`**.

---

## Purpose

Maintain a **canonical map of PBX instances** (FQDN, API URL, identity, ACL scope) so:

- The **central pbx3spa** can show “instances you may access” after login (not a raw API URL).
- Future services can run **central monitoring**, **tenant migration**, and MSP/superuser flows.

**Storage (TBD):** Likely S3 object(s) (index/map); may later add a small API that caches/serves the same JSON.

---

## Repo layout (stub)

```text
pbx3-directory/
  README.md                 ← this file
  docs/OVERVIEW.md          ← architecture and open questions
  schema/
    instance-record.v0.json   ← catalog row (picker)
    instance-index.json       ← example catalog (same key in S3: catalog/instance-index.json)
    instance-meta.v0.json     ← instances/{ksuid}/meta.json
    tenant-meta.v0.json       ← tenants/{shortuid}/meta.json
    did-record.v0.json        ← single DID (catalog/dids/{e164_key}.json)
    did-inventory.v0.json     ← tenants/{shortuid}/dids.json
    did-index.v0.json         ← catalog/did-index.json (compiled)
    backup-manifest.v0.json
    retention-policy.v0.json  ← policy.json (backups/recordings)
```

---

## Ops

- **`docs/OPS_S3_RUNBOOK.md`** — **Quick recipe** (console checklist), bucket policy, CORS, node IAM, Laravel S3 (Phase 4).
- **`docs/INSTANCE_ONBOARDING.md`** — manual steps + **`onboard-fleet-instance.sh`** (preferred).
- **`tools/README.md`** — Phase 3 registrar (`register-instance.sh`, `register-tenant.sh`, `move-tenant.sh`).

## Not in scope for this stub

- Runtime code, Terraform (runbook is manual CLI; IaC later)
- Central auth implementation
- Changes to per-node `pbx3` / `pbx3api` installers

Those follow after schema agreement and LE work is merged.

---

## Git

This folder lives in the **pbx3** repository at **`pbx3-directory/`**. When the service is real, it may split into its own repository (e.g. `github.com/aelintra/pbx3-directory`).
