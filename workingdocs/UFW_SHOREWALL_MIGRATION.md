# Home firewall — Shorewall → UFW migration

**Status:** Direction locked **2026-08-24**; **Phases 1–4** on branch **`ufw-phase1`** (2026-08-25). Phase 5 optional.  
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
| **F1** | **Fleet install baseline is fixed and small** (default deny inbound; only the ports below). Not a free-form Shorewall dialect at install. |
| **F2** | **`fqdninspect`:** retire as a live fleet security control. Panel/API may hide or no-op on fleet; solo/direct may keep a transitional period then drop. |
| **F3** | **RTP 10000–20000/udp** open to the world (RTP bypass + roaming phones). |
| **F4** | **fail2ban** banaction moves from `shorewall` → **`ufw`**. |
| **F5** | SPA Firewall panel columns (v1): **proto** (`tcp` \| `udp` \| `icmp` \| `all`), **port** (or range; N/A for icmp as needed), **source** (`any` / IP / CIDR), **comment**. No Shorewall ACTION/`$FW`/sport/origdest/**connrate**/Raw. LE `:80` may be managed/read-only. Install baseline does not depend on SPA. |
| **F6** | LE temporary **:80** open/close via UFW managed allow/delete (cert scripts), not a permanent open port. |
| **F7** | Do **not** run Shorewall and UFW together. |
| **F8** | EC2/security groups remain a **second layer**; UFW is host policy. |
| **F10** | **Sources are literal only** (`any`, IP, CIDR). No `$LAN` / `$SBC` shorthand. **Fleet SIP:** concrete SBC address(es). **Solo / singleton baseline:** **22, 44300, 5060/5061, and RTP 10000:20000** all default to the **detected LAN CIDR** from setip (typically `192.168.x.0/24`). Operator may widen in the Firewall panel (e.g. remote ops CIDR). Drop Shorewall **connrate** for now. |
| **F11** | **Fleet only:** **SSH :22 and API :44300** stay **`from=any` after install** (bootstrap must not lock the operator out over the public net). **Warn** in the package installer summary, lab `install-home-host` summary, and Firewall SPA while those Sources are still `any`. Do not auto-tighten fleet at install. **Solo** uses LAN CIDR for those ports (F10) — no “wide open” warn unless the operator widens to `any`. Cloud SG is a second layer (F8). |

### Fleet home — standard allow set (locked 2026-08-25)

| Port | Proto | Source | Notes |
|------|-------|--------|-------|
| **22** | tcp | anywhere | SSH — **install leaves `from=any`; operator should narrow** (Firewall panel + installer warn) |
| **44300** | tcp | anywhere | API / SPA — **same: open after install; narrow when safe** |
| **5060** | udp + tcp | **SBC IP(s) only** | SIP signalling |
| **5061** | tcp | **SBC IP(s) only** | SIP TLS (same restriction) |
| **10000:20000** | udp | anywhere | RTP |
| **80** | tcp | anywhere while LE needs it | Opened/closed by Let’s Encrypt scripts only |
| **Everything else** | — | — | **Closed** (default deny) — including **:443** (no public webserver; API is **:44300** only) |

No permanent :80. No :443. No fleet :8089 on the home (WSS at edge). No LAN SIP, LDAP, IAX, or STRING/`fqdninspect` in the fleet baseline.

---

## 4. Target posture (rule sets)

### 4.1 Fleet home (primary)

Apply **§3 standard allow set** at install (`ufw-apply-baseline.sh` profile `fleet`). SBC address(es) from env / onboard / provision artifact (pick one at implement and document).

Prefer **idempotent rewrite** of a `# pbx3-managed` block so Provision edge IP changes do not stack duplicate allows.

### 4.2 Solo / direct (no SBC) — singleton

Bootstrap (`ufw-apply-baseline.sh solo`): **22, 44300, 5060/5061, and RTP 10000:20000** all from the **detected LAN CIDR** (setip / `/etc/pbx3/lan.cidr`, typically `192.168.x.0/24`). Optional `:8089` WSS (if enabled) same LAN Source. LE `:80` still ephemeral via cert scripts. Panel can widen `from` later (e.g. add ops CIDR). Default deny everything else.

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

