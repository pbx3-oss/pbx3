# Call type inventory — pathways & how we test them

**Status:** Living checklist 2026-07-27.  
**Sources of truth (code):** GenAst `GenClass.php`, `extensions_presets.conf`, CAGI `agi_cmd_table` / handlers.  
**Test homes:** L0 = **pbx3cagi** `make test` · L1 = **`workingdocs/call-tests/`** (SIPp) · L2 = soak · L3 = operator PSTN/phone.  
**Related:** **`CALL_TEST_STRATEGY.md`** (layers / build order) · **`CRITICAL_PATH_TEST_PACK.md`** Pack B.

This is the **full call-type map**. `CALL_TEST_STRATEGY` §5 is only the **near-term L1** subset.

### Test column legend

| Code | Meaning |
|------|---------|
| **L0** | Offline AGI harness scenario id (or —) |
| **L1** | SIPp recipe id under `call-tests/scenarios/` (or —) |
| **L3** | Manual lab / PSTN checklist |
| **—** | No automated coverage yet |
| **n/a** | Not a SIP pathway (prompt/BLF only) or not applicable |

---

## 1. Major call pathways (media / routing)

These are the “big” call types operators care about.

| ID | What happens | Entry | Engine | L0 | L1 | L3 |
|----|--------------|-------|--------|----|----|-----|
| `maj-in-open-ext` | DID → openroute → extension ring/answer | SBC VIP DID | Ingress → CheckState → LepDial → Dial → PostDial | `cfim-none` (partial) | **`in-open-ext`** (green 2026-07-27) | PSTN smoke |
| `maj-in-closed` | DID → closeroute (IVR/ext/queue) | SBC VIP DID | Ingress → CheckState CLOSED | — | **`in-closed-ivr-or-dest`**, **`feat-master-closed`** (recipes; lab pending) | yes |
| `maj-in-holiday` | Holiday `routeoverride` → closed-like dest | DID | CheckState / CheckTime | — | `feat-holiday-override` (planned) | yes |
| `maj-in-cfim-local` | Immediate forward to local ext | DID / ring | LepDial CF path | **`cfim-local`** | **`in-cfim-local`** (recipe) | yes |
| `maj-in-cfim-external` | Immediate forward off-box | DID / ring | LepDial + OutTrunk/Egress | **`cfim-external`** | `in-cfim-external` (planned) | yes |
| `maj-in-cfbs` | Forward on busy/noanswer | Ring fail | PostDial / CFBS AstDB | — | — | yes |
| `maj-in-dnd-vm` | DND → voicemail / CFVM path | Ring | LepDial CFVMail | — | — | yes |
| `maj-in-queue` | DID/openroute → Queue → agent | DID / queue ext | Queue + `Q{ext}` Dial AGI | **`dial-queue-predial`** | **`in-queue-answer`** (recipe); cancel → `in-queue-cancel-vm` planned | yes |
| `maj-in-ivr` | DID/openroute → IVR menus | DID / IVR ext | AGI `IVR` / `IVRAction` | — | — | yes |
| `maj-in-greeting` | Playback-only greeting dest | DID / greeting key | dialplan Playback | — | — | yes |
| `maj-ext-to-ext` | Station A → station B (same tenant) | Phone | LepDial → Dial | — | — | **primary lab** |
| `maj-ext-to-ext-sbc` | Multi-tenant A ↔ B via SBC AoR | Phone | fleet PrepDial FQDN | — | `in-multi-tenant-a-b` (planned) | **lab done historically** |
| `maj-out-trunk` | Ext → OutTrunk match → carrier/Egress | Phone | AGI `OutTrunk` | — | `out-egress-ok` (planned) | yes |
| `maj-out-route` | Ext → OutRoute | Phone | AGI `OutRoute` | — | — | yes |
| `maj-out-busy-reject` | Far end 486/603 / cancel | Outbound | PostDial | **`postdial-noanswer-vm`**, **`postdial-answer-noop`** | `out-busy-or-reject` (planned) | yes |
| `maj-lepdial-fleet` | Fleet dial string / outbound_proxy | Ext dial | LepDial PrepDial | **`lepdial-fleet`** | — | yes |
| `maj-page` | Page group (queue strategy `page`) | Page/queue key | Queue page | — | — | yes |
| `maj-park` | Park / orbit retrieve | park lot / features | `genParks` + features | — | — | yes |
| `maj-pickup` | Directed pickup `_*8XX.` / `*8` | Phone | dialplan Pickup | — | — | yes |
| `maj-conf` | Meetme / ConfBridge room | room ext | ConfBridge | — | — | yes |
| `maj-vm-leave` | Leave voicemail (`*{ext}`, timeout) | PostDial / `*{ext}` | Voicemail() | **`postdial-noanswer-vm`** (partial) | — | yes |
| `maj-vm-retrieve` | Check own / general mailbox | `*50*` / `*51*` / `vm{ext}` | VoiceMailMain | — | — | yes |
| `maj-queue-agent-local` | Queue Local channel callback | Queue | AGI argc==1 SetRecord | — | — | yes |

