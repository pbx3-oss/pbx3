# Lab install automation harness (local VMs)

**Status:** Locked 2026-08-17 (operator plan).  
**Parent:** **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** (T4 Lab / D1).  
**Purpose:** Use **local Ubuntu/Debian VMs + hypervisor snapshots** as the fast loop for **install / onboard / catalog automation** — not as a call lab.

---

## Stance

| Do | Do not |
|----|--------|
| Prove **guest installers + browser panels** (Windows-tech happy path) | Require the Lab user to run AWS CLI, paste Garage keys, or Mac onboard |
| Aelintra: revert snapshots between installer iterations | Treat extra laptop CLI as the product story |
| Same catalog shape as cloud (installer writes static keys) | Invent a divergent local catalog |
| Prefer **2 VMs** | Require 3 boxes, public DNS, LE, or SIP for this track |

**Product UX bar:** **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** § Windows tech, panels first. This harness is how **we** test that — not a second CLI religion.

**Cloud AWS lab** remains the place for real calls until install is boring.

---

## Snapshot baseline

**Create the snapshot after:**

- Ubuntu or Debian guest (24.04 preferred), updated
- SSH reachable from the operator machine
- Optional: guest tools / shared clipboard

**Before any** pbx3 / pbx3api / SBC / Gatekeeper / Garage / Docker fleet stack.

Label clearly (e.g. `clean-ubuntu-2026-08-17`). **Revert → install → assert → revert** each pass.

**Operator boxes (2026-08-17):** Parallels aarch64 Ubuntu 24.04.4 — live IPs / SSH in private **`~/GiT/pbx3-ops/LAB_INVENTORY.md`**. Skip cagi on arm64.

Optional later: a second snapshot “deps only” (docker engine, etc.) if that shortens loops — still **before** product install.

---

## Topology (harness minimum)

Matches T4 (SBC+GK+Garage colocated; one home). This operator lab:

| VM | Role | This lab |
|----|------|----------|
| **A** | SBC + Gatekeeper (controller) + Garage | **`pbx3sbc`** — IPs in **`~/GiT/pbx3-ops/LAB_INVENTORY.md`** |
| **B** | Home instance (pbx3 + pbx3api; cagi optional) | **`pbx3inst`** |

LAN names (`sbc.lab` / `control.lab` / `garage.lab` / `home1.lab`) can alias those hosts. `/etc/hosts` (or private DNS) on the operator machine **and** guests. Third home only when multi-node onboard is under test.

---

## One iteration (checklist)

Reset both VMs to the clean snapshot, then exercise the **product** path (installers on the guests). Extra `aws s3` checks below are **Aelintra debug**, not Lab MkDocs.

### 0 — Prereqs

- [ ] Debs/tips reachable from guests (installer fetch or one scp — minimize)
- [ ] Browser on the Windows (or any) workstation can hit guest IPs
- [ ] SPA: LAN static on control host **or** temporary Vite for contributors

### 1 — Control box (`pbx3sbc`) — one installer

- [ ] Prompted control install: Garage + catalog seed + Gatekeeper env **on the box**
- [ ] Browser: Gatekeeper health + Fleet login
- [ ] (Debug only) `aws --endpoint-url … s3 ls` from ops — not in Lab docs

### 2 — Home box (`pbx3inst`) — one installer

- [ ] pbx3 + pbx3api prompted install (skip cagi on arm64); `/up` 200
- [ ] SPA admin login on `:44300`

### 3 — Adopt (panel first)

- [ ] Fleet panel registers/adopts the home (fallback CLI until panel exists)
- [ ] Catalog row shows LAN `api_base_url`; pick instance → Sanctum → a panel

**Pass** = control health + home `/up` + catalog pick + login. Then revert snapshots.

---

## Explicit out of scope (this harness)

- Port-forward **5060** / carrier Peer / DID audio
- Chunked RTP DNAT / rtpengine
- Let’s Encrypt (use HTTP or snakeoil / hosts-file trust)
- Asterisk dial tests, SIPp, WebRTC line test audio
- Teaching the Lab user AWS CLI or Garage internals

Those stay optional later under try-it T4 “public carrier into NATed Lab” — not part of install-automation acceptance.

---

## Known gaps before D1 is “green on VMs”

| Gap | Why it blocks the Windows-tech path |
|-----|-------------------------------------|
| **Control installer** starts Garage, seeds catalog, writes Gatekeeper `.env` | Tech must not run Compose/`aws s3`/`bootstrap-org-bucket` by hand |
| **Gatekeeper S3Client `endpoint` + path-style** | Invisible seam so Garage works; pbx3api already has the env knobs |
| **Fleet panel adopt** (fallback: static-key onboard) | Tech must not run Mac `onboard-fleet-instance.sh` |
| **Home installer** prompts for Lab names / skip cagi / skip LE | Copy-paste MkDocs, not a worksheet of exports |

No separate “Garage dialect” — same S3 key layout; endpoint + path-style + static keys only (Rule **9**). Keys stay on the control host.

---

## Relation to D1 / A9

- This harness is how **D1** should be proven: **installers + panels** on local VMs, **no SIP**.
- Marketing **A9** (Lab deployment with lab SIP) remains the fuller T4 story; SIP is **not** required to accept install automation.
- Walk this checklist as the default regression before cloud greenfield.

---

## Revision

| Date | Note |
|------|------|
| 2026-08-17 | Locked: local VM snapshots = install automation harness; no calls; 2-VM minimum; Garage = S3 analog; Gatekeeper endpoint gap called out. |
| 2026-08-17 | Operator Parallels pair snapshot+IP-pin done; inventory in pbx3-ops. |
| 2026-08-17 | UX bar: Windows tech, one installer per box, then panels. Harness tests that path. |
