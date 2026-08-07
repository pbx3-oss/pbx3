# First out — checklist (must-fix vs nice)

**Status:** Operator lean (**2026-08-06**) — product is **mostly there**; this is cleanup triage, not a new build plan.  
**Related:** **`TODO.md`** · **`STAKEHOLDER_DEMO_SCRIPT.md`** · **`TRACK_B_RELEASE_HARDENING.md`** · **`PROVISIONING_SERVER_REQUIREMENTS.md`** (parked).

**First out** here means: a credible fleet PBX you can show / soft-land with a friendly customer — not OSS org polish, not HA SKUs, not provisioning-server product.

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

Not code features — **rollout + hygiene**.

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

---

## Explicitly not first out (parked)

Do **not** block first out on these:

- Provisioning **server** product (M1 lean — vendor/reseller RPS)  
- Multi-AZ lab proof (production confidence later; same-AZ is enough for first out)  
- Control-plane HA / duplex  
- Instance shadowing / S10.7 orchestrated rebuild  
- Fleet cookie/SSO  
- Number wire Phase 2 / SBC dialect habit  
- Velocity standalone / AMI wallboard / Grafana / door-knock heat  
- cagi Phase 4 / Ast generator deep refactor  
- S7+ PCI / OSS org transfer  
- **SARK migration extract to Aelintra repo** (required **before** OSS org move; not first-out)  
- **Device templates** — seed leaned to 11 rows + nav removed; residual prune/routes/JSON optional  
- SPA list icon component / help-row prune (polish)  
- `ipphone.desc` vs `description` rename  

---

## Suggested order when you pick up cleanup

1. **F1–F4** (install + tip + smoke + DNS check)  
2. **F5** if external demo  
3. **N1–N2** if shipping Pages SPA  
4. **N3–N6** as crumbs  
5. Everything in “not first out” stays parked  

---

## Open judgment (operator)

Flip these when you resume — not locked here:

- Is first out **closed lab + friendly MSP** only, or **Pages SPA + anonymized demo**? (drives F5 / N1–N2)  
- Is **Asterisk-aware Fleet health (N3)** a soft-land must, or post-first-out?  
