# Home firewall — Shorewall → UFW migration

**Status:** Direction locked **2026-08-24** (choose **UFW**; plan not yet implemented).  
**Repos when built:** **pbx3** (installer, package Depends, scripts, NetHelper) · **pbx3api** (FirewallController, syscommands ICMP/LE noise) · **pbx3spa** (FirewallView) · docs MkDocs install/firewall notes.  
**Related:** [`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`](../pbx3-directory/docs/TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md) §11.4–11.7 · [`FLEET_TRUNK_PEERING_DECISION.md`](../pbx3-directory/docs/FLEET_TRUNK_PEERING_DECISION.md) · [`LETSENCRYPT_PER_TENANT_FQDN.md`](LETSENCRYPT_PER_TENANT_FQDN.md) · private ETL **`aelintra/sark-to-pbx3`** (§10) · Design Rules SIP-obscurity context (fleet no longer depends on home STRING match).

---

## 1. One-line purpose

Replace **EOL Shorewall / Shorewall6** on the home (instance) with **UFW**, matching the simplified fleet posture (**SIP from SBC IP(s) only**; no packet-payload inspection on the node).

---

## 2. Why now

| Fact | Implication |
|------|-------------|
| Shorewall is **unmaintained** (author retired; no successor project) | Staying on it is operational debt and a future Ubuntu packaging risk |
| Historical home SIP defense used **STRING / `fqdninspect`** INLINE rules | Required iptables string match under Shorewall; **SBC now owns SIP inspection** for fleet |
| Fleet design already decided **“5060 from SBC IP(s)”** | Maps cleanly to UFW allow-from rules; STRING machinery can retire on fleet |
| Target OS is **Ubuntu 24.04 appliance**, not a general-purpose multi-distro server | UFW is the idiomatic Ubuntu front-end; Ubuntu “lock-in” is acceptable for this product class |

**Platform note (accepted):** UFW is Ubuntu-centric. That is a deliberate trade for an **appliance** image. Product rules should be stored as a **small declarative allow-list** (proto / port / source / comment) that *UFW applies*, so a future backend (raw nftables on another distro) can re-target without resurrecting Shorewall dialect in the SPA.

**Rejected alternatives (2026-08-24):**

| Option | Why not |
|--------|---------|
| **firewalld** | RHEL-shaped; heavier zones/D-Bus; wrong default ecosystem for Ubuntu homes |
| **Raw nftables as day-1 product surface** | Correct kernel tech (UFW already sits on nft on noble) but owns tables, dual-stack policy, SPA/installer UX, and fail2ban wiring ourselves. Keep as **Phase-2 escape hatch** (e.g. RTP rate-limit) if UFW proves insufficient |

---

## 3. Locks

| # | Lock |
|---|------|
| **F0** | Home host firewall product path = **UFW** (IPv4 + IPv6 via UFW dual-stack). |
| **F1** | **Fleet:** no Shorewall STRING / `pbx3_inline_fqdn` / `update-fqdn-inline.sh` on the call path. SIP **UDP/TCP 5060** (and **5061** if used) **from SBC address(es) only**. |
| **F2** | **`fqdninspect`:** retire as a live fleet security control. Panel/API may hide or no-op on fleet; solo/direct may keep a transitional period then drop. |
| **F3** | **RTP 10000–20000/udp** stays **open to the world** (RTP bypass + roaming phones). Optional per-source rate-limit is a later harden, not a v1 blocker. |
| **F4** | **fail2ban** banaction moves from `shorewall` → **`ufw`** (shipped fail2ban action). |
| **F5** | SPA Firewall panel edits a **structured allow-list**, not Shorewall rule text. Apply = rewrite managed UFW rules + `ufw reload` (via syshelper). |
| **F6** | LE temporary **:80** open/close remains; implement with **UFW managed rules** (or `ufw allow`/`delete` by comment), not Shorewall `pbx3_rules` append. |
| **F7** | Do **not** run Shorewall and UFW together. Migration disables/removes Shorewall services before enabling UFW default-deny + allow set. |
| **F8** | EC2/security groups remain a **second layer**; UFW is host policy. Document both in install/commission docs. |

---

## 4. Target posture (rule sets)

### 4.1 Fleet home (primary)