**Day-parts (future):** mode/profile scenarios (`in-mode-lunch`, …) land with **`TIME_BASED_ROUTING_REQUIREMENTS.md`** — until then open/close covers the binary fork.

---

## 2. Feature shortcodes (`*NN*` / patterns)

### 2.1 RCS / CAGI feature codes (`extensions_presets.conf` → SYSAGI)

| Code | Pattern | Behaviour | CAGI | L0 | L1 | L3 |
|------|---------|-----------|------|----|----|-----|
| DND on | `_*18*` | CF to VM / DND on | `CFVMailSet` (18) | — | — | phone |
| DND off | `_*19*` | DND off | `CFVMailSet` (19) | — | — | phone |
| DND toggle | `_*20*` | Toggle DND | `CFVMailToggle` (20) | — | — | phone |
| CFIM on | `_*21*XX.` | Set CFIM dest | `CFToggle` (21) | — | — | phone |
| CFIM off | `_*21*` | Clear CFIM | `CFToggle` (21) | — | — | phone |
| CFBS on | `_*22*XX.` | Set CFBS dest | `CFToggle` (22) | — | — | phone |
| CFBS off | `_*22*` | Clear CFBS | `CFToggle` (22) | — | — | phone |
| CF clear | `_*23*` | Clear forwards | `CFOff` (23) | — | — | phone |
| Ring delay | `_*26[*]…` | Set ring delay | `SetRingDelay` (26) | — | — | phone |
| Follow-me | (CAGI 27; dialplan TBD / legacy) | FollowMe | `FollowMe` (27) | — | — | phone |
| Rec greeting | `_*60*XXXX` | Record greeting | `RecGreet` (60) | — | — | phone |
| Agent pause | `_*63*` | Pause | `AgentPause` (63) | — | — | phone |
| Agent unpause | `_*64*` | Unpause | `AgentUnpause` (64) | — | — | phone |
| Agent login | `_*65*` | Login | `AgentLogin` (65) | — | — | phone |
| Agent logout | `_*66*` | Logout | `AgentLogout` (66) | — | — | phone |
| ChanSpy whisper | `_*67*XXX(X)` | Whisper spy | `ChanSpyWhisper` (67) | — | — | phone *(multi-tenant debt)* |
| ChanSpy | `_*68*XXX(X)` | Spy | `ChanSpy` (68) | — | — | phone *(multi-tenant debt)* |

### 2.2 Dialplan-only utilities (presets / GenAst)

| Code | Behaviour | L0 | L1 | L3 |
|------|-----------|----|----|-----|
| `*52*` | Echo test | n/a | — | phone |
| `*55*` | Say time/date | n/a | — | phone |
| `*56*` | Say own extension digits | n/a | — | phone |
| `*50*` | VoiceMailMain (own mailbox) | n/a | — | phone |
| `*51*` | VoiceMailMain (general) | n/a | — | phone |
| `*{ext}` | Leave VM for that ext | — | — | phone |
| `vm{ext}` | VM main for that mailbox + hint | n/a | — | phone |
| `_*8XX.` | Directed pickup | n/a | — | phone |
| `*8` | `pickupexten` (features) | n/a | — | phone |
| `_*24*` / `_*24*XXX(X)` | Wakeup (`kwakeup`) — **legacy / needs PJSIP work** | n/a | — | avoid / manual |
| `_***XXX(X)` | Dial PJSIP/SIP by stripped digits (legacy intercom style) | — | — | phone |

