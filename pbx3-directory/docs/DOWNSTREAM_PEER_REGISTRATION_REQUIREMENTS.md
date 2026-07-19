# Downstream peer registration edge (future requirement)

**Status:** **Not implemented** — initial architectural decisions recorded 2026-07-18.  
**Related:** **`DESIGN_RULES.md`** Rules 1, 7, 11 and 13; **`pbx3sbc/workingdocs/PEERING-PLAN.md`**; **`FLEET_SYSTEM_OVERVIEW.md`**.

---

## Requirement

PBX3 may later need to accept SIP registrations from **downstream trunk peers** whose address cannot be treated as a fixed, IP-trusted peer.

This is distinct from:

- endpoint phones registering through the current SBC to their tenant Asterisk;
- the current SBC trusting carrier, Asterisk and other trunk peers by configured IP/SIP address; and
- the current SBC registering **outbound** to an upstream carrier with `uac_registrant`.

---

## Current state

The current **pbx3sbc** is not the registration authority:

1. Endpoint REGISTER requests are proxied to the tenant's Asterisk.
2. Asterisk challenges, authenticates and accepts or rejects the registration.
3. After a successful response, OpenSIPS records the endpoint contact in `location` for routing and NAT handling.
4. Trunk Peers use configured `dr_gateways` addresses and source-address trust; they do not acquire a dynamic Peer destination by registering.

Therefore the existing SBC has no SBC-owned authentication and binding mechanism for a downstream trunk peer.

---

## Settled architectural decisions

### D1 — A separate instance class

Downstream peer registration will be handled by a new **registration-edge SBC instance class**. It will not be added as another personality or mode of the current main SBC.

### D2 — A separate OpenSIPS image

The registration edge will have its own OpenSIPS image, configuration, deployment lifecycle and tests.

It will **not share the current pbx3sbc OpenSIPS image**. Common operational knowledge and deliberately extracted utilities may be reused, but the runtime images and routing scripts remain independent.

### D3 — Registration authority lives on the registration edge

The registration edge will:

- challenge and authenticate downstream peer REGISTER requests;
- own the downstream peer credentials and active bindings;
- handle expiry, re-registration, deregistration and NAT/contact behaviour; and
- route SIP to the currently valid registered contact.

The current main SBC and tenant Asterisk nodes do not become the authority for these trunk registrations.

### D4 — Trusted SIP interconnect to the main SBC stack

The registration edge and main SBC communicate over a fixed, explicitly trusted SIP peer link.

```mermaid
flowchart LR
    peer["Downstream peer"] -->|"REGISTER + authenticated SIP"| reg["Registration-edge SBC"]
    reg <-->|"trusted SIP peer link"| main["Main pbx3sbc stack"]
    main <--> fleet["PBX3 fleet / carriers"]
```

The main SBC sees the registration edge as a stable trusted Peer. It does not need each downstream peer's dynamic Contact projected into `dr_gateways`.

### D5 — Keep responsibilities narrow

The registration edge owns downstream peer authentication and reachability. The main SBC retains its current fleet-edge responsibilities, including carrier peering, DID routing and Asterisk dispatcher routing.

The registration-edge role must not silently absorb fleet orchestration, tenant homing or directory responsibilities.

### D6 — Standard SIP remains the runtime contract

The link between the registration edge and main SBC is standard SIP. The fleet directory/control plane must not be required for established registrations or calls to continue (**Design Rules 1, 7 and 11**).

Any future control-plane provisioning is management-plane work only. Runtime bindings remain local to the registration edge.

---

## Interim workaround (not the product path)

**Just in case** a lab or short-term need appears before the registration-edge instance class exists: treat the downstream trunk like an **extension**.

| Step | Behaviour |
|------|-----------|
| 1 | Downstream PBX REGISTERs into the **current** main SBC |
| 2 | SBC proxies REGISTER to a chosen tenant Asterisk (same path as phones) |
| 3 | Asterisk authenticates the identity (PJSIP endpoint / digest) |
| 4 | On 2xx, OpenSIPS stores the Contact in `location` |
| 5 | Calls **to** that AOR can follow `lookup(location)` to the registered Contact |

**What this buys:** dynamic reachability and Asterisk as auth authority, without building an SBC-owned trunk registrar.

**Why it is only a workaround:**

- The identity is an **endpoint/AOR**, not a Peer in `dr_gateways` (no Peer role, carrier grouping, or drouting gwlist semantics).
- **INVITEs from** that PBX are still not automatically trusted as a Peer via `is_from_gw` unless IP trust (or another identify path) is also configured.
- Dialplan/context must keep the identity from behaving like a normal extension (privileges, CID, concurrent calls).
- The AOR lives under a **tenant domain → dispatcher set**, so one Asterisk owns that fake “trunk extension.”

**Do not** elevate this into D1–D6. Product destination remains the separate registration-edge instance class with its own OpenSIPS image.

---

## Future functional requirements

When this work is prioritized, the registration edge must:

1. Authenticate downstream peers using dedicated trunk credentials.
2. Reject unknown, disabled or incorrectly authenticated registrations.
3. Maintain one or more current bindings per agreed peer/AOR policy.
4. Route calls from the main SBC to the active downstream binding.
5. Route authorized calls from the downstream peer to the main SBC.
6. Support expiry, refresh and explicit deregistration without stale routing.
7. Handle NAT safely where the downstream peer is not on a fixed public address.
8. Expose registration state and last failure to operators.
9. Integrate brute-force protection, rate limits, audit logging and failure notification.
10. Fail closed for authentication while preserving existing calls where SIP transaction/dialog state permits.

---

## Isolation requirements

- A registration flood or auth attack must not share the main SBC's OpenSIPS process or image.
- Credentials and registrar tables must not be added to the current main SBC merely to support this feature.
- Downstream registrar routing must have its own test pack and deployment rollback.
- Trust between the two SBC classes must be explicit and restricted by network policy plus SIP identity policy; “same fleet” alone is not authorization.
- Each downstream registration has one declared home of record. Static trust and registration-based reachability must not compete silently for the same peer.

---

## Open design questions for the implementation phase

These choices are deliberately not settled by this initial requirement:

- credential and peer-definition home of record, provisioning API and admin UI;
- single binding versus controlled multi-binding/forking;
- UDP/TCP/TLS support and whether mutual TLS is also offered;
- HA topology and replication of registrar bindings;
- media anchoring versus signaling-only proxying;
- topology hiding and identity/header normalization;
- exact routing identifiers used across the trusted inter-SBC link;
- repository layout and cloud/provider implementation;
- monitoring thresholds, retention and operator notification details.

These decisions require a dedicated design review before implementation.

---

## Acceptance shape

A future lab proof is complete when:

1. A downstream PBX with no fixed trusted source IP registers to the registration edge and completes authentication.
2. The registration edge shows an active, expiring binding.
3. The main SBC sends a call over its fixed trusted link and the registration edge delivers it to the active Contact.
4. The downstream PBX sends an authorized call through the registration edge to the main SBC.
5. A bad password is rejected and enters the abuse-monitoring path.
6. Deregistration or expiry removes reachability without editing the main SBC Peer address.
7. The existing phone-to-Asterisk registration path and current trusted Peers on the main SBC are unchanged.

---

*Last updated: 2026-07-18 — initial future requirement, instance-class decision, and Asterisk-proxied REGISTER interim workaround.*
