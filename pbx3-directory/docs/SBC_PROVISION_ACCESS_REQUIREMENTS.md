# SBC provision access (edge :41363 allowlist) — requirements

**Status:** Design **accepted 2026-10-02** — not built. Mirror polish of **Management access** (shipped). Allowlist on **one port** (`:41363`) — not a full firewall GUI.  
**Audience:** SBC / Filament / ops / security-aware fleet customers.  
**Related:** **`SBC_MANAGEMENT_ACCESS_REQUIREMENTS.md`** (admin :443) · **`PROVISIONING_SERVER_REQUIREMENTS.md` §8** (mTLS primary remote harden) · **`PROVISION_EDGE_PROXY.md`** · **`EDGE_PORTABILITY_SCORECARD.md`** · **`DESIGN_RULES.md`** Rule **7**.

**Naming:** **SBC** = edge. Product SoT = **host UFW** (portable). Do not hard-require AWS Security Groups.

---

## Problem

Fleet phone provisioning terminates on the edge at **`provision.{apex}:41363`** (HTTPS). Homes keep `:41363` **SBC-only**. The edge port is intentionally **phone-facing** for RPS.

Defense today (locked / in flight):

| Layer | Role |
|-------|------|
| Vendor **mTLS** (C5) | Client cert chains to phone-vendor CA — family proof, not site perimeter |
| MAC map + fail-closed | Unknown MAC → 404 |
| `sndcreds` Once/Always/No | Secret emission |
| Home UFW | Edge→home only |

None of those **restrict which public IPs may open a TCP session to provision :41363**. Security-aware customers often want: *only our office / site egress CIDRs may fetch configs*.

SBC **Management access** already gives a polished Filament lockdown for **admin :443**. Provision needs the **same product shape** for **:41363** — not a full firewall GUI, not SIP/RTP.

---

## Locked stance (v1 design)

1. **Product SoT = host UFW** for **provision HTTPS (`41363/tcp`) only**. Same portability story as Management access.  
2. **UX = dedicated Filament panel** — **System → Provision access** (sibling to **Management access**; not folded into Fail2ban; not a clone of home Firewall).  
3. **Default: lockdown off** — world can reach `:41363` (today’s RPS-friendly behaviour). Operators enable when ready.  
4. **Defense in depth:** optional IP allowlist **then** mTLS (when CA present) **then** MAC map **then** `sndcreds`. This panel does not replace mTLS.  
5. **Scope = edge-global** for v1 — one CIDR list on the SBC for all tenants. Per-tenant allowlists need MAC→tenant→CIDR at nginx (parked).  
6. **SIP / RTP / WSS / admin :443** out of scope here. Admin stays on Management access; signaling stays domain check + Fail2ban.  
7. **Break-glass (same pattern as Management access):** on lockdown Apply, **always keep the current client IP** (auto-add `/32` or `/128` if missing) and say so; refuse enabling lockdown with an **empty** allow list after that step; refuse deleting the last CIDR while lockdown is on. Document AWS console / serial recovery.  
8. **Rule 7:** no AWS API hardwiring in Filament for the core feature. Optional SG sync adapter **parked**.  
9. **Fail2ban stays** separate (reactive). Provision allowlist is pre-connect.  
10. **php-fpm UFW write:** reuse the same **`ReadWritePaths=/etc/ufw`** setup as Management access.  
11. **Solo / direct home:** out of scope — operators use **instance Firewall** for home `:41363`. This panel is **fleet edge only**.

### Existential difference vs siblings

| | Management access | Provision access (this) | Instance Firewall |
|--|-------------------|-------------------------|-------------------|
| **Job** | Who may reach Filament | Who may reach provision `:41363` | Home service posture |
| **Port** | **443/tcp** | **41363/tcp** | Many |
| **Default** | Lockdown off | Lockdown off | Install baseline |
| **Sibling defenses** | Password + 2FA + F2B | mTLS + MAC map + Once | SBC-only SIP/provision on fleet |

---

## Desired UX (v1)

Filament **System → Provision access**:

- Toggle: **Restrict provision HTTPS** (lockdown on `:41363`).  
- CIDR list + comment; **Add my IP**.  
- **Apply** → write state + UFW helper (provision-tagged rules only); show last apply / effective rules.  
- Clear copy:
  - *Only TCP 41363 (phone provisioning). SIP, RTP, WSS, and admin HTTPS are unaffected.*
  - *Vendor client certificates (mTLS) still apply when configured.*
  - *Phones must egress from an allowed CIDR — WFH / mobile / multi-site need those CIDRs listed or lockdown left off.*
  - *RPS only discovers the URL; the phone (or its site NAT) opens the HTTPS session — allowlist the phone’s public egress, not “the vendor cloud” unless your RPS mode actually fetches from a cloud IP.*

