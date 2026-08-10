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
| 1 | **pbx3cagi** | `GetExt` / `Mangle` return stack pointers (UB) | **Done** — caller buffers + `agi_helpers` unit tests |
| 2 | **pbx3cagi** | `outboundClip` / `CFCheck` / Voicemail buffer overflows | **Done** — `strlcpy`/`snprintf`/`strlcat` sized scratch |
| 3 | **pbx3cagi** | Fail closed on default sys/spy pass (`4444`/`3333`) | **Done** — AGI + golden desk (`CHANSPY_LAB.md`); ChanSpy shortuid fix |
| 4 | **pbx3api** | CosClose / CosOpen cluster scope | **Done** — EnforcesClusterScope + Feature tests |
| 5 | **pbx3api** | Destinations require cluster + clamp | **Done** — require `?cluster=` + scope assert |
| 6 | **pbx3api** | Hide secrets in JSON (`Trunk`/`Tenant`/`Agent`) | **Done** — `$hidden`; SPA tenant spy/sys = password inputs |
| 7 | **pbx3api** | Restrict twin AstDB AMI writes | **Done** — `dbputTwin`/`dbdelTwin` + ability ACL |
| 8 | **pbx3** | Dumper SQL escape + falsy column skip | **Done** — `sql_escape` + include `0`/`''`; `dumper-escape-test.php` |
| 9 | **pbx3** | GenClass `appl.cluster` use shortuid | **Done** — query by shortuid; `genclass-appl-cluster-test.php` |
| 10 | **pbx3sbc** | Bind MI/metrics to localhost (not `0.0.0.0:8888`) | **Done** — `httpd` ip `127.0.0.1`; UFW 8888 rule removed; `mi-localhost-bind-test.sh` |
| 11 | **pbx3sbc** | Escape / parameterize SIP→SQL concat | **Done** — `{s.escape.common}` on free-form fields (door-knock/Slice D/failed_registrations); shortuid charset gate kept; `sql-escape-contract-test.sh` |
| 12 | **pbx3sbc-admin** | Lock Filament edits on fleet-owned `dr_rules` | **Done** — `DrRulePolicy` (update/delete deny when `FleetDidProjector::isFleetOwned`) + table row actions gated; `DrRulePolicyTest` |
| 13 | **pbx3sbc-admin** | Surface MI reload failure (don’t claim ok) | **Done** — `OpenSIPSMIService` reload methods return bool; Filament afterSave/delete + fleet API (`FleetSbcController`) surface warning/`ok:false`/502 on MI failure; `OpenSIPSMIServiceReloadTest` |
| 14 | **pbx3sbc-admin** | DB password off sudo argv | **Done** — `WhitelistSyncService::sync` writes a private mode-0600 MySQL `--defaults-extra-file` instead of argv; paired `pbx3sbc/scripts/sync-fail2ban-whitelist.sh` updated; `WhitelistSyncServiceTest` |
| 15 | **pbx3spa** | Mask SIP password in extension UI | **Done** — password input + reveal after regen; `maskSipPassword.test.js` |
| 16 | **pbx3spa** | Fleet GK 401 clears stale token | **Done** — `gkFetch`/`parseJsonResponse` clears token; fleetGatekeeper tests |

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
