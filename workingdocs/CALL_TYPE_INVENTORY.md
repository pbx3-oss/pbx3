# Call type inventory — pathways & how we test them

**Status:** Living checklist 2026-07-27.  
**Sources of truth (code):** GenAst `GenClass.php`, `extensions_presets.conf`, CAGI `agi_cmd_table` / handlers.  
**Test homes:** L0 = **pbx3cagi** `make test` · L1 = **[sipplab](https://github.com/aelintra/sipplabs)** (SIPp) · L2 = soak · L3 = operator PSTN/phone.  
Stub redirect: **`workingdocs/call-tests/README.md`**.  
**Related:** **`CALL_TEST_STRATEGY.md`** (layers / build order) · **`CRITICAL_PATH_TEST_PACK.md`** Pack B.

This is the **full call-type map**. `CALL_TEST_STRATEGY` §5 is only the **near-term L1** subset.

### Test column legend

| Code | Meaning |
|------|---------|
| **L0** | Offline AGI harness scenario id (or —) |
| **L1** | SIPp recipe id under **sipplab** `scenarios/` (or —) |
| **L3** | Manual lab / PSTN checklist |
| **—** | No automated coverage yet |
| **n/a** | Not a SIP pathway (prompt/BLF only) or not applicable |

### Attendance legend (**Attend**)

| Code | Meaning |
|------|---------|
| **U** | **Unattended** — can run hands-off (CI / cron / `make test`) with no phone answer and no listening |
| **H** | **Human** — someone must act during the run (answer/ring, hear prompt, DTMF, second phone, PSTN) |
| **H-setup** | Human prepares lab state once (CFIM, CLOSED, queue agents, Peer allow); the SIP assert may still be **H** today if a phone must answer |
| **U later** | Could become unattended with SIPp UAS / phone auto-answer / AMI force-answer — see call-tests **Snom auto-answer** |

**Rule of thumb today:** all **L0** = **U**. **L1 VIP** = **U** if lab Snom (e.g. 1000) auto-answers; else **H**. All **L3** = **H**. SIPp scenarios send `Call-Info: Answer-After=0` + `Alert-Info` (Snom); those headers must appear on the **phone** INVITE (or use phone always-auto-answer) — carrier-leg alone is not enough on the DID/AGI path.

---

## 1. Major call pathways (media / routing)

These are the “big” call types operators care about.

| ID | What happens | L0 | L1 | L3 | Attend (today) |
|----|--------------|----|----|-----|----------------|
| `maj-in-open-ext` | DID → openroute → extension ring/answer | `cfim-none` (partial) **U** | **`in-open-ext`** green (BYE clean 2026-07-27) | PSTN smoke | **L0: U** · **L1: U** with Snom always-auto-answer (Ext alert unreliable on ring-group openroute) · **L3: H** |
| `maj-in-closed` | DID → closeroute | — | **`in-closed-*`**, **`feat-master-closed`** (pack) | yes | **L1: U** with catcher + lab-state · **L3: H** |
| `maj-in-holiday` | Holiday override | — | planned | yes | **H-setup** + **H** |
| `maj-in-cfim-local` | CFIM → local ext | **`cfim-local`** **U** | **`in-cfim-local`** recipe | yes | **L0: U** · **L1: H-setup** (set CFIM) + **H** (answer target) |
| `maj-in-phone-302-local` | Phone **302** → local ext (not AstDB CF*) | — | **`phone-302-local`** (catcher A 302 → B) | yes | **L1: U** with catcher UAS · distinct from CFIM |
| `maj-in-cfim-external` | CFIM off-box | **`cfim-external`** **U** | **`in-cfim-external`** (pack) | yes | **L0: U** · **L1: U** via SIPP_MAIN→Egress→upstream carrier DID/1000 |
| `maj-in-cfbs` | Forward busy/noanswer | — | — | yes | **H** |
| `maj-in-dnd-vm` | DND → VM | — | — | yes | **H** |
| `maj-in-queue` | Queue → agent | **`dial-queue-predial`** **U** | **`in-queue-answer`**, **`in-queue-cancel-vm`** (pack) | yes | **L0: U** · **L1: U** answer or agent-486→VM |
| `maj-in-ivr` | IVR menus | — | — | yes | **H** (DTMF + listen) |
| `maj-in-greeting` | Playback greeting | — | — | yes | **H** (or **U later** if SIPp only checks 200 + RTP) |
| `maj-ext-to-ext` | Station ↔ station same tenant | — | — | primary lab | **H** (two phones) · **U later** (dual SIPp) |
| `maj-ext-to-ext-sbc` | Multi-tenant via SBC AoR (domain discrimination) | — | **`in-multi-tenant-a-b`** (peer REG + DID→A) | historical lab | **L1: U** with peer catcher on 2nd tenant |
| `maj-site-dial` | Cross-tenant short dial (`site_code`+ext) | lab green (prefix path) | **`site-dial-a-b`** dual-host green — sipplab **`docs/examples/site-dial-lab.md`**; pack gate plan **`SITE_DIAL_PACK_GATE_PLAN.md`** (not executed) | — | **L1: U** Domain phones; not pack-gated yet; see **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** |
| `maj-out-trunk` | OutTrunk / Egress | — | **`out-egress-ok`** (pack) | yes | **L1: U** Local originate→Egress Up (SIPp phone UAC blocked: lab EIP = Peer 99) · **L3: H** |
| `maj-out-route` | OutRoute | — | via `out-egress-ok` (SIPP_MAIN) | yes | **L1: U** (same Local path) |
| `maj-out-busy-reject` | Far-end reject / cancel | **`postdial-*`** **U** | **`out-busy-or-reject`** (pack) | yes | **L0: U** · **L1: U** Local→catcher 486→PostDial VM/Busy |
| `maj-lepdial-fleet` | Fleet dial string | **`lepdial-fleet`** **U** | — | yes | **L0: U** · live **H** |
| `maj-page` | Page group | — | — | yes | **H** |
| `maj-park` | Park / retrieve | — | — | yes | **H** (golden 2026-09-26: `*5` + dial `901` + timeout comeback) |
| `maj-pickup` | Directed pickup `*8{ext}` + named call/pickup groups | — | **`pickup-directed-ok`**, **`pickup-group-deny`**, **`pickup-pjsip-config`** (sipplab `./run-pickup-pack.sh`) — req **`EXTENSION_NAMED_PICKUP_GROUPS.md`** § Lab acceptance; **lab green pending** | yes (BLF) | **U** (harness req; green pending) |
| `maj-conf` | Conference | — | — | yes | **H** |
| `maj-vm-leave` | Leave voicemail | **`postdial-noanswer-vm`** partial **U** | — | yes | **L0: U** · live **H** (record/listen) |
| `maj-vm-retrieve` | Check mailbox | — | — | yes | **H** |
| `maj-queue-agent-local` | Queue Local callback | — | — | yes | **H** |

**Entry / engine (unchanged detail):** VIP DID via SBC for inbound majors; phone for station/outbound; GenAst + CAGI as in prior revision. Day-parts deferred to **`TIME_BASED_ROUTING_REQUIREMENTS.md`**.

---

## 2. Feature shortcodes (`*NN*` / patterns)

**Attendance:** v1 unattended pack in **sipplab** `./run-feature-pack.sh` (AstDB + ChanSpy fingerprints) — see `sipplab/workingdocs/FEATURE_SHORTCODE_PACK.md`. Remaining codes stay **H** until a recipe exists.  
**L0 complement:** CAGI `make test` for handler logic; L1 pack proves presets → SYSAGI → side effect on a live home.

### 2.1 RCS / CAGI feature codes (`extensions_presets.conf` → SYSAGI)

| Code | Pattern | Behaviour | CAGI | Attend |
|------|---------|-----------|------|--------|
| DND on | `_*18*` | CF to VM / DND on | `CFVMailSet` (18) | **U** (2026-08-09 sipplab feature pack) |
| DND off | `_*19*` | DND off | `CFVMailSet` (19) | **U** (2026-08-09 sipplab feature pack) |
| DND toggle | `_*20*` | Toggle DND | `CFVMailToggle` (20) | **H** |
| CFIM on | `_*21*XX.` | Set CFIM dest | `CFToggle` (21) | **U** (2026-08-09 sipplab feature pack) |
| CFIM off | `_*21*` | Clear CFIM | `CFToggle` (21) | **U** (2026-08-09 sipplab feature pack) |
| CFBS on | `_*22*XX.` | Set CFBS dest | `CFToggle` (22) | **U** (2026-08-09 sipplab feature pack) |
| CFBS off | `_*22*` | Clear CFBS | `CFToggle` (22) | **U** (2026-08-09 sipplab feature pack) |
| CF clear | `_*23*` | Clear forwards | `CFOff` (23) | **U** (2026-08-09 sipplab feature pack) |
| Ring delay | `_*26[*]…` | Set ring delay | `SetRingDelay` (26) | **U** (2026-08-09 sipplab feature pack) |
| Follow-me | (CAGI 27) | FollowMe | `FollowMe` (27) | **H** |
| Rec greeting | `_*60*XXXX` | Record greeting | `RecGreet` (60) | **H** |
| Agent pause/unpause | `_*63*` / `_*64*` | Pause / unpause | 63 / 64 | **H** |
| Agent login/out | `_*65*` / `_*66*` | Login / logout | 65 / 66 | **H** |
| ChanSpy (whisper) | `_*67*` / `_*68*` | Spy | 67 / 68 | **U** (2026-08-09 sipplab feature pack; **2026-09-26** cross-tenant deny **U** — cagi **1.0.0-22**) |

### 2.2 Dialplan-only utilities

| Code | Behaviour | Attend |
|------|-----------|--------|
| `*52*` echo · `*55*` time · `*56*` say ext | Playback UX | **H** (must hear) |
| `*50*` / `*51*` / `vm{ext}` / `*{ext}` | VM main / leave | **H** |
| `_*8XX.` / `*8` | Directed pickup (`Pickup(@PICKUPMARK)`); named groups on PJSIP endpoint | **U** (req sipplab `./run-pickup-pack.sh`; **`pickup-directed-ok`** / **`pickup-group-deny`**; blind idle `*8` not in v1) |
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
| `OutTrunk` / `OutRoute` / `OutQmt` | — | **`out-egress-ok`** (OutRoute→Egress) / — | L1 **U** · live **H** · `OutQmt` still — |

---

## 4. Unattended vs human — rollup (2026-07-27)

### Can run unattended **now**

| What | How |
|------|-----|
| All existing CAGI L0 scenarios | `cd pbx3cagi-…/csource && make test` |
| L1 `in-open-ext` (and siblings) **if** lab Snom auto-answers | Phone always-auto-answer, **or** `Call-Info`/`Alert-Info` on the **Asterisk→phone** INVITE (see **sipplab** docs) |

### Need a human **now**

| What | Why |
|------|-----|
| L1 without auto-answer on the ringing dest | SIPp waits for **200** |
| L1 with CFIM / CLOSED / queue | Plus **H-setup** of AstDB / day state / agents |
| Remaining `*NN*` (agents/greetings/UX/`*20*`/open-close), BLF | Dial + hear prompt / confirm; CF/DND/ringdelay/spy now **U** via sipplab feature pack |
| IVR, page, park, pickup, conf, VM retrieve | Interactive or multi-party |
| PSTN L3 / SBC-Twilio matrix | Carrier + human |
| Ext↔ext / multi-tenant AoR | Two endpoints (until dual-SIPp / dual auto-answer) |

### Path to reliable unattended L1

1. Lab Snom **always auto-answer** on target ext(s), **or** GenAst/PJSIP inject `Call-Info: Answer-After=0` (+ `Alert-Info`) on the **phone** INVITE for lab.  
2. AMI/scripts for **H-setup** (CFIM, OCSTAT, queue members).  
3. Optional later: SIPp **UAS** as a fake phone (REGISTER via SBC).

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
| 2026-07-27 | Snom auto-answer via `Call-Info`/`Alert-Info`; L1 U when phone auto-answers; note carrier-leg vs phone-leg headers. |
| 2026-07-27 | `in-open-ext` full green (auto-answer + `rrs=true` BYE). Ring-group openroute skips `extalert`; use phone always-auto-answer. |
| 2026-07-27 | `phone-302-local` — SIP 302 phone divert (catcher UAS) added to L1 pack; separate from AstDB CFIM. |
| 2026-07-27 | `maj-site-dial` planned — cross-tenant site-code short dial; see **`TENANT_SHORT_DIAL_REQUIREMENTS.md`**. |
| 2026-07-27 | Pack grow: `feat-master-closed`, `in-cfim-external`, `out-egress-ok` + catcher `SIPP_MAIN`. |
| 2026-07-27 | Clarify `out-egress-ok` = Local originate (not SIPp phone UAC); strategy status → L1 9/9. |
| 2026-07-27 | + `in-queue-cancel-vm`, `out-busy-or-reject` (catcher uas-486). |
| 2026-08-09 | §2.1 Attend **U** for DND/CF/ringdelay/ChanSpy via sipplab `./run-feature-pack.sh` (10/10 ×2 golden). Multi-tenant spy isolation remains debt. |
| 2026-08-24 | **`maj-pickup`** + `_*8XX.` — L1 requirement via sipplab `./run-pickup-pack.sh` (3 ids); lock **`EXTENSION_NAMED_PICKUP_GROUPS.md`** § Lab acceptance. Attend **U** once green; BLF stays L3. |
