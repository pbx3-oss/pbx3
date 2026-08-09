# Pre-release safety debt (go / no-go)

**Status:** Near-time — **before release go/no-go**. Not a feature track.  
**Opened:** 2026-08-09 (six-repo debt pass).  
**Detail canvases (operator IDE):** `~/.cursor/projects/Users-jeffstokoe-GiT-pbx3-master/canvases/` — `tech-debt-rollup.canvas.tsx` plus per-repo `*-tech-debt-pass.canvas.tsx`.

Parked / deep refactors (GenClass splits, Phase 4 file splits, Track A/B SKUs, cookie SSO, etc.) stay parked — **do not** block this list.

---

## Fix-now cluster (release gate)

Work in roughly this order; stop when go/no-go criteria below are met.

| # | Repo | Item | Notes |
|---|------|------|--------|
| 1 | **pbx3cagi** | `GetExt` / `Mangle` return stack pointers (UB) | Caller buffers or clear lifetime |
| 2 | **pbx3cagi** | `outboundClip` / `CFCheck` / Voicemail buffer overflows | `snprintf` / sized scratch |
| 3 | **pbx3cagi** | Fail closed on default sys/spy pass (`4444`/`3333`) | No authenticate with defaults |
| 4 | **pbx3api** | CosClose / CosOpen cluster scope | Tenant IDOR |
| 5 | **pbx3api** | Destinations require cluster + clamp | No full-instance leak |
| 6 | **pbx3api** | Hide secrets in JSON (`Trunk`/`Tenant`/`Agent`) | `$hidden` / write-only |
| 7 | **pbx3api** | Restrict twin AstDB AMI writes | Ability + key ACL |
| 8 | **pbx3** | Dumper SQL escape + falsy column skip | Reloader data integrity |
| 9 | **pbx3** | GenClass `appl.cluster` use shortuid | Dialplan gap after normalize |
| 10 | **pbx3sbc** | Bind MI/metrics to localhost (not `0.0.0.0:8888`) | |
| 11 | **pbx3sbc** | Escape / parameterize SIP→SQL concat | Slice D / door-knock |
| 12 | **pbx3sbc-admin** | Lock Filament edits on fleet-owned `dr_rules` | Rule 13 |
| 13 | **pbx3sbc-admin** | Surface MI reload failure (don’t claim ok) | |
| 14 | **pbx3sbc-admin** | DB password off sudo argv | Whitelist sync |
| 15 | **pbx3spa** | Mask SIP password in extension UI | |
| 16 | **pbx3spa** | Fleet GK 401 clears stale token | |

**Also near-time (data integrity):** Tenant wipe already cascades in app code — harden gaps in **`TENANT_DELETE_DATA_INTEGRITY.md`** (T2–T5: sibling dialaliases, park parity, orphan audit, schema↔wipe-list CI). Do **not** gate Delete on empty dependents.

**Shared:** AMI password out of source (`pbx3` + `pbx3api`) — schedule with secret rotation (same week if time).

---

## Go / no-go (this list)

**Go** when: items **1–16** landed (or explicit accepted risk noted per row) + smoke on golden/bzy (dial + SPA login + one fleet DID path).

**No-go** if: open Critical/High from the table without accepted risk, especially cagi UB/overflows or api tenant IDOR.

---

## Explicitly later (not this gate)

- SPA bundle diet (**N1**), Devices route drop (**N7**), sessiontimout honour (**N4**)  
- GenClass splits / cagi Phase 4 / LDAP strategy  
- Fleet token scopes/mTLS, TOTP require-admin  
- UA harvest sidekick, OSS org transfer  

See rollup canvas + per-repo canvases for the full medium/low inventory.
