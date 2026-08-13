# Multi-locale instance (cross-border desk) — requirements stub

**Status:** Stub **2026-08-12** — **§3.A preferred lean** (nationally homed instance + phone multi-identity); confirm as lock when ready. **§9** open problem: global outbound `do_routing(0)` vs per-home groups (design next).  
**Lab persona / host:** operator lives in the **USA**, business / DIDs in the **UK** → US home **Toliman**; UK home = second identity/instance (lab L5).  
**Related:** [`NUMBER_WIRE_POLICY.md`](../pbx3-directory/docs/NUMBER_WIRE_POLICY.md) · [`NUMBER_DIALECT_REQUIREMENTS.md`](../pbx3-directory/docs/NUMBER_DIALECT_REQUIREMENTS.md) (§5.1 face grammar, §5.3–5.4 recipes) · [`EGRESS_PLUS_E164_WIRE.md`](EGRESS_PLUS_E164_WIRE.md)

## 1. Problem

One fleet **instance** can own DIDs and Peers in **more than one country**. Inbound is easy (SBC routes each carrier DID home). Outbound is hard:

- There is **one Egress** trunk instance → SBC.
- Egress **mangle** is a simple longest-prefix rewrite (one “serving locale” habit table). It **cannot** safely mean both UK national `0…` and US national/`1…` at once: shared seize digits (`0`) are ambiguous across countries.
- Carriers reject calls when **CLIP** is not an authorised identity for that egress Peer / country.
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

Two postures fit the persona. **Prefer A** unless a single-instance mandate appears later.

### 3.A Preferred candidate — nationally homed instances + phone multi-identity

**Locked lean 2026-08-12 (lab operator):** an instance is **nationally homed** (one primary serving locale / one Egress mangle). Cross-border desk = **two identities on the phone**, not two nationals on one mangle.

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

Still valid for “one PBX, many countries,” but fights the simple mangle and needs multi-CLIP product work. **Do not** “fix” by stuffing foreign seize rules into the primary mangle.

### 3.C Shared rules (either posture)

- **One Egress per instance** → SBC; SBC may still fan out to many Peers.
- PBX owns CLIP **value**; SBC owns carrier **format**.
- Store CLIP/DIDs as **`+CC…`** on the wire-facing fields where possible.
- Inbound stays “DID → home”; no directory in the call path.

## 4. Non-goals (this stub)

- Bilingual national mangle (UK `0` + US `1` as equal first-class habits on one mask).
- SBC inventing CLIP values (PBX owns which number; SBC formats).
- Per-country Egress trunks **from one** instance (use a second nationally homed instance instead — §3.A).
- Full auto CLIP-by-CC on a multi-locale instance (only needed if §3.B wins).

## 5. Open questions

1. **Confirm §3.A as product lock** — instance must be nationally homed; cross-border = multi-identity on the phone across instances?  
2. Org/billing: one customer → N nationally homed instances; shared directory?  
3. If §3.B remains supported: primary locale + IDD-other + multi-CLIP — or refuse multi-country DIDs on one instance?  
4. Softphone/`+` directory as convenience on top of either model.  
5. Phase 2 `serving_cc` on SBC — still one CC per instance under §3.A.  
6. **Outbound drouting group per home** — see **§9** (parked problem; design tomorrow).

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

## 7. Next engineering (when scheduled)

- Confirm **§3.A** as product lock (or reject and keep §3.B).  
- Lab **L5:** same handset dual identity → UK-homed instance + Toliman.  
- Design **§9** — per-home outbound drouting group (Twilio `1` scoped to US homes).  
- MkDocs: “instance is nationally homed; cross-border = second line on the phone.”  
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

**Status:** Open problem **2026-08-12** — design tomorrow; no Magrathea rule change yet.  
**TODO:** product **#5d**.  
**Lab symptom (Toliman / Magrathea):** From Asterisk, OpenSIPS always `do_routing(0, …)`. Group **0** includes rule **`prefix=1` → Twilio**. Longest-prefix therefore sends **every** NANP (`1…` / `+1…`) home’s outbound to Twilio — including a **UK-homed** (or UK-CLIP) instance such as Toliman. CLIP then fails carrier auth (e.g. Twilio **403** on UK CLI). Parking rule 26 is a lab band-aid, not a product answer.

### What we need

Scope carrier prefix rules (e.g. Twilio’s `1`) to **US-homed PBXs only**, not every home that dials NANP.

### Candidate (not locked)

| Piece | Direction |
|-------|-----------|
| **One drouting `groupid` per outbound policy** | e.g. UK-homed → group without `1`→Twilio; US-homed → group with Twilio NANP |
| **Select group on `FROM_ASTERISK`** | Already know source home (dispatcher `setid` / source IP); stop hardcoding `do_routing(0)` |
| **Catalog → attrs** | Instance `serving_cc` or `outbound_dr_group` projected onto Peer / dispatcher attrs; cfg reads attr → `$var(out_group)` |
| **PBX** | Stays one dumb Egress; no Peer-awareness |

### Weak / non-goals for this issue

- CLIP-only Peer pick as the sole scope (helps A-number vs carrier; does not replace home policy).  
- Multiple Egress trunks on one instance to “pick Twilio vs Magrathea.”  
- Hope that one global group 0 can serve mixed nationally homed fleets.

### Twin of §3.A

Nationally homed instance → **mangle on the node** *and* **outbound rule group on the SBC**. Destination prefix stays **inside** the home’s group.
