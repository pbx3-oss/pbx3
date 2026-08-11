# High-risk dial block — posture (locked 2026-08-11)

**Status:** Locked.  
**Related:** **`VELOCITY_PREFIX_SEEDS.md`** · **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`** · research §7 (ops) · CoS GenAst.

## Decision

| Layer | Owns | Scope |
|-------|------|--------|
| **PBX CoS** | **Prevention HoR** — deny Asterisk patterns → congestion/Hangup | Per tenant; `defaultopen`/`defaultclosed=YES` so new phones inherit; SPA editable / removable |
| **Velocity** | **Detection + act** — CDR prefix surge → notify / `active=NO` | Same destination *set*, literal CDR prefixes (not `_` patterns) |
| **SBC** | **Optional thin never-route floor** only | Fleet-wide sat / junk CCs — **not** the full offshore pack |
| **Carrier** | Backstop geo-bar / fraud desk | Not our HoR |

**Do not** put the full UK/US starter pack only on Magrathea — tenant exceptions, solo sites, and UK **`070`** (looks like mobile) belong on the **home**.

```text
Prevention (CoS deny patterns, seeded)
    → Detection (velocity on aligned prefixes)
        → Act (active=NO)
            ↔ Optional SBC hard refuse (tiny never-route tier)
                ↔ Carrier fraud desk
```

## What “seeded CoS” looks like

Per tenant (locale pack):

| pkey | cname (example) | dialplan (Asterisk) | defaults |
|------|-----------------|---------------------|----------|
| **`HR_UK070`** | High risk — UK personal 070 | `_070. _+4470. _076. _+4476.` | open+closed YES (UK pack) |
| **`HR_OFFSHORE`** | High risk — offshore / IRSF | `_001268. _+1268. _00252. …` (UK `00`/`+`) or `_1268. _011252. …` (US) | open+closed YES |

SPA: **Class of Service** list shows these like any other rule. Operator can clear `default*`, detach from phones, or edit patterns (liability unlock ≈ remove/narrow the rule).

**Not** OutRoute / `default_outbound_dialplan` — that **allows** trunk seize (`_0XXX. _00XX.`); high-risk is a **deny** layer.

## Enable

| Knob | Meaning |
|------|---------|
| `PBX3_COS_HIGHRISK_SEED=true` | Seed on **new tenant create** |
| `PBX3_COS_HIGHRISK_LOCALE=uk\|us` | Which pack (default **`uk`**) |
| `php artisan pbx3:cos-highrisk-seed --tenant=…` | Backfill one tenant |
| `php artisan pbx3:cos-highrisk-seed --all` | Backfill all tenants |

Pattern sources: `pbx3api/config/cos/highrisk-*-starter.dialplan` (keep aligned with velocity prefix seeds).

## SBC never-route (optional later)

Hard refuse only a **short** list, e.g. satellite `870`/`881`/`882`/`883`, Ascension `247`, when product wants a fleet floor no tenant can CoS-open. Full Caribbean/Africa stays **CoS**. Implement when scheduled — not blocking CoS seed.

## Lab

Default seed **off** (`PBX3_COS_HIGHRISK_SEED` unset/false) so fixture / SIPp labs are not surprised. Golden/Toliman: enable + locale when proving prevention.