### 2.3 Open / close force (GenAst — not CAGI feature table)

| Code | Behaviour | L0 | L1 | L3 |
|------|-----------|----|----|-----|
| `*30*` | Master OPEN (AUTH → `STAT/OCSTAT=AUTO`) | n/a | feeds `feat-master-closed` inverse | phone |
| `*31*` | Master CLOSED | n/a | **`feat-master-closed`** setup | phone |
| `MASTER` BLF | Toggle master open/close | n/a | — | phone |
| Tenant BLF `{shortuid}` | Toggle tenant OCSTAT | n/a | — | phone |
| `*33*` | Tenant open (GenAst) | n/a | — | phone |
| `*34*` | Tenant close (GenAst) | n/a | — | phone |

### 2.4 NANP vertical-service aliases (map onto §2.1)

| NANP | Maps to | Notes |
|------|---------|--------|
| `*60` | `*55*` | Say time |
| `*65` | `*56*` | Say ext |
| `_*72X.` | CFIM on (`*21*…`) | |
| `*73` | CFIM off | |
| `_*77XXXX` | Play greeting (`*60*…`) | |
| `*78` / `*79` | DND on / off | |
| `_*90X.` / `*91` | CFBS on / off | |
| `*97` | → `*50*` (comment in presets says DND — **verify**; dialplan Goto `*50*`) | |
| `*98` | → `*52*` echo | |
| `_*99XXXX` | AGI `*61*…` — **no handler 61 in current `agi_cmd_table`** | treat as **debt / dead** until confirmed |

---

## 3. Named AGI commands (GenAst → CAGI)

| Cmd | Typical dialplan use | L0 today | L1 today |
|-----|----------------------|----------|----------|
| `Ingress` | DID `inroutes` | — | via `in-open-ext` stack |
| `LepDial` | Extension short-run pre-dial | `lepdial-fleet` | via ext answer |
| `Dial` | Queue agent `Q{ext}` PrepDial | `dial-queue-predial` | `in-queue-answer` |
| `PostDial` | After Dial fail/answer | `postdial-*` | — |
| `IVR` | IVR extension | — | — |
| `OutTrunk` | Trunk match outbound | — | planned `out-egress-ok` |
| `OutRoute` | Route object outbound | — | — |
| `OutQmt` | Queue member / agent path | — | — |

---

## 4. Coverage summary (2026-07-27)

| Bucket | Automated? | Notes |
|--------|------------|--------|
| Simple inbound open → ext | **L1 green** + partial L0 | Keep as smoke every dial-locus / SBC change |
| CFIM local/external logic | **L0** | L1 recipes for local; external still planned |
| PostDial answer / VM | **L0** | |
| Queue predial | **L0** + L1 recipe | Need green-lab on golden Q |
| Closed / master closed | L1 recipes | Need lab state + green |
| IVR / Page / Park / Conf / Pickup | **L3 only** | Add L1 only if regression-prone |
| Almost all `*NN*` feature codes | **L3 only** | L0 fixtures beat SIPp for AstDB side-effects; SIPp UAC for “code answered + playback” is optional later |
| Outbound Egress / multi-tenant | L3 + historical lab | L1 IDs planned |
| Wakeup / `*99`→61 | **debt** | Do not advertise as supported until fixed |

---

## 5. How to extend this list

1. New GenAst exten or presets row → add a row here in the same PR/docs tip.  
2. New CAGI handler / `agi_cmd_table` entry → §2 or §3.  
3. Prefer **L0** when the assert is dial-string / AstDB / CF decision; **L1** when the assert is “real SIP through SBC+Asterisk”; **L3** when carrier or human UX.  
4. Stable IDs (`maj-…`, shortcode names, L1 ids) are what Pack B and handoffs should cite.

---

## 6. Revision

| Date | Note |
|------|------|
| 2026-07-27 | Initial inventory from GenAst + presets + CAGI cmd table + existing L0/L1. |
