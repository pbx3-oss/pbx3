# SIPp traffic-profile sim (mini project)

**Status:** opened 2026-07-31 — infra + mixed-office CDR specimen analyzed; profile runners not built yet.  
**Home:** `pbx3/workingdocs/call-tests/` · hosts **`SIPP_LAB_HOST.md`** §9.  
**Goal:** realistic multi-profile SIPp load (mixed office, inbound-heavy, outbound-heavy) on lab Domain + Numbers paths — not commercial generators.

---

## 1. Intent

Build a **small library of traffic profiles** derived from real CDRs (and later synthetic variants), replayable through:

| Path | Lab role | Host |
|------|----------|------|
| **Domain** (ext↔ext, queue agents) | REGISTER’d SIPp phones | **`sippuac`** `192.168.1.51` (non-Peer) |
| **Numbers in** (DID → tenant) | Peer UAC | SIPp Catcher **`98.82.58.59`** Peer **99** |
| **Numbers out** (fake PSTN) | Peer UAS on `:5060` | same Catcher; dial prefix **`019242*`** |

PBX3 **1 caller → N callees** = Asterisk **queue** (e.g. ringall ≈ SARK ring-group parallel Dial). SIPp supplies 1 caller + N agents; the PBX fans out.

---

## 2. Done this arc (2026-07-30→31)

### Domain / L2 soak
- Magrathea “state-3” root cause: SIPp UAS missing **Record-Route** echo → `[last_Record-Route:]` in `soak-answer` (not NAT). Tip **pbx3** **`36c9ea8`** + leanings **`e576cc2`**.
- Soak proven on **`sippuac`** under office NAT after RR fix.
- **Graceful stop:** `./run-soak.sh stop` drains hold+BYE; `stop force` + Mac `./clear-sbc-dialogs.sh` for residue.

### Numbers lab (coexists with real PSTN)
- Pretend DID **`01924234567`** → golden pb0wsk openroute **2120**.
- Magrathea Number route prefix **`441924234567`** (UK dialect turns national `0…` → `44…` before `do_routing`).
- Peer **99** = **SIPp Catcher**; `./run-peer-pstn-uas.sh` answers Egress on UDP **5060**.
- **Outbound coexistence:** prefix **`019242*`** → gwid **99** only; default empty-prefix stays **`1,20,50`** (Brindley/Magrathea/Twilio).
- Smokes: `./run-did-lab-in.sh`, `OUT_DIGITS=01924234567 ./run-did-lab-out.sh` — both GREEN.

### CDR specimen
- File: **`~/GiT/nonGitStuff/pdh-2026-07-28.csv`** (SARK / Asterisk Master.csv, no header).
- Day shape: **152** logical calls (`uniqueid`), **236** legs; peak concurrent answered **~4**; busiest hour **08:00** (26 calls).
- Mix: to-ext / PSTN / ext↔ext; ~75% ANSWERED; billsec heavy-tailed (p50 **46s**, p90 **280s**).
- Multi-leg uniqueids ≈ ring groups (1→N) — ~15% of calls.

### Design leanings (locked for this project)
1. **1→N sim = queue path** (PBX3 truth), not N parallel Peer INVITEs.
2. Profiles are **data + recipe**, not one-off scripts.
3. This CDR = **mixed-office** specimen (quiet day wallpaper, not stress).

---

## 3. Profile library (target)

| Profile ID | Intent | Notes |
|------------|--------|--------|
| **`mixed-office`** | This CDR | Low concurrency; morning hump; mix Domain + some Numbers; occasional queue |
| **`inbound-heavy`** | Call centre | DID → queue dominant; agent count / AHT / occupancy |
| **`outbound-heavy`** | Sales prospecting | Ext → `019242*` cadence; 1:1 mostly |

Each profile should pin: hour/CPS schedule, hold-time distribution, answer/busy/NA weights, % Domain vs Numbers in/out, **% to queue** + agent N + strategy (start with **ringall**).

---

## 4. How to sim 1→N (PBX3)

```text
Peer 99 or sippuac UAC
    → DID or queue ext
    → Asterisk Queue (ringall)
    → N sippuac UAS (agents)
    → 1× 200 OK + (N−1)× CANCEL
```

- Reuse / extend soak phones + catcher queue **2060** or a dedicated soak queue.
- Answer scenarios must handle **CANCEL** (not only BYE).
- SARK ring-group AGI Dial is **out of scope** for product path; queue-only is enough unless a SARK-parity demo is requested later.

---

## 5. Next session — pick up here

1. Draft a **profile schema** (YAML or `profiles/*.env` + companion md): fields in §3.
2. Encode **`mixed-office`** from `pdh-2026-07-28.csv` (distributions + rough schedule).
3. Implement a runner slice: 1:1 Domain soak (existing) + **queue fan-out** smoke (1 UAC → N agents).
4. Wire Numbers % via Peer 99 / `019242*` without breaking real-carrier default gwlist.
5. Only then sketch `inbound-heavy` / `outbound-heavy` as scaled variants.

**Do not** change Magrathea default outbound back to “99 first” — prefix **`019242*`** is the lab gate.

---

## 6. Script / doc index

| Artifact | Role |
|----------|------|
| `run-soak.sh` | Domain L2; graceful `stop` |
| `clear-sbc-dialogs.sh` | Mac: MI/restart stuck Magrathea dialogs |
| `run-peer-pstn-uas.sh` | Catcher PSTN UAS `:5060` |
| `run-did-lab-in.sh` / `run-did-lab-out.sh` | Numbers smokes |
| `scenarios/soak-*.xml`, `peer-pstn-answer.xml` | RR echo on UAS responses |
| `SIPP_LAB_HOST.md` §9 | Host split + DID/outbound prefix |
| `CALL_TEST_STRATEGY.md` | L0/L1/L2 layers |
| CDR specimen | `~/GiT/nonGitStuff/pdh-2026-07-28.csv` (outside git) |

---

## 7. Open questions (next session)

- Profile file format: YAML vs env+md?
- Scale factor for “busier mixed office” vs literal 4-concurrent replay?
- Queue member login automation (AddQueueMember / static members)?
- Keep extension EC2 `13.222.41.98` as Domain fallback or sippuac-only?
