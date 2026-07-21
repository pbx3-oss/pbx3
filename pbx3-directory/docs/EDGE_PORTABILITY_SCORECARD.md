# Edge portability scorecard

**Status:** Snapshot **2026-07-20** (design session). Not a project plan — debt inventory against **`DESIGN_RULES.md`** Rule **7**.  
**Related:** Rule 8, Rule 13; **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.4 (`SbcFleetAdapter`); gatekeeper **`SbcFleetClient.php`**.

---

## Verdict

| Dimension | Grade |
|-----------|--------|
| **Control-plane structure** (gatekeeper ≠ Filament; SIP runtime; S3 HoR) | **GREEN** |
| **Adapter methods shipped** (repoint, DID project, provision, preflight) | **AMBER** — works, but OpenSIPS-shaped |
| **Catalog / SPA / public API vocabulary** | **RED** — `dispatcher` / `setid` leak past the adapter |

**Swapping** to customer OpenSIPS, dSIPRouter, or TelcoBridges is **new adapter + projector**, not a config flip. **Nodes and catalog HoR survive**; **Filament + our SBC DR/HA/aging tooling do not.**

### Preferred escape hatch (locked 2026-07-20)

**Peer (or cascade), don’t replace.** Same posture as Magrathea: a commercial SBC is another SIP upstream/downstream peer on **our** edge (`dr_gateways` / routes). Keep pbx3sbc as phone/node registrar and fleet projection target. Full BYO-edge (second `SbcFleetAdapter` binding) only if a customer requires **our** OpenSIPS off the phone path — rarer, and not a vocabulary-rename project.

Organic OpenSIPS nouns (`setid`, dispatcher) stay acceptable while we are the edge; they name our box correctly under the peer model.

---

## Adapter contract vs shipment

| Method (Rule 7 ideal) | Intent | Status | Leak | Grade |
|----------------------|--------|--------|------|-------|
| `preflight` | Dest backend healthy; domain exists | Shipped | `dest_dispatcher_setid` | AMBER |
| `repointTenant` | Tenant domain → dest backend | Shipped | `dest_dispatcher_setid` / `previous_setid` | AMBER |
| `rollbackRepoint` | Undo cutover | Shipped | setid vocabulary | AMBER |
| `registerNode` / `provisionNode` | Backend pool + peer for a node | Shipped | Dispatcher + Asterisk Peer shaped | AMBER |
| `projectTenantDids` | DID delivery → tenant/backend | Shipped | First impl → `dr_rules` | AMBER |
| `health` | Edge reachable | Partial | Not a clean adapter `health()` | AMBER |
| Live inventory helpers | Guard catalog against invented pools | Shipped as `listDispatcherSets` | Returns **`setid`** | RED |

Gatekeeper talks only to **`/api/fleet/*`** on pbx3sbc-admin — good seam. Types and field names still say OpenSIPS.

---

## Vocabulary leaks

| Where | Today | Portable ideal | Grade |
|-------|--------|----------------|-------|
| Catalog / instance-index | `sbc_dispatcher_setid` | Opaque `edge_backend_pool_id` | RED |
| Move jobs | `dest_sbc_dispatcher_setid`, `previous_*` | Opaque pool ids | RED |
| Gatekeeper API | `GET /api/v1/sbc/dispatcher-sets` | `…/edge/backend-pools` | RED |
| SPA Fleet Instances | “dispatcher setid”, Link setid | “Edge backend pool” | RED |
| Client PHPDoc | “project … `dr_rules`” | Intent only; schema inside adapter | AMBER |
| Ops notify | default jail `opensips-brute-force` | Edge-reported event type | AMBER |
| DID catalog facts | e164, tenant, sip_prefix | Already mostly neutral | GREEN |
| Node `Egress` | SIP URI to VIP/FQDN | Portable | GREEN |
| Control plane hosting | Not inside `pbx3sbc-admin` | Rule 7 anti-pattern avoided | GREEN |

---

## Keep / lose on edge swap

| Layer | Keep? | Lose / rebuild |
|-------|-------|----------------|
| Fleet nodes + `Egress` | Yes (SIP) | Nothing material |
| S3 catalog HoR | Yes | Migrate/rename setid fields if cleaning debt |
| Move orchestration | Yes | Cutover needs new adapter binding |
| Fleet SPA shell / auth | Yes | Copy + pool pickers until renamed |
| pbx3sbc-admin Filament | No | Peers, Fail2ban, aging, aliases UX |
| SBC backup / HA / aging scripts | No | OpenSIPS/MariaDB-specific |
| Lab SIP hardening | Knowledge only | Re-validate on new stack |

---

## Second-adapter effort (rough)

| Work | Effort | Notes |
|------|--------|-------|
| Implement adapter against vendor API | M–L | dSIPRouter REST / TB provisioning |
| Map opaque pool id ↔ their backend group | M | Or accept setid as alias forever |
| DID projector → vendor objects | M | Not `dr_rules` |
| Optional catalog/SPA rename | S–M | Clears RED vocabulary |
| Drop Filament for that customer | — | Expected |
| Lab-prove second binding | L | Until then Rule 7 is **intent**, not product option |

---

## Debt reduction (only on product ask)

Do **not** rename the world until a customer/trigger needs a second edge. If/when:

1. Opaque `edge_backend_pool_id` in catalog + jobs + SPA.  
2. OpenSIPS mapping **only** inside pbx3sbc-admin adapter.  
3. Second lab binding before marketing “bring your own SBC.”

Revisit triggers remain in **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.4.

---

*Last updated: 2026-07-20.*
