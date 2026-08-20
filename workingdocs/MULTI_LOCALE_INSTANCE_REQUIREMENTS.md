# Multi-locale instance (cross-border desk) — requirements stub

**Status:** **§3.A** remains v1 desk / usual ops (instance one mangle). **Direction 2026-08-19 (§3.E):** product must **allow** mixed-nationality tenants on one instance so tenant move is not trapped by instance “national borders”; **usual ops** will still not mix carrier nationalities on a box. Hinge = **where mangle runs**. **§3.D** / **§9** (#5d) origin-table — **design accepted; parked past first candidate.** **§3.B** unhomed still not v1.  
**Lab persona / host:** operator lives in the **USA**, business / DIDs in the **UK** → US home **Toliman**; UK home = second identity/instance (lab L5).  
**Related:** [`NUMBER_WIRE_POLICY.md`](../pbx3-directory/docs/NUMBER_WIRE_POLICY.md) · [`NUMBER_DIALECT_REQUIREMENTS.md`](../pbx3-directory/docs/NUMBER_DIALECT_REQUIREMENTS.md) (§5.1 face grammar, §5.3–5.4 recipes) · [`EGRESS_PLUS_E164_WIRE.md`](EGRESS_PLUS_E164_WIRE.md)

## 1. Problem

One fleet **instance** can own DIDs and Peers in **more than one country**. Inbound is easy (SBC routes each carrier DID home). Outbound is hard:

- There is **one Egress** trunk instance → SBC.
- Egress **mangle** is a simple longest-prefix rewrite (one “serving locale” habit table). It **cannot** safely mean both UK national `0…` and US national/`1…` at once: shared seize digits (`0`) are ambiguous across countries.
- **USA (and similar strict CLIP-auth Peers):** the carrier rejects CLIP it has not authorised (lab: Twilio **403** on UK CLI). **Outside the USA (typical ITSP):** operators can often present CLIDs the carrier does not “know” in advance after a signed disclaimer — dest-based Peer pick is the product shape, not CLIP-auth per dest.
- Many handsets **cannot dial `+`**; users fall back to the **serving country’s IDD** (NANP `011…`, UK `00…`).

Persona: *I live in the USA; my business is in the UK.* Desk habit is US; UK numbers and Magrathea (etc.) still matter.

**Survival without new product (proved Toliman):** a **nationally homed** instance already works for cross-border — primary mangle + **IDD to the other CC** (`01144…` from US) + matching CLIP. No unhomed mode, no multi-Egress, no smart-route locale engine required. Everything below is posture choice / UX, not a go-live blocker.

## 2. What we already proved (Toliman lab, 2026-08-12)

| Attempt | Result | Lesson |
|---------|--------|--------|
| Dial UK mobile `07949943282` with US Egress `011:+ 1:+1` | FAIL — DNID left national; Brindley/Magrathea path congested | US mangle does not interpret UK seize `0` |
| CLIP only on Egress while ext still had `+1…` | FAIL — ext CLIP wins | Multi-identity must be on the **station** (or win over trunk) |
| Ext CLIP → UK `01924918076`, still dial `07…` | FAIL — CLIP OK on wire; DNID still wrong | CLIP ≠ DNID |
| Dial `011447949943282` (+ UK CLIP) | **OK** | Serving-locale **IDD** → `+E.164` is the cross-border dial path |

## 3. Direction

Two postures fit the persona. **§3.A is locked** (2026-08-19). **§3.B** is not v1 unless a later mandate reopens it.

### 3.A Locked — nationally homed instances + phone multi-identity

**Product lock 2026-08-19** (lean from 2026-08-12 lab operator): an instance is **nationally homed** (one primary serving locale / one Egress mangle). Cross-border desk = **two identities on the phone**, not two nationals on one mangle.

| Piece | UK instance | US instance |
|-------|-------------|-------------|
| Serving locale / mangle | `00:+ 0:+44` | `011:+ 1:+1` |
| DIDs / CLIP | UK | US |
| Peers | Magrathea / … | Twilio / … |
| What the human dials | UK national / `00…` | US national / `011…` |
| Phone | Identity A (reg to UK home) | Identity B (reg to US home) |

**Why this may be correct**

- Matches how multi-line phones already work (operator already runs multiple identities).
- One mangle stays honest; no `0:+44` on a US desk.
- CLIP is naturally right for the line in use (no dest-CC CLIP picker required for v1).
- Inbound is trivial per home; user hears the line that owns the DID.
- Keeps **Rule-shaped** “PBX = appliance for a locale”; fleet can still host both instances.

**Costs / open product questions**

- Two instances (or two tenants on two homes) to provision and bill.
- Directory / presence / “one company” UX across instances.
- User must place the call on the **right identity** (UK line vs US line) — same discipline as choosing CLIP, but at registration/line level.
- Mobility: moving only one identity’s home still works; the other stays put.

**Lab:** Toliman = US-homed identity; keep (or restore) a **UK-homed** instance/identity for UK national dial + UK CLIP — rather than teaching Toliman UK `0…`.

### 3.B Alternate — single multi-locale instance

One instance, one Egress, DIDs in several countries:

| Concern | Owner |
|---------|--------|
| Habit for **primary** locale only | Egress mangle |
| Other-country dial | **IDD** (or `+` when UA allows) → `+E.164` |
| CLIP | Extension/desk **multi-identity pool** (explicit line or later dest-CC auto) |
| Peer face | SBC dialect; Peer pick by dest after DNID is E.164 |

Still valid for “one PBX, many countries,” but fights the simple mangle and needs multi-CLIP product work. **Not product v1.** **Do not** “fix” by stuffing foreign seize rules into the primary mangle.

### 3.C Shared rules (either posture)

- **One Egress per instance** → SBC; SBC may still fan out to many Peers.
- PBX owns CLIP **value**; SBC owns carrier **format**.
- Store CLIP/DIDs as **`+CC…`** on the wire-facing fields where possible.
- Inbound stays “DID → home”; no directory in the call path.

### 3.D Locked — many Peers, dest-based pick; CLIP-auth is the USA exception

**Locked 2026-08-19** (ops): **Nationally homed ≠ one Peer.** A home (and the tenants on it) may use **several outbound Peers**. After the node has mangled to E.164 and seized **Egress**, the **SBC** chooses Peer by **dialled dest** (drouting prefix → gwid). Fleet Peers stay on the **edge** (`FLEET_TRUNK_PEERING_DECISION.md`); the node does not grow per-country Egress trunks.

| Region / Peer class | CLIP | Routing |
|---------------------|------|---------|
| **Typical non-US ITSP** (UK Magrathea / Gamma / …) | Carrier often accepts CLIDs it has not provisioned in advance; operator signs a **disclaimer**. Product may present the station CLIP as stored. | Several Peers **in the same outbound group**: **priority / failover** (Magrathea unless unavailable) and **dest-class** (e.g. `800` / freephone → Gamma, else Magrathea). OpenSIPS `dr_rules` prefix + `gwlist` / `use_next_gw` — not a fight with Twilio. |
| **USA / strict CLIP-auth** (Twilio lab) | CLIP must be an identity that Peer has authorised — unknown CLI → **403**. | Dest pick only **inside the US group**. Must **not** share the UK group’s prefix table (**§9 / #5d**). |

**UK example (in-group, not steal):** Magrathea first; Gamma on Magrathea fail **or** for a dest class (0800…). That is ordinary drouting inside `serving_cc=44`.

**Symmetric steal (global table):** a **UK-homed** user dials a **NANP** dest (`1…` / `011…`) → Twilio `prefix=1` wins, Magrathea never sees it (CLIP 403). A **US-homed** user dials a **UK** dest (`44…` / `01144…`) → Magrathea `prefix=44` wins, Twilio never sees it. Cross-border dest is **valid §3.A** (IDD from the serving locale). Peer must follow **origin home**, not dest CC. Split groups: UK group sends NANP → Magrathea; US group sends `44` → Twilio.

### 3.E Direction — mixed nationality capability; mangle is the bind

**Direction 2026-08-19 (not built):** We **need** to be able to place mixed-nationality tenants on one instance. In practice we will **usually not** mix **carrier** nationalities on a box (UK ITSPs on this home, Twilio-class on that one). Binding the **instance** to a national carrier set **blocks free tenant move** (UK tenant cannot move onto a “US carrier” box). Fleet move is catalog homing + SBC setid — carriers should not be baked into the Asterisk.

**Yes, it comes back to where mangle happens.**

| Where habit → E.164 lives | Mixed tenants on one box | Tenant move |
|---------------------------|--------------------------|-------------|
| **Instance Egress mangle (today)** | Share one seize table — UK `0…` vs US `1…` collide | Moving a tenant changes **habit** (and looks like a national border) |
| **Tenant mangle** (miniDB / per-tenant transform) | Each tenant keeps its seize table | Move takes mangle with the tenant |
| **SBC mangle from tenant `serving_cc`** (number-wire Phase 2) | Node passthrough; habit is catalog fact | Move = setid only; habit + origin Peer group follow the tenant |
| **No national mangle** (digit E.164 / IDD only) | Easy mix | Easy move; desk habit is the cost |

**Carriers** already belong on the SBC (`FLEET_TRUNK_PEERING_DECISION.md`). If #5d selects the outbound **group by tenant origin** (From domain), the instance is **not** nationally bound by Magrathea vs Twilio — only by **mangle** if mangle stays instance-wide.

**Carrier preselect (PSTN analogy).** Default **CPS** = tenant (or serving_cc) is pre-selected onto one outbound **group**; **every** E.164 from that tenant uses that group — **hidden from the caller** (call characteristic, not dialled digits). Call-by-call CPS = optional access prefix (strip, then dest) as ops/power-user only. Still one node **Egress**, SBC `dr_rules`. Origin intent, not dest-CC steal. Companion: **smarter mangle** (tenant/SBC habit) for §3.E — see [`ORIGIN_OUTBOUND_ROUTING_DESIGN.md`](ORIGIN_OUTBOUND_ROUTING_DESIGN.md).

**§3.A** stays the **usual ops / v1 desk** story (don’t mix on purpose; phone multi-identity for a human in two countries). **§3.E** is the **capability** so ops can mix tenants when they must, and so move is not a customs checkpoint. Do **not** stuff two nationals into one instance mangle mask.

## 4. Non-goals (this stub)

- Bilingual national mangle (UK `0` + US `1` as equal first-class habits on one mask).
- SBC inventing CLIP values (PBX owns which number; SBC formats).
- Per-country Egress trunks **from one** instance (use a second nationally homed instance instead — §3.A).
- Full auto CLIP-by-CC on a multi-locale instance (only needed if §3.B wins).

## 5. Open questions

1. ~~**Confirm §3.A as product lock**~~ — **v1 desk / usual ops 2026-08-19;** **§3.E** direction: mixed-nationality **capability** on an instance (mangle location).  
2. Org/billing: one customer → N nationally homed instances; shared directory? (parked)  
3. §3.B not v1 — reopen only with an explicit single-instance mandate.  
4. Softphone/`+` directory as convenience on top of §3.A. (parked)  
5. Phase 2 `serving_cc` on SBC — tenant-scoped under §3.E, not only instance. (parked)  
6. **Outbound drouting group per origin** — see **§9** (**TODO #5d**). Design accepted; **later out**, not first candidate. **`ORIGIN_OUTBOUND_ROUTING_DESIGN.md`**.  
7. ~~**Tenant locale on a shared instance?**~~ — **direction yes (§3.E).** Usual ops: do not mix carrier nationalities on a box. Build later: tenant `serving_cc` + origin group; mangle per tenant or on SBC — not instance-wide dual seize.

## 6. Lab checklist

### Toliman as US-homed (§3.A)

| # | Case | Pass |
|---|------|------|
| L1 | US domestic via US identity | Completes (Twilio path) |
| L2 | UK via US identity + `01144…` (+ UK CLIP on that ext) | Completes (proved) — **workaround**, not the long-term UK habit path |
| L3 | UK national `07…` on US-only mangle | Expect fail (limitation) |
| L4 | UK dial with US-only CLIP | Expect fail |
| L5 | Second **UK-homed** identity on same phone → dial `07…` + UK CLIP | Target lab for §3.A |

### If exercising §3.B on one instance

| # | Case | Pass |
|---|------|------|
| M1 | Primary habit + IDD-other + matching CLIP | Completes |
| M2 | Foreign national seize on primary mangle | Expect fail / do not productize |

## 7. Next engineering (parked)

**#5c is closed** on the lock above — no further work this pass.

When someone picks the track up later (optional, not blocking):

- Lab **L5:** same handset dual identity → UK-homed instance + US-homed instance.  
- MkDocs: “instance is nationally homed; cross-border = second line on the phone.”  
- Design **§9** — per-home outbound drouting group (Twilio `1` scoped to US homes) — that is **#5d**, not #5c. Draft: **`ORIGIN_OUTBOUND_ROUTING_DESIGN.md`**.  
- Do **not** productize stuffing `0:+44` into a US Egress transform.

## 8. Exploration — “unhomed / international” instance (not locked)

Play space if we ever want **one** box to feel multi-country without §3.A’s second home.

| Idea | Mechanism | Telephony verdict |
|------|-----------|-------------------|
| **2 — Unhomed E.164 appliance** | Dial **CC + NSN** (and/or `+CC…` / IDD+CC). No national seize. Length ⇒ outbound; embedded CC ⇒ international. CLIP by dest CC from pool. | **Best** — instance lives on the ITU plane, not in a country |
| **1 — Locale profile keys** | Per-call UK/US transform+CLIP | Sugar on top of 2 for users who want national habit sometimes |
| **5 — Multi-Egress** | `Egress-UK` / `Egress-US` each with its own mangle; **OutRoutes** (ARS) choose trunk by dial prefix / pattern | Clever reuse of today’s mangle — but **N routes** (and operator discipline) to pick which Egress |
| **5b — One Egress + smart routes** | Single trunk to SBC (passthrough / minimal `+:`). **OutRoutes** carry locale brain: pattern → mangle rules + CLIP pool (or dest-CC CLIP) before Dial | Same power as 5 without a second trunk — digit map selects the algorithm |

**Note on 2:** “Just dial CC+area+SN” is digit E.164 (or `+` the same). Ambiguous national-only strings are **out of scope** for an unhomed instance — that is the point.

**Minimal build for 2 (lean 2026-08-12):** almost nothing new — dial **digit E.164 only** (e.g. NANP `1513…`, UK `441924…`). Egress transform is just **ensure leading `+`** (e.g. `:+`). **No IDD** (`00` / `011`), **no national seize** (`0:+44`, `1:+1`). Ambiguous national-only strings are out of scope. CLIP-by-dest-CC (or multi-identity) remains separate if the instance owns DIDs in more than one country.

**Note on 5:** Multiple mangles without multiple homes; cost is route table complexity and “which trunk did I seize?” support burden. Closer to “two homes in one Asterisk” than true unhomed.

**Note on 5b:** Preferred engineering shape if exploring unhomed on today’s stack — trunk stays dumb; routes (or route-attached profiles) apply locale-scoped transform + CLIP. National patterns only where a route **explicitly** opts in; default routes stay CC+NSN (§2).

## 9. Problem issue — outbound Peer group is global (not per home)

**Status:** Open problem **2026-08-12** — **design accepted 2026-08-19; parked past first candidate.** Usual first-out ops = one nationality / one carrier class per home (no mixed-country trunks required).  
**TODO:** product **#5d** (later out).  
**Design:** [`ORIGIN_OUTBOUND_ROUTING_DESIGN.md`](ORIGIN_OUTBOUND_ROUTING_DESIGN.md) — Phase A = origin `do_routing` group (hidden CPS); Phase B = smarter tenant/SBC mangle (§3.E).  
**Lab symptom (Toliman / Magrathea):** From Asterisk, OpenSIPS always `do_routing(0, …)`. Group **0** includes rule **`prefix=1` → Twilio**. Longest-prefix therefore sends **every** NANP (`1…` / `+1…`) home’s outbound to Twilio — including a **UK-homed** (or UK-CLIP) instance such as Toliman. CLIP then fails carrier auth (e.g. Twilio **403** on UK CLI). Parking rule 26 is a lab band-aid, not a product answer.

**Not the same as §3.D:** dest-prefix → Peer is **wanted inside one serving group** (UK: Magrathea vs Gamma). The defect is one **global** group keyed only on DNID, so Peers steal **cross-border dests** from the other home class:

| Origin home | DNID | Wrong winner if group 0 is shared | Right Peer |
|-------------|------|-------------------------------------|------------|
| UK-homed | NANP `1…` | Twilio | Magrathea (intl from UK) |
| US-homed | UK `44…` | Magrathea | Twilio (intl from US) |

### What we need

Scope outbound prefix tables by **origin** (`serving_cc` / home or tenant — see open Q), not by dest CC. **Every** E.164 DNID from that origin uses that origin’s Peer set (UK origin → Magrathea/Gamma for `44…` **and** `1…`; US origin → Twilio for `1…` **and** `44…`). Cross-border IDD stays on the **origin** carriers.

### Candidate → design draft

Superseded by **[`ORIGIN_OUTBOUND_ROUTING_DESIGN.md`](ORIGIN_OUTBOUND_ROUTING_DESIGN.md)** (still not locked for build). Summary: one outbound `groupid` per origin policy; resolve on `FROM_ASTERISK` from tenant domain / dispatcher attrs; catalog `serving_cc` → attrs; PBX stays Peer-unaware.

### Weak / non-goals for this issue

- CLIP-only Peer pick as the sole scope (helps A-number vs carrier; does not replace home policy).  
- Multiple Egress trunks on one instance to “pick Twilio vs Magrathea.”  
- Hope that one global group 0 can serve mixed nationally homed fleets.

### Twin of §3.A

Nationally homed instance → **mangle on the node** *and* **outbound rule group on the SBC**. Destination prefix stays **inside** the home’s group.
