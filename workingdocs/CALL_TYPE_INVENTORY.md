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

### Attendance legend (**Attend**)

| Code | Meaning |
|------|---------|
| **U** | **Unattended** — can run hands-off (CI / cron / `make test`) with no phone answer and no listening |
| **H** | **Human** — someone must act during the run (answer/ring, hear prompt, DTMF, second phone, PSTN) |
| **H-setup** | Human prepares lab state once (CFIM, CLOSED, queue agents, Peer allow); the SIP assert may still be **H** today if a phone must answer |
| **U later** | Could become unattended with SIPp UAS / phone auto-answer / AMI force-answer — **not** how we run it today |

**Rule of thumb today:** all **L0** = **U**. All current **L1 VIP** recipes = **H** (or H-setup + H) unless an auto-answer endpoint is on the target. All **L3** = **H**.

---

## 1. Major call pathways (media / routing)

These are the “big” call types operators care about.

| ID | What happens | L0 | L1 | L3 | Attend (today) |
|----|--------------|----|----|-----|----------------|
| `maj-in-open-ext` | DID → openroute → extension ring/answer | `cfim-none` (partial) **U** | **`in-open-ext`** green | PSTN smoke | **L0: U** · **L1: H** (1000 must answer / auto-answer) · **L3: H** |
| `maj-in-closed` | DID → closeroute | — | **`in-closed-*`**, **`feat-master-closed`** recipes | yes | **H-setup** (force CLOSED) + **H** (answer closeroute) · **U later** |
| `maj-in-holiday` | Holiday override | — | planned | yes | **H-setup** + **H** |
| `maj-in-cfim-local` | CFIM → local ext | **`cfim-local`** **U** | **`in-cfim-local`** recipe | yes | **L0: U** · **L1: H-setup** (set CFIM) + **H** (answer target) |
| `maj-in-cfim-external` | CFIM off-box | **`cfim-external`** **U** | planned | yes | **L0: U** · live path **H** / PSTN |
| `maj-in-cfbs` | Forward busy/noanswer | — | — | yes | **H** |
| `maj-in-dnd-vm` | DND → VM | — | — | yes | **H** |
| `maj-in-queue` | Queue → agent | **`dial-queue-predial`** **U** | **`in-queue-answer`** recipe | yes | **L0: U** · **L1: H-setup** (queue/agents) + **H** (agent answer) |
| `maj-in-ivr` | IVR menus | — | — | yes | **H** (DTMF + listen) |
| `maj-in-greeting` | Playback greeting | — | — | yes | **H** (or **U later** if SIPp only checks 200 + RTP) |
| `maj-ext-to-ext` | Station ↔ station same tenant | — | — | primary lab | **H** (two phones) · **U later** (dual SIPp) |
| `maj-ext-to-ext-sbc` | Multi-tenant via SBC AoR | — | planned | historical lab | **H** · **U later** (dual SIPp) |
| `maj-out-trunk` | OutTrunk / Egress | — | planned | yes | **H** (or **U later** with SIPp UAS peer) |
| `maj-out-route` | OutRoute | — | — | yes | **H** |
| `maj-out-busy-reject` | Far-end reject / cancel | **`postdial-*`** **U** | planned | yes | **L0: U** · live **H** / **U later** |
| `maj-lepdial-fleet` | Fleet dial string | **`lepdial-fleet`** **U** | — | yes | **L0: U** · live **H** |
| `maj-page` | Page group | — | — | yes | **H** |
| `maj-park` | Park / retrieve | — | — | yes | **H** |
| `maj-pickup` | Directed pickup | — | — | yes | **H** |
| `maj-conf` | Conference | — | — | yes | **H** |
| `maj-vm-leave` | Leave voicemail | **`postdial-noanswer-vm`** partial **U** | — | yes | **L0: U** · live **H** (record/listen) |
| `maj-vm-retrieve` | Check mailbox | — | — | yes | **H** |
| `maj-queue-agent-local` | Queue Local callback | — | — | yes | **H** |

**Entry / engine (unchanged detail):** VIP DID via SBC for inbound majors; phone for station/outbound; GenAst + CAGI as in prior revision. Day-parts deferred to **`TIME_BASED_ROUTING_REQUIREMENTS.md`**.

---

## 2. Feature shortcodes (`*NN*` / patterns)

**Attendance:** every shortcode row below is **H** today (dial from a registered phone, hear playback / confirm BLF or AstDB by eye).  
**Unattended path:** add **L0** fixtures that drive the same CAGI handler with mock AstDB (no phone) — none of these have L0 yet except where CFIM/DND behaviour is covered indirectly by CFIM LepDial scenarios.

### 2.1 RCS / CAGI feature codes (`extensions_presets.conf` → SYSAGI)