- [x] Choose UFW; record locks F0–F9 and **fleet standard allow set** (2026-08-25).
- [x] SBC IP list source (Phase 2): **`PBX3_UFW_SBC_IPS`** (preferred) or literal **`PBX3_SBC_EGRESS_HOST`** in `/opt/pbx3api/.env`. Hostname-only values are skipped (must be IP/CIDR).

### Phase 1 — Lab proof (no SPA rewrite yet)

1. Rebuild or wipe lab home (`.31`) if convenient — no production tenants.
2. Disable shorewall{,6}; enable UFW default deny; apply **§3 standard allow set** with lab SBC IP.
3. Prove: desk REGISTER via SBC, extension call + RTP, SPA `:44300`, fail2ban once, LE open/close :80.

**Scripts (branch `ufw-phase1`):** `scripts/ufw-apply-baseline.sh` · LE `le-port80-*.sh` UFW path · fail2ban `banaction=ufw`.  
**SBC IP source (lab):** `PBX3_UFW_SBC_IPS` or literal `PBX3_SBC_EGRESS_HOST` in `/opt/pbx3api/.env` (Phase 0 confirm still open for cloud EIP list).

**Exit:** written lab notes in ops TODO; no package Depends/installer cutover yet (Phase 2).

- [x] Lab `.31` apply (2026-08-25): Shorewall stopped/disabled; UFW active; fleet allow set from `192.168.1.85`; post-cutover desk REGISTER via SBC; API `:44300` 200; LE open/close; fail2ban `action=ufw` wired; **101→102 call/RTP OK**. Live ban smoke optional. Notes: **`~/GiT/pbx3-ops/TODO_OPS.md`**.

### Phase 2 — pbx3 package + installer

1. Add `scripts/ufw-apply-baseline.sh` (idempotent; profiles `fleet` | `solo`).
2. Wire installer: Depends `ufw`; stop shipping Shorewall templates as live config; migrate-or-purge on upgrade.
3. Replace LE port-80 scripts; setip LAN for solo; fail2ban → `ufw`.
4. Remove or gate FQDN inline path (`fqdninspect=NO` default; skip update on fleet import — already decided in mobility design).
5. Package bump when ready for fleet roll.

- [x] **2026-08-25 (`ufw-phase1`):** Depends `ufw` (drop shorewall*); installer `ufw-apply-baseline.sh`; LE + fail2ban; setip `/etc/pbx3/lan.cidr`; NetHelper/update-fqdn-inline UFW path. Shorewall templates remain in tree until Phase 4 purge. **Package floor:** tip-only until rebuild → **`0.0.6-1`**.

### Phase 3 — API + SPA

1. Declarative allow-list file (JSON or simple line DSL) matching §3 columns.
2. `FirewallController` GET/POST/PUT → that file + `ufw-apply` via syscmd.
3. **Simplify `FirewallView`:** drop Shorewall parser (action/source/dest/`$FW`/sport/connrate + Raw mode). One table: allow rows for the standard set; optional add-row for rare extras. Unify IPv4/IPv6 under UFW (or hide v6 until needed).
4. ICMP syscommand: reimplement or drop from UI until needed.
5. Docs / help: remove Shorewall manpage copy.

- [x] **2026-08-25 (`ufw-phase1`):** HoR `/etc/pbx3/firewall.allows.json` · API `GET/POST/PUT firewalls` · SPA table proto/port/source/comment · ICMP under UFW = default allow (toggle parked) · logs list `ufw.log`.

### Phase 4 — Retire Shorewall entirely

1. Remove `shorewall*` from Depends and tree templates (or archive under `workingdocs/archive/` if needed for archaeology).
2. Delete dead PHP (inline FQDN writers), prerm links, help text, log names.
3. Greenfield install must never install Shorewall.
4. Upgrade path: one-shot “detect Shorewall → apply UFW baseline → disable Shorewall” in postinst/installer.

