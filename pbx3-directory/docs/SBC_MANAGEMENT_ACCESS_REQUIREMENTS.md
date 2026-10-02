# SBC management access (Filament lockdown) — requirements

**Status:** **Done / shipped 2026-09-26** (v1). Tips: **pbx3sbc-admin `c772714`** · **pbx3sbc `8690a16`** (+ cloud SBC tip + php-fpm `ReadWritePaths=/etc/ufw`).  
**Audience:** SBC / Filament / ops.  
**Related:** Fail2ban Filament pages (reactive) · home **`UFW_SHOREWALL_MIGRATION.md`** (different product job) · **`EDGE_PORTABILITY_SCORECARD.md`** · **`SBC_PRODUCT_TRACKS.md`** · **`DESIGN_RULES.md`** Rule **7** (edge portability) · SBC TOTP (**`TOTP_2FA_SBC.md`**) · sibling **Provision access** draft (**`SBC_PROVISION_ACCESS_REQUIREMENTS.md`** — edge `:41363`).

**Naming:** **SBC** = edge. Do not hard-require AWS Security Groups as the product firewall.

---

## Problem

Admin HTTPS (**443**) is often open to the world on lab/cloud SBC images. Filament already has **UID/password** + optional **TOTP 2FA**, and **Fail2ban** (reactive bans + ignoreip). None of those **restrict who may open the admin UI** before login.

Operators want a **browser-visible allowlist** for Filament reachability. Some fleets run the SBC on **AWS**; others on bare metal / colo — product must not assume Security Groups for this feature.

---

## Locked stance (v1)

1. **Product SoT = host UFW** for **admin HTTPS (443) only**. Portable everywhere the SBC image runs.  
2. **SSH (22)** is **out of product** for v1 — operators use AWS SG / customer edge firewall / host UFW by hand. Panel may note this; no SSH toggle.  
3. **SIP / RTP / WSS** are **out of scope**. Domain checking + Fail2ban remain the edge signaling defenses. Do not put those ports behind this allowlist.  
4. **UX = dedicated Filament panel** — **System → Management access** (not a clone of the home Firewall table; not folded into Fail2ban whitelist).  
5. **Defense in depth:** network allowlist (optional lockdown) **then** password **then** 2FA. This panel does not replace auth.  
6. **Default:** lockdown **off** (world can reach 443, same as today). Operators turn on when ready.  
7. **Break-glass:** on lockdown Apply, **always keep the current client IP** (auto-add `/32` or `/128` if missing) and say so in the result message; refuse enabling lockdown with an **empty** allow list after that step; refuse deleting the last CIDR while lockdown is on. Document AWS console / serial recovery. No confirm checkbox.  
8. **Rule 7:** no AWS API hardwiring in Filament for the core feature. Optional SG sync adapter is **parked**.  
9. **Fail2ban stays** separate (reactive). Management allowlist is pre-connect; Fail2ban whitelist is post-abuse ignoreip.
10. **php-fpm ProtectSystem=full:** Ubuntu’s php-fpm unit mounts `/etc` read-only for the service **and** `sudo` children. Mutating UFW from Filament requires systemd **`ReadWritePaths=/etc/ufw`** (`pbx3sbc/scripts/setup-php-fpm-ufw-write.sh`). Status (`--status`) stays read-only and must not require write.

### Existential difference vs instance Firewall

| | Instance Firewall | SBC Management access |
|--|-------------------|------------------------|
| **Job** | PBX host service posture (SIP/RTP + ops ports) | Who may reach Filament |
| **Shape** | General proto/port/source rows | Lockdown + CIDR allow list for **443** |
| **Sibling defenses** | UFW is primary for fleet SIP-from-SBC | Auth + 2FA + F2B + (ops) SG for SSH |

---

## Desired UX (v1)

Filament **System → Management access**:

- Toggle: **Restrict admin HTTPS** (lockdown).  
- CIDR list + comment; **Add my IP**.  
- **Apply** → write state + run UFW helper (sudo); show last apply / effective rules (mgmt-tagged only).  
- Clear copy: *Phones and carriers are unaffected. Password and 2FA still apply. SSH is not managed here.*

---

## Non-goals (v1)

- Full generic firewall GUI.  
- SSH lockdown in-panel.  
- Replacing Fail2ban.  
- Requiring IAM / AWS credentials on the SBC.  
- HA apply-both (park until HA productized).

---

## Open / parked

- [ ] Optional cloud SG sync adapter (lab only).  
- [ ] HA pair: apply on active only vs both members.  
- [ ] SSH toggle for colo/bare-metal (if demand).

*Last updated: 2026-09-26 (shipped)*