| Allow | Source | Notes |
|-------|--------|-------|
| SSH 22/tcp | anywhere (or operator CIDR if hardened later) | Same as today |
| API 44300/tcp | anywhere | SPA/API |
| SIP 5060/udp + 5060/tcp | **SBC VIP/EIP set** | Core fleet lock |
| SIP 5061/tcp | SBC set **if** TLS used node↔SBC | Optional |
| RTP 10000:20000/udp | anywhere | Bypass; see F3 |
| HTTP 80/tcp | ephemeral | LE only (open/close scripts) |
| WSS 8089/tcp | **closed** on fleet homes (edge WSS) | Lab/solo may open |

NTP / LDAP / IAX from “LAN” in today’s `pbx3_rules` are **legacy solo shapes** — keep only if a solo/direct profile still needs them; do not invent fleet LAN SIP.

**SBC address source of truth (implementer choice, pick one and document):**

1. Env / onboard: `PBX3_SBC_SIP_SOURCES` (CIDR/IP list), or  
2. Read from Egress peer / fleet posture already on the node, or  
3. Installer writes `/etc/pbx3/ufw-sbc.sources` refreshed on Provision edge / setip.

Prefer **idempotent rewrite** of a named UFW app or numbered comment block (`# pbx3-managed`) so Provision edge IP changes do not stack duplicate allows.

### 4.2 Solo / direct (no SBC)

| Allow | Source | Notes |
|-------|--------|-------|
| SIP 5060/udp+tcp (±5061) | **LAN CIDR** (from setip) and/or operator-edited allows | Replaces `$LAN` Shorewall params |
| Same API/SSH/RTP/LE as fleet | | |
| 8089 | if instance-direct WSS used | Lab / singleton |

No STRING match. Security = network allow + Asterisk auth (+ optional fail2ban), not SIP URI inspection.

---

## 5. Surface inventory (replace or delete)

| Area | Today | After UFW |
|------|-------|-----------|
| Package `Depends` | `shorewall`, `shorewall6` | `ufw`; drop shorewall\* |
| `installer.sh` | enable shorewall{,6}, copy rules/inline, `shorewall update` | `ufw --force enable`, apply baseline profile, disable shorewall units if present |
| Templates under `etc/shorewall{,6}/` | zones, policy, `pbx3_rules`, inline FQDN/limit | Replace with UFW baseline script + optional `/etc/pbx3/firewall.allows` |
| `setip.php` | writes `local.lan` / `local.if1` | Write LAN CIDR for solo SIP allows; stop Shorewall params |
| `NetHelperClass` FQDN inline | STRING INLINE + restart | **Delete or no-op** on fleet; remove from restart path |
| `update-fqdn-inline.sh` / `shorewallreload.php` | tenant/sysglobal/firewall restart | Skip on fleet; remove when `fqdninspect` retired |
| `le-port80-open.sh` / `close` | append Shorewall ACCEPT | UFW allow/delete managed :80 |
| `reloader.sh` / `sanitize-firewall.php` | `shorewall check` | UFW status / apply-baseline check |
| fail2ban `banaction` + `shorewall.local` | Shorewall | `ufw`; drop shorewall.local link |
| **pbx3api** `FirewallController` | R/W `/etc/shorewall/pbx3_rules{,6}` + check/restart | R/W declarative allows + `ufw-apply` syscmd |
| **SysCommandController** ICMP ping toggle | sed Shorewall `Ping/REJECT` | UFW ICMP policy or documented “not exposed” |
| **pbx3spa** `FirewallView` | Shorewall line editor + Raw | Table of allows (proto/port/source/comment); optional advanced later |
| Logs list | `shorewall.log` | `ufw.log` / kernel if enabled |
| MkDocs / install docs | Shorewall mentions | UFW + SG dual-layer |

---

## 6. Phases

### Phase 0 — Spec complete (this doc)

- [x] Choose UFW; record locks F0–F8 and fleet vs solo postures.
- [ ] Confirm SBC IP list source (env vs provision artifact) before coding Phase 2.

### Phase 1 — Lab proof (no SPA rewrite yet)

1. Snapshot lab home (`.31` or throwaway).
2. Capture current working ports with Shorewall up.
3. Disable shorewall{,6}; enable UFW default deny incoming / allow outgoing.
4. Apply fleet baseline by hand (SBC IP + RTP + 44300 + 22).
5. Prove: desk REGISTER via SBC, extension call, RTP audio, SPA login `:44300`, fail2ban ban/unban once.
6. Prove LE open/close :80 with UFW helpers (dry-run or staging).