### Suggested empty / off state help

> Leave lockdown **off** for mixed WFH fleets or unknown egress. Turn **on** for hard sites with stable office egress (and list every site CIDR). Combine with mTLS for defense in depth.

---

## State / apply (implementation sketch)

Mirror Management access storage shape (exact paths chosen at build):

| Piece | Intent |
|-------|--------|
| State file | e.g. `/etc/pbx3sbc/provision-access.json` — `{ "lockdown": bool, "cidrs": [ { "cidr", "comment" } ] }` |
| UFW tags | Comment prefix e.g. `pbx3-prov-access` so Apply can replace only provision rules |
| When lockdown **off** | Remove tagged `:41363` allows; ensure baseline **allow 41363/tcp from anywhere** (or equivalent open) so RPS keeps working — document exact baseline interaction with install UFW |
| When lockdown **on** | Deny world; **allow 41363/tcp from each CIDR** (tagged) |
| HA | Park — apply on this host; pair sync later (same as Management access) |

**Open at build:** whether install currently opens `41363` as `any` via UFW vs SG-only — Apply must leave a known-good open path when lockdown is off.

---

## Non-goals (v1)

- Full generic firewall GUI.  
- Per-tenant / per-MAC CIDR maps.  
- SIP / RTP / WSS / SSH in this panel.  
- Replacing mTLS or Fail2ban.  
- Requiring IAM / AWS credentials on the SBC.  
- HA apply-both.  
- Solo home provision lockdown (use instance Firewall).

---

## Risks / operator footguns

| Risk | Mitigation |
|------|------------|
| Lockdown on + WFH phone | Document; leave off or add home egress CIDRs |
| Lockdown on + forgot multi-site | Multi-CIDR list; comments per site |
| Lockout of operator laptop while toggling | Auto-add current client IP on Apply (even though laptop ≠ phone — ops still need panel access… **wait**) |

**Panel access vs phone access:** Filament is on **:443**, provision lockdown is **:41363**. Enabling provision lockdown does **not** lock the operator out of Filament. Break-glass “add my IP” still helps when testing provision from the same laptop (`curl` / phone on same NAT). Keep the Management-access-style auto-add for consistency when the client will also hit `:41363`.

| Lockout of all phones | Refuse empty list; loud SPA copy; recovery via AWS/serial / disable lockdown in state file + re-apply helper |
| Cloud SG still open | Product UFW is portable SoT; ops may still mirror in SG (document; no AWS hardwiring) |

---

## Relationship to mTLS (C5)

| Mode | Intent |
|------|--------|
| Lockdown **off** + mTLS | Typical cloud RPS default once CAs installed |
| Lockdown **on** + mTLS | Hard site: perimeter + vendor family |
| Lockdown **on** without mTLS | Better than MAC-only open internet; still weaker than mTLS — document as interim |
| Lockdown **off** without mTLS | Lab / interim only — §8 already calls this a hard sell |

---

## Acceptance sketch

- [ ] Lockdown off → phone/RPS from arbitrary IP can reach `:41363` (subject to mTLS/MAC as configured)  
- [ ] Lockdown on + listed site CIDR → GET from that egress succeeds; from other public IP → TCP refused / filtered before nginx  
- [ ] SIP REGISTER / admin :443 unchanged when provision lockdown toggled  
- [ ] Empty allow list cannot enable lockdown; cannot delete last CIDR while on  
- [ ] Apply shows effective UFW rules tagged for provision  
- [ ] Solo home unaffected (no this panel / no change to instance Firewall contract)  
- [ ] MkDocs: when to use; WFH warning; complements mTLS  

---

## Open / parked

- [ ] Per-tenant CIDR allowlists (nginx/MAC-aware) — only if fleet-global proves insufficient  
- [ ] Optional cloud SG sync adapter  
- [ ] HA pair apply  
- [ ] Baseline UFW vs SG ownership on current lab images (freeze at implement)  
- [ ] Exact Filament nav label (**Provision access** vs **Provisioning access**)

---

## Schedule

Not on critical path for rehome soak / C5. Natural follow-on after **C5 mTLS** (or parallel if a customer blocks on perimeter before certs). Plan slice: provision track **C10** (or SBC admin sibling of Management access).

*Last updated: 2026-10-02 (design accepted — allowlist, not full FW)*
