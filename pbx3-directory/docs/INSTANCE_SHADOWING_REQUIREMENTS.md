# Instance shadowing — requirements (SKU framing)

**Status:** **Framing locked (2026-07-21).** Implementation **parked** — rehearse on SBC edge HA first; apply the same mechanics to PBX instances when a customer SKU needs it.  
**Related:** **`SBC_HA_FAILOVER_REQUIREMENTS.md`** (mechanics + control-plane Manual/Auto); **`SBC_BACKUP_RESTORE_REQUIREMENTS.md`** / instance backup (warmth / DR); **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** (node→edge qualify — complementary); **`DESIGN_RULES.md`** Rule 1, Rule 9, Rule 13.

---

## Idea

Customers who want **minimum downtime** and will **pay for it** can run PBX instances **shadowed**: an active node plus a warm standby twin. Failover uses the **same Occam shape as SBC edge HA** — not a second architecture.

| | **SBC edge HA** | **Instance shadowing** |
|--|-----------------|-------------------------|
| Pair | Active + warm standby | Same |
| Stable identity | VIP/EIP (phones, carriers) | Instance VIP / FQDN (phones, SBC dispatcher target) |
| Warmth | Catalog project + edge-authored sync | Catalog/S3 HoR + backup / sync cadence (instances already have more HoR) |
| Promote | Fence → move address → re-REGISTER / LE as needed | Same control-plane Manual / Auto + break-glass Console |
| Soft state | Mid-call / usrloc lost — OK | Channels / local soft state lost — OK |
| Who pays | Fleet ops | Customer SKU (“minimum downtime”) |

**Not** 999-grade / emergency-services RTO. Mid-call loss and minutes of re-registration are honest. Directory/control stays **off the call path** (Rule 1).

---

## Locked framing

| Decision | Choice |
|----------|--------|
| **Mechanism** | Reuse SBC HA: warm twin + move stable address; control-plane probe/alert; **Manual** (human promote) or **Auto** (control promotes) |
| **Product** | Optional **paid SKU** for customers who want that SLA — not default for every node |
| **Cold DR** | Instance backup/restore remains box-loss rebuild — shadowing ≠ “restore zip as failover” |
| **Implementation order** | Prove and operate **SBC edge HA** (including lab Magrathea partner when ready) → then instance shadow pairs |
| **Still out until SKU ships** | Auto-billing, self-serve twin provision UI, usrloc/channel sync |

---

## Complements (do not confuse)

| Leg | Doc |
|-----|-----|
| Edge box death | **`SBC_HA_FAILOVER_REQUIREMENTS.md`** |
| Carrier path failover | Peering `DR_FAILOVER` |
| Node → edge visibility | **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** |
| This file | Pay-for warm **PBX** twin |

---

*Last updated: 2026-07-21 — framing lock from SBC HA analogy (paid shadow SKU).*