| Code | Pattern | Behaviour | CAGI | Attend |
|------|---------|-----------|------|--------|
| DND on | `_*18*` | CF to VM / DND on | `CFVMailSet` (18) | **H** |
| DND off | `_*19*` | DND off | `CFVMailSet` (19) | **H** |
| DND toggle | `_*20*` | Toggle DND | `CFVMailToggle` (20) | **H** |
| CFIM on | `_*21*XX.` | Set CFIM dest | `CFToggle` (21) | **H** |
| CFIM off | `_*21*` | Clear CFIM | `CFToggle` (21) | **H** |
| CFBS on | `_*22*XX.` | Set CFBS dest | `CFToggle` (22) | **H** |
| CFBS off | `_*22*` | Clear CFBS | `CFToggle` (22) | **H** |
| CF clear | `_*23*` | Clear forwards | `CFOff` (23) | **H** |
| Ring delay | `_*26[*]…` | Set ring delay | `SetRingDelay` (26) | **H** |
| Follow-me | (CAGI 27) | FollowMe | `FollowMe` (27) | **H** |
| Rec greeting | `_*60*XXXX` | Record greeting | `RecGreet` (60) | **H** |
| Agent pause/unpause | `_*63*` / `_*64*` | Pause / unpause | 63 / 64 | **H** |
| Agent login/out | `_*65*` / `_*66*` | Login / logout | 65 / 66 | **H** |
| ChanSpy (whisper) | `_*67*` / `_*68*` | Spy | 67 / 68 | **H** *(multi-tenant debt)* |

### 2.2 Dialplan-only utilities

| Code | Behaviour | Attend |
|------|-----------|--------|
| `*52*` echo · `*55*` time · `*56*` say ext | Playback UX | **H** (must hear) |
| `*50*` / `*51*` / `vm{ext}` / `*{ext}` | VM main / leave | **H** |
| `_*8XX.` / `*8` | Pickup | **H** (two parties) |
| `_*24*` wakeup | Legacy / PJSIP debt | **H** / avoid |
| `_***XXX(X)` | Legacy strip-dial | **H** |

### 2.3 Open / close force

| Code | Behaviour | Attend |
|------|-----------|--------|
| `*30*` / `*31*` / `MASTER` BLF | Master open/close | **H** (auth + hear) — also used as **H-setup** for closed L1 |
| Tenant BLF / `*33*` / `*34*` | Tenant OCSTAT | **H** / **H-setup** |

### 2.4 NANP aliases

Same attendance as the mapped RCS code (**H**). `_*99XXXX` → `*61*` = debt / do not test as supported.

---

## 3. Named AGI commands — attendance by layer

| Cmd | L0 today | L1 today | Attend |
|-----|----------|----------|--------|
| `Ingress` | — | via `in-open-ext` | L1 **H** |
| `LepDial` | `lepdial-fleet` **U** | via ext answer | L0 **U** · live **H** |
| `Dial` | `dial-queue-predial` **U** | `in-queue-answer` | L0 **U** · L1 **H** |
| `PostDial` | `postdial-*` **U** | — | **U** |
| `IVR` | — | — | live **H** |
| `OutTrunk` / `OutRoute` / `OutQmt` | — | planned / — | live **H** · **U later** |

---

## 4. Unattended vs human — rollup (2026-07-27)

### Can run unattended **now**

| What | How |
|------|-----|
| All existing CAGI L0 scenarios | `cd pbx3cagi-…/csource && make test` (CFIM local/external/none, postdial, queue predial, lepdial-fleet) |
| (None of the VIP SIPp L1 pack) | Still need a human or auto-answer phone on the ringing dest |

### Need a human **now**

| What | Why |
|------|-----|
| `in-open-ext` and sibling L1 recipes | SIPp waits for **200**; golden phone must answer (or auto-answer) |
| L1 with CFIM / CLOSED / queue | Plus **H-setup** of AstDB / day state / agents |
| All `*NN*` feature codes, BLF open/close | Dial + hear prompt / confirm state on device |
| IVR, page, park, pickup, conf, VM retrieve | Interactive or multi-party |
| PSTN L3 / Magrathea-Twilio matrix | Carrier + human |
| Ext↔ext / multi-tenant AoR | Two endpoints (until dual-SIPp) |

### Path to more unattended L1 (not built)

1. Auto-answer lab phone **or** SIPp UAS registered as the target ext.  
2. AMI/scripts for **H-setup** (set/clear CFIM, OCSTAT, queue members) so a cron can arm state.  
3. Then VIP UAC scenarios become **U** for signalling-only asserts (200/BYE); media quality stays **H**/L2 optional.

---

## 5. How to extend this list

1. New GenAst exten or presets row → add a row here in the same tip.  
2. New CAGI handler → §2 or §3; mark **Attend**.  
3. Prefer **L0 (U)** for dial-string / AstDB / CF decisions; **L1** for real SIP; **L3 (H)** for carrier / UX.  
4. When an L1 recipe becomes auto-answer capable, flip Attend from **H** → **U** and note the date.

---

## 6. Revision

| Date | Note |
|------|------|
| 2026-07-27 | Initial inventory from GenAst + presets + CAGI cmd table + existing L0/L1. |
| 2026-07-27 | Attendance: **U** / **H** / **H-setup** / **U later** on majors, shortcodes, rollup. |
