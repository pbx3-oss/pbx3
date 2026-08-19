# rtpengine — selective engage (research)

**Status:** Research — **not locked** (2026-08-19).  
**Extends (does not replace):** **`SBC_PRODUCT_TRACKS.md`** gap #2 · **`FLEET_TRUNK_PEERING_DECISION.md`** §6.1 · **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** Appendix A.

**Summary:** RTP **bypass** (signaling at SBC, media at home Asterisk) remains the product default. **rtpengine** is the credible media-plane class for **topology hiding**, NAT repair, and WebRTC↔legacy **media** bridging — but only on **routes that need it**. Load on busy systems is manageable with **selective engage** and **no default transcoding**; it becomes painful when **all** media is anchored at the edge or codecs are translated.

---

## 1. Problem statement

Fleet edge (OpenSIPS on the **SBC**) already scales well for **signaling**: REGISTER, INVITE, usrloc, dispatcher, domain→setid. Product posture (2026-07+) locks **RTP bypass**: endpoints and carriers send media to **home Asterisk**, not through the SBC relay.

That posture is correct for **capacity and simplicity**, but it leaves gaps where bypass breaks or is undesirable:

| Need | Signaling-only SBC | Media plane (rtpengine-class) |
|------|-------------------|------------------------------|
| Route calls to correct home | Yes | N/A |
| Hide home node IP in SDP (topology hiding) | Partial (SIP headers) | **Yes** — remote sees SBC media address |
| Symmetric RTP / NAT hairpin repair | No | **Yes** |
| WebRTC SRTP/ICE ↔ desk/carrier RTP | No (WSS signaling only) | **Yes** — when browser audio must terminate at edge |
| Foreign PBX behind SBC (Track A) | Signaling proxy | Often **yes** for consistent public media face |
| Generic “VPN/tunnel to lab” (frp, Orbien, etc.) | N/A | **No** — wrong tool class for production SIP/RTP |

**Orbien / frp / Cloudflare Tunnel** are reasonable for **HTTPS admin** or SSH to lab VMs. They are **not** a substitute for SBC-as-edge or rtpengine for telephony media (SDP addresses, RTP port ranges, latency, scanner exposure).

---

## 2. Product locks (unchanged)

From **`FLEET_TRUNK_PEERING_DECISION.md`** §6.1 and **`SBC_PRODUCT_TRACKS.md`**:

- **Default:** RTP bypass — media path includes **home Asterisk**; SBC is **not** in the RTP path unless explicitly engaged.
- **Do not** anchor media for capacity reasons alone or “because SBCs usually do media.”
- **rtpengine** is **parked** until a **concrete trigger** appears.
- **HA media plane** deferred (signaling HA is a separate, simpler story).
- **Try-it / lab adoption** must not depend on rtpengine (**Appendix A**).

**Triggers to unpark (existing):**

1. **Track A** — foreign PBX (SARK / FreePBX) behind SBC where bypass is insufficient.
2. **Peer forbids bypass** — carrier or ITSP requires a single public media face / topology hiding.
3. **LAN-edge** — home on LAN, public remote party; **chunked RTP DNAT** pilot fails or is rejected for ops.
4. **WebRTC ↔ legacy non-WebRTC** — signaling-only WSS gateway does not yield browser audio; **media** gateway required (**§6.1** — may never be worth it for oldest SARK; separate go/no-go).

