# First out — checklist (must-fix vs nice)

**Status:** Operator lean (**2026-08-06**; duplex won't-do **2026-08-11**) — product is **mostly there**; this is cleanup triage, not a new build plan.  
**Related:** **`TODO.md`** · **`STAKEHOLDER_DEMO_SCRIPT.md`** · **`TRACK_B_RELEASE_HARDENING.md`** · **`PROVISIONING_SERVER_REQUIREMENTS.md`** (parked, §0 / §0.1) · Device lean in **`sqlite_device_data.sql`** + **`sqlite_device_lean_prune.sql`**.

**First out** here means: a credible fleet PBX you can show / soft-land with a friendly customer — not OSS org polish, not HA SKUs, not a provisioning-server product.

---

## Already in (core story)

Treat as **done on `main` / lab-proven** unless a regression appears:

| Area | Notes |
|------|--------|
| Fleet catalog + Instances / Tenants | Create, Delete (D1–D5), naming lock |
| Site Groups / short dial | C0–C6 + Path 1 lab green |
| Day-parts / time-based routing | On `main`; golden path |
| Number wire Phase 1 | D1 = C; node Mangle |
| DNS / LE fleet lock | Tenant = SIP domain only; instance LE; SPA warn |
| SBC-fronted desk + WebRTC lab | Same-AZ proven; WSS line test |
| Ops notify / log retention / SBC aging | Shipped tracks |
| Packages | **pbx3 0.0.5-1** / **cagi 1.0.0-14** artefacts on `main` |
| Privileges | Instance P1–P4 + B′ login homing |
| Device templates (lean) | Seed **11** keepers only; SPA **Devices** nav removed (`main`) — create-time `sipiaxfriend` still via Device table |
| Provisioning server | **Parked** — lean don’t build; vendor/reseller RPS (M1). Spec only |

---

## Cleanup landed this pass (not first-out blockers)

| Item | Where |
|------|--------|
| Provisioning product question + M1–M5 options | **`PROVISIONING_SERVER_REQUIREMENTS.md`** |
| First-out triage (this file) | **`FIRST_OUT_CHECKLIST.md`** |
| Private migrate ETL stays under Aelintra (**done**) | **`TODO.md`** · **`REPOS_AND_RELEASES.md`** · **`OPEN_SOURCE_GITHUB_SETUP.md`** |
| Device seed lean + prune SQL; Devices off System nav | pbx3 `sqlite_device_*` · pbx3spa `AppLayout` |

**Existing lab DBs** still hold fat Device rows until **`sqlite_device_lean_prune.sql`** is run (seed alone does not shrink them).

---

## Must-fix / must-do (before calling first out “shipped”)

Ops and honesty gates — small list:

| # | Item | Why |
|---|------|-----|
| **F1** | Install **0.0.5-1** + **1.0.0-14** on fleet nodes (or greenfield instance) | Lab still on older debs; “what we ship” ≠ “what’s running” until this |
| **F2** | Deploy **API + SPA tip** (Certificates Sync instance-only + fleet DNS warn) | Avoid operator recreating tenant A / wrong Sync |
| **F3** | Smoke the **stakeholder demo path** on HTTPS against current golden/bzy | Regressions only — **`STAKEHOLDER_DEMO_SCRIPT.md`** |
| **F4** | Confirm **no tenant public A** leftovers; phones → SBC; SPA → instance | Fleet DNS lock is policy + lab; re-check before external eyes |
| **F5** | **Lab / demo DB anonymize** if anyone outside the closed lab sees screens / dumps | Real-site surnames still on golden — do before wider demo |
| **F6** | Optional but tidy: run **`sqlite_device_lean_prune.sql`** on golden/bzy | Align running DB with lean seed; drop surplus Device template fat |
| **F7** | **Pre-release safety debt** — **`PRE_RELEASE_SAFETY_DEBT.md`** | Go/no-go before calling a release: cagi buffers, api tenant IDOR, dumper/appl, edge MI/SQL, Filament fleet-owned, spa secrets |
| **F8** | **Tenant delete integrity** — **`TENANT_DELETE_DATA_INTEGRITY.md`** · lab **`TENANT_WIPE_AND_EXT_LEN_LAB.md`** §1 | Wipe already cascades; close sibling dialalias / park / orphan gaps before release honesty |
| **F9** | **`ext_len` enforce** — **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** §3.8 · lab **`TENANT_WIPE_AND_EXT_LEN_LAB.md`** §2 | Digit-plan length namespaces; tip-deploy then run §2 |

Not new product features — **rollout + hygiene + safety**.

---

## Should (nice before first out — schedule if time)

Worth doing if a soft-land or public-ish demo is soon; not architecture:

| # | Item | Why |
|---|------|-----|
| **N1** | **SPA production bundle diet** | Explicit pre-first-release TODO; lab OK, prod Pages chunk fat |
| **N2** | **Pages + CORS** for production SPA origin | If first out ≠ `npm run dev` |
| **N3** | **Fleet instance health includes Asterisk** | `/up` alone lies; embarrassing in a live Fleet view |
| **N4** | **SPA session timeout** honour `globals.sessiontimout` | Small trust/UX gap |
| **N5** | Magrathea gwid **dialect** / Twilio crumb if that carrier story is in the pitch | Only if demo script needs it |
| **N6** | Quick pass: inbound **SWOCLIP** create/edit parity; Extension **Runtime** with a live phone | Panel honesty on demo path |
| **N7** | Drop Devices **routes/views** entirely (nav already gone) | Finish hiding the unused admin surface |

---

## Explicitly not first out (parked)

Do **not** block first out on these:

- Provisioning **server** product — **`PROVISIONING_SERVER_REQUIREMENTS.md`** §0 lean **M1** (vendor/reseller RPS); §0.1 M2–M5 if ever resumed  
- Multi-AZ lab proof (production confidence later; same-AZ is enough for first out)  
- ~~Control-plane HA / duplex~~ — **won't-do** (2026-08-11): management binary; Rule 11 — **`CONTROL_HOST.md`**  
- Instance shadowing / S10.7 orchestrated rebuild  
- Fleet cookie/SSO  
- TOTP 2FA (SPA + SBC) — **`TOTP_2FA_REQUIREMENTS.md`**  

- Number wire Phase 2 / SBC dialect habit  
- ~~Velocity standalone~~ — **won't-do** (2026-08-11) — in-tree only · AMI wallboard / Grafana / door-knock heat  
- cagi Phase 4 / Ast generator deep refactor  
- S7+ PCI  
- **OSS org transfer** — private migrate ETL already extracted (**not** first-out)  
- Device → packaged JSON (optional later; keep lean SQLite for now)  
- SPA list icon component / help-row prune (polish)  
- `ipphone.desc` vs `description` rename  

---

## Suggested order when you pick up cleanup

1. **F1–F4** (install + tip + smoke + DNS check)  
2. **F7–F9** tip-deploy safety / wipe / ext_len lab (**`TENANT_WIPE_AND_EXT_LEN_LAB.md`**) when rolling those tips  
3. **F6** when touching golden DB anyway; **F5** if external demo  
4. **N1–N2** if shipping Pages SPA  
5. **N3–N7** as crumbs  
6. Everything in “not first out” stays parked  

---

## Open judgment (operator)

Flip these when you resume — not locked here:

- Is first out **closed lab + friendly MSP** only, or **Pages SPA + anonymized demo**? (drives F5 / N1–N2)  
- Is **Asterisk-aware Fleet health (N3)** a soft-land must, or post-first-out?  
