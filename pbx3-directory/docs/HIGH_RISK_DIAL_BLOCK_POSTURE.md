# High-risk dial block — posture (locked 2026-08-11)

**Status:** Locked.  
**Related:** **`VELOCITY_PREFIX_SEEDS.md`** · **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`** · research §7 (ops) · CoS GenAst.

## Decision

| Layer | Owns | Scope |
|-------|------|--------|
| **PBX CoS** | **Prevention HoR** — deny Asterisk patterns → congestion/Hangup | Per tenant; `defaultopen`/`defaultclosed=YES` so new phones inherit; SPA editable / removable |
| **Velocity** | **Detection + act** — CDR prefix surge → notify / `active=NO` | Same destination *set*, literal CDR prefixes (not `_` patterns) |
| **SBC** | **No never-route floor in current plan** (deferred) | Sat/high-risk stay on **tenant CoS** so ops can open a paying satphone (etc.) per customer |
| **Carrier** | Backstop geo-bar / fraud desk | Not our HoR |

**Do not** put the full UK/US starter pack only on Magrathea — tenant exceptions, solo sites, and UK **`070`** (looks like mobile) belong on the **home**. Evolve packs (S3 / seeds) and **adopt per tenant** so one customer can be relaxed without a fleet SBC bite.

```text
Prevention (CoS deny patterns, seeded; per-tenant exceptions)
    → Detection (velocity on aligned prefixes)
        → Act (active=NO)
            ↔ Carrier fraud desk
```

(SBC hard refuse = deferred — see L4 in **`FLEET_TOLL_FRAUD_VELOCITY_IMPLEMENTATION_PLAN.md`**.)

## What “seeded CoS” looks like

Per tenant (locale pack):

| pkey | cname (example) | dialplan (Asterisk) | defaults |
|------|-----------------|---------------------|----------|
| **`HR_UK070`** | High risk — UK personal 070 | `_070. _+4470. _076. _+4476.` | open+closed YES (UK pack) |
| **`HR_OFFSHORE`** | High risk — offshore / IRSF | `_001268. _+1268. _00252. …` (UK `00`/`+`) or `_1268. _011252. …` (US) | open+closed YES |

SPA: **Class of Service** list shows these like any other rule (stable **`pkey`** + **cname** explain what they deny). Operator can clear `default*`, detach from phones, or edit patterns (liability unlock ≈ remove/narrow the rule). SPA-created custom rules omit operator key — API sets **`pkey = shortuid`**; seeds keep the `HR_*` names for upsert.

**Not** OutRoute / `default_outbound_dialplan` — that **allows** trunk seize (`_0XXX. _00XX.`); high-risk is a **deny** layer.

## Enable

| Knob | Meaning |
|------|---------|
| `PBX3_COS_HIGHRISK_SEED=true` | Seed on **new tenant create** |
| `PBX3_COS_HIGHRISK_LOCALE=uk\|us` | Which pack (default **`uk`**) |
| `php artisan pbx3:cos-highrisk-seed --tenant=…` | Backfill one tenant |
| `php artisan pbx3:cos-highrisk-seed --all` | Backfill all tenants |

Pattern sources: `pbx3api/config/cos/highrisk-*-starter.dialplan` (keep aligned with velocity prefix seeds).

## SBC never-route (optional — **deferred 2026-08-11**)

Previously floated as a hard refuse for a **short** list (e.g. satellite `870`/`881`/`882`/`883`, Ascension `247`). **Not building now:** customers may need satphone (and will pay); blocking at **tenant CoS** lets ops **open that tenant** on request. Fleet-wide SBC refuse is a poor exception model. Velocity/CoS policy can still use S3 store-and-forward without duplicating a refuse list on the edge. Revisit only for a true no-exception fleet floor. See **`FLEET_TOLL_FRAUD_VELOCITY_IMPLEMENTATION_PLAN.md`** L4.

## Lab

Default seed **off** (`PBX3_COS_HIGHRISK_SEED` unset/false) so fixture / SIPp labs are not surprised. Golden/Toliman: enable + locale when proving prevention.