**Prefer before rtpengine (lab / small-N):** chunked RTP port-forwards (**`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** T4 optional carrier subsection).

---

## 3. What rtpengine adds (when engaged)

OpenSIPS controls **when** to invoke rtpengine (`rtpengine_manage()` / offer-answer flags). rtpengine performs **media relay** (and optionally SRTP termination, recording tap, transcoding).

| Capability | Fleet relevance |
|------------|-----------------|
| **Topology hiding** | Remote party SDP shows **SBC media IP**, not home `.31`-class addresses — mobility, multi-home, LAN-origin homes |
| **NAT / symmetric RTP repair** | When Contact/SDP and actual RTP paths diverge (hairpin, strict ALG) |
| **SRTP ↔ RTP** | Browser WebRTC legs that cannot bypass to home UDP |
| **Recording / tap** | Edge-attached copy without Asterisk MixMonitor (policy choice) |
| **Selective relay** | Per-route, per-Peer, per-tenant — not global |

OpenSIPS alone does **not** replace media relay for hiding **RTP addresses** in SDP.

---

## 4. Load model (why “busy system” is a valid worry)

Rough cost model:

```text
media_cost ≈ concurrent_calls × bitrate × relay_hops × (transcode ? large : 1)
```

### Cheap — typical “topology hiding only”

- **Kernel relay / passthrough** (rtpengine kernel module): packet copy, **low CPU per Mbps**.
- **Same codec** both sides (e.g. G.711 end-to-end), **no transcoding**.
- Industry rule of thumb: **hundreds to low thousands** of concurrent G.711 relay legs on a modest NIC-heavy box (exact ceiling depends on kernel path, PPS, NIC offload — **measure**).

### Expensive — where busy fleets hurt

| Factor | Effect |
|--------|--------|
| **Transcoding** (G.729, Opus↔μ-law, wideband downgrade) | **Orders of magnitude** more CPU than relay |
| **Userspace-only** forwarding | Worse under high packet rate |
| **Default anchor all media at SBC** | Extra **hop** + **NIC bandwidth** on edge for every call (even if CPU per packet is low) |
| **Stateful media HA** | Harder than signaling HA; clustering helps but is ops-heavy |

**Conclusion:** Load is **not** an argument against rtpengine entirely. It **is** an argument against **global media anchoring** and against **transcoding by default**.

---

## 5. Recommended architecture (when unparked)

### 5.1 Selective engage (OpenSIPS policy)

Engage rtpengine **only** on legs that match a trigger, for example:

- Inbound **Peer** / carrier where SDP must not expose home IP.
- **WebRTC** browser legs requiring SRTP termination at edge.
- **Track A** foreign PBX routes.
- Explicit tenant/route **“relay mode”** (catalog- or Filament-authored — Rule 13: fleet-owned projection).

**Do not engage** for routine fleet desk-to-desk calls that already work on bypass (lab **101↔102** class).

### 5.2 Split signaling and media capacity

- **OpenSIPS** — signaling scale (current design).
- **rtpengine** — dedicated **NIC-heavy** node(s); scale media independently.
- OpenSIPS → rtpengine control socket; multiple rtpengine nodes possible for horizontal scale.

### 5.3 No transcoding by default

Topology hiding ≠ codec change. Enable transcode **only** on routes that require it (document per Peer/recipe).

### 5.4 Measure before HA

Before media-plane HA, instrument:

- Concurrent rtpengine sessions
- Relay Mbps (in/out per NIC)
- Kernel vs userspace forwarding
- Drops / RTCP quality proxies

Define scale triggers (example): “add rtpengine node when sustained relay > X Gbps or > Y sessions” — numbers are **environment-specific**, not locked here.

### 5.5 Example call shape (topology hiding, home still in path)

```text
Carrier ──RTP──► SBC (rtpengine) ──RTP──► Home Asterisk ──RTP──► Phone
         hidden SDP face              queues, VM, MOH, recording policy
```

Media is anchored at SBC **for that leg**; home remains application logic (dialplan, CAGI, queues). Load applies to **calls that use the relay**, not every registered extension.

---

## 6. What this is not

| Approach | Role |
|----------|------|
| **RTP bypass (default)** | Production fleet path; keep until trigger |
| **Chunked RTP DNAT** | Lab / small-N carrier pilot before rtpengine |
| **Orbien / frp / tunnel** | Off-LAN **admin** access only — not call-path edge |
| **rtpengine everywhere** | Rejected — load, latency, blast radius |
| **rtpengine for fewer VMs in try-it** | Rejected — **Appendix A** |

---

## 7. Unpark checklist (future implementation)

When a trigger is accepted, before coding:

1. **Name the route class** (which Peers, which WebRTC profile, Track A recipe).
2. **Bypass vs engage matrix** — table of call legs and expected media path.
3. **Capacity assumption** — concurrent calls, codec list, **transcode yes/no**.
4. **Pilot environment** — lab chunked-NAT result or cloud Peer requirement.
5. **Rule 13** — OpenSIPS/recipe ownership (fleet adapter / catalog); no ad-hoc Filament co-author of call-path law.
6. **Rule 14** — destructive or fleet-wide edge changes via durable job or confirm-gated ops.
7. **Effort estimate (historical):** ~1–2 weeks SBC MVP (**Appendix A**).

---

## 8. Related docs

| Doc | Topic |
|-----|--------|
| **`SBC_PRODUCT_TRACKS.md`** | Gap #2; roadmap order |
| **`FLEET_TRUNK_PEERING_DECISION.md`** | §6.1 RTP at edge; WebRTC media strategy |
| **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** | Appendix A; RTP bypass; chunked DNAT |
| **`DOWNSTREAM_PEER_REGISTRATION_REQUIREMENTS.md`** | Topology hiding (signaling / identity) |
| **`WEBRTC_WSS_LAB.md`** | W1 green on bypass; no rtpengine for proven path |
| **`workingdocs/TODO.md`** | Item **#30** (parked) |

---

## 9. Session note (2026-08-19)

Discussed after lab **101↔102** green on LAN bypass. Confirmed: **rtpengine likely for topology hiding and selective media**, not Orbien-class tunnels; **load concern** addressed by **selective engage**, not global anchor. Promote sections to locked requirements when a trigger is accepted and checklist §7 is complete.
