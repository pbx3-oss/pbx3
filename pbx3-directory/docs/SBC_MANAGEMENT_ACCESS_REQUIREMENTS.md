# SBC management access (firewall) — requirements stub

**Status:** Open work (not scheduled). Seeded **2026-08-30**.  
**Audience:** SBC / Filament / ops.  
**Related:** Fail2ban Filament pages (reactive) · home **`UFW_SHOREWALL_MIGRATION.md`** · **`EDGE_PORTABILITY_SCORECARD.md`** · **`SBC_PRODUCT_TRACKS.md`** · **`DESIGN_RULES.md`** Rule **7** (edge portability).

**Naming:** **SBC** = edge. Do not hard-require AWS Security Groups as the product firewall.

---

## Problem

SSH (**22**) and admin HTTPS (**443**) are often open to the world on lab/cloud SBC images. Filament already exposes **Fail2ban** (ban after abuse + ignoreip whitelist). That does **not** restrict who may connect to management ports.

Operators want a **browser-visible allowlist** for management access. Some fleets run the SBC on **AWS**; others on bare metal, other clouds, or customer colo — product must not assume Security Groups.

---

## Locked stance

1. **Product SoT = host firewall** (UFW or nftables wrapper — same family as home UFW track). Portable everywhere the SBC image runs.  
2. **AWS SG (or equivalent cloud SG) = optional ops overlay**, not the Filament dependency. Lab AWS may mirror allowlists into SG for defense in depth; non-AWS installs never need it.  
3. **Scope = management ports only** by default: **22** + **443** (and optional admin-only alt HTTPS if ever used). Do **not** put SIP **5060**, RTP, or WSS **8089** behind this allowlist — those stay carrier/phone-facing.  
4. **Fail2ban stays** for reactive bans on whatever remains reachable; management allowlist is a separate panel (“Management access”), not a rename of Fail2ban whitelist.  
5. **Break-glass:** never apply a change that drops the **current client IP** without an explicit confirm; refuse deleting the last CIDR while lockdown is enabled; document console / serial / physical access recovery for non-AWS.  
6. **Rule 7:** no AWS API hardwiring in the Filament domain path for the core feature. Optional “sync to SG” adapter later, behind capability detection.

---

## Desired UX (sketch)

Filament **System → Management access** (name TBD):

- Toggle: **Restrict SSH / Restrict HTTPS** (or one “lockdown” with per-port checkboxes).  
- CIDR list (desk, office, control host, …) + “Add my IP”.  
- Apply → write host firewall; show effective rules / last apply result.  
- Clear copy: phones and carriers are unaffected.

---

## Non-goals (v1)

- Full generic firewall GUI (arbitrary ports/chains).  
- Replacing Fail2ban.  
- Requiring IAM / AWS credentials on the SBC for the feature to work.

---

## Open

- [ ] UFW vs nftables on current Ubuntu SBC image (prefer align with home UFW).  
- [ ] Default on fresh install: open vs restricted-with-installer-seeded CIDR.  
- [ ] HA pair: apply on active only vs both members.  
- [ ] Optional cloud SG sync adapter (lab only).

*Last updated: 2026-08-30*