**Exit:** written lab notes in ops TODO; no package cutover yet.

### Phase 2 — pbx3 package + installer

1. Add `scripts/ufw-apply-baseline.sh` (idempotent; profiles `fleet` | `solo`).
2. Wire installer: Depends `ufw`; stop shipping Shorewall templates as live config; migrate-or-purge on upgrade.
3. Replace LE port-80 scripts; setip LAN for solo; fail2ban → `ufw`.
4. Remove or gate FQDN inline path (`fqdninspect=NO` default; skip update on fleet import — already decided in mobility design).
5. Package bump when ready for fleet roll.

### Phase 3 — API + SPA

1. New allow-list file format (JSON or simple line DSL owned by pbx3 — **not** Shorewall syntax).
2. `FirewallController` GET/POST/PUT against that file + `ufw-apply` via syshelper.
3. Rewrite `FirewallView` to structured rows; keep IPv4/IPv6 sections or unify under UFW dual-stack with source family.
4. ICMP syscommand: reimplement or drop from UI until needed.
5. Docs: `general.md`, install pages, LE docs (drop Shorewall INLINE FQDN as active path).

### Phase 4 — Retire Shorewall entirely

1. Remove `shorewall*` from Depends and tree templates (or archive under `workingdocs/archive/` if needed for archaeology).
2. Delete dead PHP (inline FQDN writers), prerm links, help text, log names.
3. Greenfield install must never install Shorewall.
4. Upgrade path: one-shot “detect Shorewall → apply UFW baseline → disable Shorewall” in postinst/installer.

### Phase 5 — Optional harden (not blocking)

- RTP UDP per-source rate-limit (UFW limit or small nft snippet beside UFW).
- Tighten SSH/API source CIDRs for cloud images.
- Auto-refresh SBC allow list on Provision edge / EIP change.

---

## 7. SPA / API contract (target)

**GET** returns structured rules, e.g.:

```json
{
  "profile": "fleet",
  "rules": [
    { "action": "allow", "proto": "udp", "port": "5060", "from": "3.93.26.82/32", "comment": "SBC SIP" },
    { "action": "allow", "proto": "udp", "port": "10000:20000", "from": "any", "comment": "RTP" }
  ]
}
```

**POST** validates and writes the managed file (does not apply).  
**PUT** (restart/apply) runs `ufw-apply-baseline.sh` or `ufw reload` after syncing managed rules.

Do **not** expose raw `iptables`/`nft` in v1. Advanced SSH remains for break-glass.

---

## 8. Upgrade / coexistence rules

1. **Never** `ufw enable` while Shorewall is still the active policy without a rehearsed cutover (risk of double-filter or lockout).
2. Installer must ensure **SSH and 44300** are allowed **before** default-deny takes effect (same caution as today’s Shorewall bootstrap comment).
3. Existing customer-edited `pbx3_rules` lines do **not** auto-translate perfectly — document: migration applies **profile baseline**; operators re-add custom allows in the new panel.
4. Cloud nodes: verify **SG** still admits needed ports; UFW tighten must not assume SG is open.

---

## 9. Acceptance checks

| # | Check |
|---|--------|
| A1 | Fresh install (lab): no shorewall packages required; UFW active; SPA login works |
| A2 | Fleet: SIP from non-SBC IP **dropped**; from SBC **OK** |
| A3 | Extension↔extension + PSTN (if configured) with RTP |
| A4 | fail2ban ban shows in `ufw status` / blocks offender |
| A5 | LE renew path opens :80 then closes |
| A6 | Firewall SPA save + apply persists reboot |
| A7 | `fqdninspect` / update-fqdn-inline **not** invoked on fleet tenant import |
| A8 | Solo profile: SIP from LAN CIDR works without SBC |

---

## 10. SARK → pbx3 migrate impact (ETL)

**Gap noted 2026-08-24:** the UFW decision was locked without an ETL pass; this section closes that. Private ETL: **`aelintra/sark-to-pbx3`**. Product strip already removed migrate from pbx3; firewall host state was never the ETL’s job.

### 10.1 What SARK actually carries

