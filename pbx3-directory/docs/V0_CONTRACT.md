# Directory v0 contract (pointer)

**Catalog (SPA login):** `catalog/instance-index.json`

```json
{
  "version": 1,
  "updated_at": "<ISO-8601 UTC>",
  "instances": [ { /* instance record */ } ]
}
```

**Instance record (required):** `id`, `fqdn`, `api_base_url`, `label`, `status`  
**Optional:** `environment`, `org_id`, `region`, `notes`, `package_version`, `last_seen_at`  
**Schema:** `schema/instance-record.v0.json` · **Example:** `schema/instance-index.json`

**Instance meta:** `instances/{globals.id}/meta.json` — `schema/instance-meta.v0.json`  
**Tenant meta:** `tenants/{cluster.shortuid}/meta.json` — `schema/tenant-meta.v0.json` (required)

**Backups:** `instances/{ksuid}/backups/{stamp}/backup.zip` + `manifest.json` + `policy.json` — Phase 4

**Registrar:** `tools/register-instance.sh`, `unregister-instance.sh`, `register-tenant.sh`, `move-tenant.sh`  
**Validate:** `tools/validate-index.sh`

**Rules:** `DESIGN_RULES.md` · **Ops:** `OPS_S3_RUNBOOK.md`