- [x] **2026-08-25 (`ufw-phase1`):** Templates/rsyslog/logrotate/`shorewall.local` removed; `firewall-reload.php`; NetHelper UFW-only; LE UFW-only; sudoers `ufw`; installer `apt-get remove shorewall*`; help UPDATEs. Git history retains archaeology. **Next built .deb = `pbx3 0.0.6-1`** (consolidates Phases 1–4; 0.0.5-7/8 never packaged).

### Phase 5 — Optional harden (not blocking)

- RTP UDP per-source rate-limit (UFW limit or small nft snippet beside UFW) — **parked** unless soak shows abuse (hard to pick a sane per-source pps that survives dense NAT).
- Tighten SSH/API source CIDRs for cloud images — **fleet default stays open (F11)**; installer/SPA **warn** while `any`. **Solo** defaults to LAN (F10). Auto-tighten fleet at install is not the product path.
- **SBC allow auto-refresh** on Provision edge / EIP change — **parked until pain (2026-08-25).** Easy half: re-sync SIP `from` rows from `PBX3_UFW_SBC_IPS` / literal `PBX3_SBC_EGRESS_HOST` on apply. Hard half: nothing today pushes a new SBC EIP onto the home (Provision edge updates **SBC** fail2ban whitelist for the **home** IP, not the reverse; hostname-only egress is skipped). Until an EIP/VIP change actually breaks fleet SIP on a live box, operator edits Source (or `.env` + re-bootstrap) is enough.

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

**Description / comment:** UFW supports this natively — `ufw allow … comment 'SBC SIP'`. Comments show in `ufw status numbered` (trailing `# …`). Updating a rule with a new `comment` changes the text; `comment ''` clears it.

**HoR for the SPA:** keep `comment` on the **declarative allow-list file** (JSON/DSL), and have `ufw-apply` emit `comment '…'` on each rule. Do not scrape `ufw status` as the editor source of truth (fragile parse). Use a stable comment (e.g. `LE renewal (managed)`) so LE open/close can find/delete the ephemeral `:80` rule the same way Shorewall used a marker line.

**POST** validates and writes the managed file (does not apply).  
**PUT** (restart/apply) runs `ufw-apply-baseline.sh` after syncing managed rules.

Do **not** expose raw `iptables`/`nft` in v1. Advanced SSH remains for break-glass.

---

## 8. Upgrade / coexistence rules

1. Prefer **greenfield / rebuild** over translating old `pbx3_rules` (F9). Lab wipe OK.
2. Still apply baseline **before** relying on default deny in installer scripts (order: allow 22 + 44300 + … then enable) so a half-finished install does not strand SSH mid-script — not a “existing customer” concern.
3. Cloud nodes: SG still admits needed ports; UFW is host policy on top.

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

ETL **v2** drops `shorewall_blacklist` / `shorewall_whitelist` from `TABLE_MAP` (**M4**, 2026-08-25). Help text / schema comments still say Shorewall until product help rewrite.

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

1. **`sark-to-pbx3`:** M2–M4 in v2 transform + REQUIREMENTS lock row — **done 2026-08-25** (`REQUIREMENTS` **#13**; force `fqdninspect`/`sipflood` **NO**; drop shorewall_* + clid_blacklist from map). Fixture assert optional when next offline migrate run.  
2. ~~**MkDocs migrate / first-boot:**~~ — **done 2026-08-25** in **`pbx3-docs`** `admin/firewall.md` (UFW baseline + SARK migrate note); Shorewall wording cleared on LE / login / cert / globals / API reference.  
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
5. ~~**ETL M2–M4**~~ — **done 2026-08-25** in **`aelintra/sark-to-pbx3`**.  
6. Phase 5 only if soak demands it.

Track as product TODO open item pointing here; tip/host gossip stays in **`~/GiT/pbx3-ops/TODO_OPS.md`**.