| Artifact | In `sarkbak` zip? | Notes (lab fixtures) |
|----------|-------------------|----------------------|
| `globals.fqdninspect` | Yes (DB) | Often **`YES`** on real sites (e.g. duncanrogers, regal, wdcvs, pdh3s01) |
| `globals.sipflood` | Yes (DB) | Often **`NO`**; drives Shorewall `pbx3_inline_limit` today |
| Tables `shorewall_blacklist` / `shorewall_whitelist` | Yes (DB) | Present in SARK schema; **empty** on sampled fixtures |
| Table `threat` | Yes (DB) | Sampled empty; legacy UI noise |
| Host `/etc/shorewall/pbx3_rules` (custom ACCEPTs) | **No** | Not in backup; lives only on the old box |
| fail2ban ignoreip | **No** | Host-local |

ETL **v2** (`python/sources/sark/transform.py`) still has identity `TABLE_MAP` entries for `shorewall_blacklist` / `shorewall_whitelist`, but **current pbx3 schema has no such tables** — those copies are dead weight (skip or fail depending on loader strictness). Help text / schema comments still say Shorewall.

### 10.2 Locks for migrate + UFW

| # | Lock |
|---|------|
| **M1** | ETL does **not** recreate Shorewall rule files. Post-load firewall = **UFW profile baseline** on the target home (fleet or solo), same as greenfield. |
| **M2** | Force or normalize **`globals.fqdninspect='NO'`** on migrate output (or document operator must turn off). Do **not** expect STRING inspection after UFW. Fleet customers get SIP safety from **SBC + “5060 from SBC”**; solo customers get **LAN/source allows + strong creds**. |
| **M3** | **`sipflood`:** either map to a future UFW rate-limit (Phase 5) or force **`NO`** and drop Shorewall limit templates. Do not leave a YES that no longer applies any rules. |
| **M4** | Drop `shorewall_blacklist` / `shorewall_whitelist` from ETL `TABLE_MAP` (or map into a documented UFW deny/allow sidecar **only if** fixtures show non-empty lists worth preserving). Sampled customer zips were empty — **default = drop**. |
| **M5** | Custom host Shorewall rules are an **operator checklist** item (MkDocs migrate runbook): re-enter needed allows in the new Firewall SPA / UFW. No automatic dialect translator. |
| **M6** | **`clid_blacklist`:** ignore for SARK migrate (stub never used in production). Greenfield tenant CLID blacklist is a **separate** product track — **`CLID_BLACKLIST_REQUIREMENTS.md`** (tenant-scoped; mutate requires auth; no open feature key in v1). Not host firewall. |

### 10.3 ETL / docs work when UFW ships

1. **`sark-to-pbx3`:** M2–M4 in v2 transform + REQUIREMENTS lock row; fixture assert `fqdninspect=NO` (or explicit migrate report warning).  
2. **MkDocs migrate / first-boot:** “Firewall is UFW baseline; old Shorewall custom rules and fqdninspect are not ported.”  
3. **Product help (`tt_help_core`):** rewrite `fqdninspect` / firewall help away from Shorewall manpage links when SPA hides the control.  
4. Optional later: if a customer zip has non-empty shorewall_* lists, add a one-off report (`migrate --firewall-report`) listing IPs for manual UFW entry — not a silent import into a missing table.

---

## 11. Non-goals

- Replacing **EC2 security groups** or Shorewall on non-home roles unrelated to this track.
- Porting STRING / `fqdninspect` onto UFW or nft (explicitly abandoned for fleet).
- Auto-translating arbitrary Shorewall rule text from customer hosts (not in backup).
- firewalld.
- Making the SPA a full nftables IDE.
- Changing SBC edge firewall as part of this track (SBC already UFW-shaped in lab).

---

## 12. Suggested implement order when scheduled

1. Phase 1 lab proof on a disposable home.  
2. Phase 2 scripts + installer + fail2ban + LE.  
3. Phase 3 API/SPA.  
4. Phase 4 package purge + docs.  
5. **ETL M2–M4** (can parallel Phase 2–3; must land before marketing “migrate to UFW homes”).  
6. Phase 5 only if soak demands it.

Track as product TODO open item pointing here; tip/host gossip stays in **`~/GiT/pbx3-ops/TODO_OPS.md`**.
