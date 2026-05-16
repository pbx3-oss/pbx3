# pbx3-directory (project stub)

**Status:** Stub only — not a deployed service yet. Defines the **instance directory** (control-plane index) for **Model B** central admin.

**Product direction:** **pbx3spa** repo — **`workingdocs/CENTRAL_ADMIN_DIRECTION.md`**

**Current priority:** Finish **per-instance Let's Encrypt / TLS** on pbx3 nodes before implementing this project.

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
    instance-record.v0.json   ← JSON Schema for one instance
    instance-index.v0.json    ← example full index file
```

---

## Not in scope for this stub

- Runtime code, Terraform, or S3 buckets
- Central auth implementation
- Changes to per-node `pbx3` / `pbx3api` installers

Those follow after schema agreement and LE work is merged.

---

## Git

This folder lives in the **pbx3** repository at **`pbx3-directory/`**. When the service is real, it may split into its own repository (e.g. `github.com/aelintra/pbx3-directory`).
