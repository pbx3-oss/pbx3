# SIPp traffic-profile sim (mini project)

**Status:** 2026-07-31 — schema + `mixed-office` YAML + queue **2160** / `rrmemory` runner. **Lab smoke GREEN** on sippuac (4 agents × 2 calls each; Magrathea dialogs→0 after graceful stop).  
**Home:** `pbx3/workingdocs/call-tests/` · hosts **`SIPP_LAB_HOST.md`** §9.  
**Goal:** realistic multi-profile SIPp load (mixed office, inbound-heavy, outbound-heavy, freephone-trunk) on lab Domain + Numbers paths — not commercial generators.

**Locked (2026-07-31):**
- Profile format: **YAML** (`profiles/*.yaml` + `profiles/SCHEMA.md`); soak `.env` knobs stay for `run-soak.sh` only.
- Concurrency: start at CDR peak **4**; raise `concurrency.scale` later if needed.
- Queue: dedicated **`2160`** (do not reuse L1 **2060**).
- Strategy: **`rrmemory`** default; `ringall` optional.

---

## 0. How to run (mixed-office / queue-rr)

**Hosts:** Domain on **`sippuac`** `192.168.1.51` (`ssh tech@192.168.1.51`). Golden for provision/GenAst. Magrathea VIP for SIP. Never Peer-99 EIP for Domain phones.

### One-time (Mac)

```bash
cd pbx3/workingdocs/call-tests
# lab.env + soak phones already exist from L2 soak
./provision-soak-phones.sh          # if 2100–2139 missing
./provision-soak-queue.sh           # queue 2160 rrmemory, members 2120–2123; GenAst + app_queue reload
# writes soak-queue.env (gitignored) — quote MEMBERS if editing by hand
```

### Sync to sippuac

```bash
cd pbx3/workingdocs/call-tests
rsync -av soak-phones.env soak-queue.env lab.env \
  run-queue-rr.sh run-soak.sh clear-sbc-dialogs.sh profiles/ \
  tech@192.168.1.51:~/call-tests/
rsync -av scenarios/soak-register.xml scenarios/soak-answer.xml scenarios/soak-dial.xml \
  tech@192.168.1.51:~/call-tests/scenarios/
```

### Run / stop (on sippuac)

```bash
cd ~/call-tests
./run-queue-rr.sh start mixed-office   # 4 agents + 4 dialers → queue 2160; ~50s hold
./run-queue-rr.sh status
./run-queue-rr.sh stop                 # graceful: drain BYE then kill
# ./run-queue-rr.sh stop force         # may litter Magrathea Active Calls
```

### Verify rotation (on golden)

```bash
# Asterisk queue *section* is shortuid (see soak-queue.env SOAK_QUEUE_SHORTUID), not pkey 2160
sudo asterisk -rx "queue show 305st9"
# Expect rrmemory; member call counts advancing round-robin
```

Dialplan still uses **pkey** `2160` (`Queue(305st9,…)`). Magrathea residue after force-stop: Mac `./clear-sbc-dialogs.sh`.

### Related wallpaper

| Command | What |
|---------|------|
| `./run-soak.sh start demo` | Domain 1:1 pairs (~10), not queue |
| `./run-soak.sh stop` | Graceful Domain soak stop |

Profile data: **`profiles/mixed-office.yaml`**. Schema: **`profiles/SCHEMA.md`**.

---

## 1. Intent

Build a **small library of traffic profiles** derived from real CDRs (and later synthetic variants), replayable through:

| Path | Lab role | Host |
|------|----------|------|
| **Domain** (ext↔ext, queue agents) | REGISTER’d SIPp phones | **`sippuac`** `192.168.1.51` (non-Peer) |
| **Numbers in** (DID → tenant) | Peer UAC | SIPp Catcher **`98.82.58.59`** Peer **99** |
| **Numbers out** (fake PSTN) | Peer UAS on `:5060` | same Catcher; dial prefix **`019242*`** |

PBX3 **1 caller → N agents** = Asterisk **queue**. Default strategy **`rrmemory`** (advance last member); optional **`ringall`**. SIPp supplies callers + registered agents; the PBX selects.

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
2. Default queue strategy **`rrmemory`** (remember last, advance); **`ringall`** optional for parallel-ring slice.
3. Profiles are **data + recipe**, not one-off scripts.
4. This CDR = **mixed-office** specimen (quiet day wallpaper, not stress).
5. **`freephone-trunk`** = intl toll-free → trunker → carrier(s); separate from Domain/queue wallpaper.

---

## 3. Profile library (target)

| Profile ID | Intent | Notes |
|------------|--------|--------|
| **`mixed-office`** | This CDR | Low concurrency; morning hump; mix Domain + some Numbers; occasional queue |
| **`inbound-heavy`** | Call centre | DID → queue dominant; agent count / AHT / occupancy |
| **`outbound-heavy`** | Sales prospecting | Ext → `019242*` cadence; 1:1 mostly |
| **`freephone-trunk`** | Intl freephone trunking | Toll-free DNIS in (e.g. BR 0800) → trunker → **carrier(s)** deliver world PSTN. Mostly static DNIS→DDI; optional time. Encode when CDR arrives. |

Each profile should pin: hour/CPS schedule, hold-time distribution, answer/busy/NA weights, % Domain vs Numbers in/out, **% to queue** + agent N + **strategy** (`rrmemory` default; `ringall` optional) — except **`freephone-trunk`**, which pins DID set, route table (static ± day-part), and egress mix instead of queue %.

### 3.1 `freephone-trunk` (sketch)

**Production shape:** international freephone / toll-free DNIS in (e.g. Brazil **0800**-style) → trunker maps to a **world PSTN** target → hand off to **carrier(s)** for international delivery. Destinations **mostly static** DNIS→DDI; may include a **time** element. **Not** queue/agents; **not** Domain phones; **not** peer-to-foreign-SBC as the primary story (carrier egress is).

```text
SIPp Peer UAC (intl freephone DNIS)
    → Magrathea FROM_CARRIER / Number route
    → golden openroute = trunker HoR (static ± day-part)
    → Magrathea Egress → carrier Peer(s)
    → lab PSTN stand-in: 019242* → Peer 99 UAS (or extra Peer gwids later)
```

**v1 lean (2026-07-31):**
- **Golden hairpin** = product fidelity (we own the translate table).
- Catcher / Peer 99 = **carrier stand-in** for egress (and can originate the freephone INVITE as if from an inbound carrier).
- VIP-only Peer→Peer with no Asterisk = edge CPS soak only; do not call that `freephone-trunk` fidelity.
- Dialects / country codes matter more here than for mixed-office — Number route prefixes and Peer `dialect=` will show up in CDR encoding.
- Lab gate: pretend freephone DID(s) + `019242*` out coexistence (do not put lab traffic on real intl carriers).
- Kinship: day-parts → **`TIME_BASED_ROUTING_REQUIREMENTS.md`** later; profile data stays separate.
- **Blocked on:** CDR sample (AHT/CPS/concurrent, origin countries, dest mix, how often time flips).

---

## 4. How to sim 1→N (PBX3)

SIPp supplies **1 caller + N registered agents**; Asterisk Queue does agent selection. Do **not** fan out with N Peer INVITEs.

### 4.1 Default — `rrmemory` (round-robin)

Queue **remembers** the last member and advances on the next arrival. Each call is 1→**one** agent; over a stream, load walks the pool.

```text
Dialers (Domain or DID)
    → soak queue **2160** (SOAK_Q; not L1 2060)
    → Asterisk Queue strategy=rrmemory
    → next sippuac UAS agent (static member)
    → 200 + BYE (normal 1:1; no CANCEL storm)
```

**v1 lean (locked 2026-07-31):**
1. Static members = subset of soak answerers (**2100–2139**); no AddQueueMember automation yet.
2. Strategy **`rrmemory`** (or `rrordered` if we need fixed order) as the **default** wallpaper / `mixed-office` queue slice.
3. Runner: N UAS up on sippuac → stream of callers → assert rotation across agents; Magrathea dialogs clear after BYE.
4. Answerer = existing `soak-answer` RR echo path (CANCEL handling not required for this strategy).

### 4.2 Optional — `ringall` (parallel)

```text
1 dialer → queue ringall → N agents at once
    → 1× 200 OK + (N−1)× CANCEL
```

- Use for PDH multi-leg / ring-group-ish (~15%) or an explicit profile knob `strategy=ringall`.
- Needs CANCEL-aware answerer XML; more Magrathea dialog litter risk — second smoke, not day-one.

### 4.3 Shared notes

- Reuse soak phones; dedicated soak queue **2160** (not L1 **2060**).
- Profile fields: `% to queue`, `agent_n`, `strategy` (`rrmemory` default | `ringall`).
- SARK ring-group AGI Dial remains **out of scope** unless a SARK-parity demo is requested later.

---

## 5. Next session — pick up here

1. ~~Draft profile schema~~ → **`profiles/SCHEMA.md`** + **`mixed-office.yaml`**.
2. ~~Encode mixed-office~~ (CDR peak concurrent 4; path/hold weights in YAML).
3. ~~Lab smoke~~ — sippuac **GREEN** 2026-07-31 (`rrmemory` rotation; graceful stop; dlg_count 0).
4. Wire Numbers % via Peer 99 / `019242*` without breaking real-carrier default gwlist.
5. Only then sketch `inbound-heavy` / `outbound-heavy` as scaled variants.
6. **`freephone-trunk`:** park until CDR; golden hairpin + carrier stand-in Peer; intl freephone DNIS → world dest.

**Do not** change Magrathea default outbound back to “99 first” — prefix **`019242*`** is the lab gate.

---

## 6. Script / doc index

| Artifact | Role |
|----------|------|
| `profiles/SCHEMA.md` | YAML profile field reference |
| `profiles/mixed-office.yaml` | CDR-derived mixed-office (concurrent 4) |
| `provision-soak-queue.sh` | Create/update queue **2160** `rrmemory` + GenAst |
| `run-queue-rr.sh` | Domain dialers → queue; N agents on sippuac |
| `run-soak.sh` | Domain L2 1:1; graceful `stop` |
| `clear-sbc-dialogs.sh` | Mac: MI/restart stuck Magrathea dialogs |
| `run-peer-pstn-uas.sh` | Catcher PSTN UAS `:5060` |
| `run-did-lab-in.sh` / `run-did-lab-out.sh` | Numbers smokes |
| `scenarios/soak-*.xml`, `peer-pstn-answer.xml` | RR echo on UAS responses |
| `SIPP_LAB_HOST.md` §9 | Host split + DID/outbound prefix |
| `CALL_TEST_STRATEGY.md` | L0/L1/L2 layers |
| CDR specimen | `~/GiT/nonGitStuff/pdh-2026-07-28.csv` (outside git) |

---

## 7. Open questions (next session)

- Profile file format: **YAML** (locked).
- Scale: start **concurrent 4**; raise later via `concurrency.scale`.
- Dedicated soak queue **2160** (locked; not L1 2060).
- Keep extension EC2 `13.222.41.98` as Domain fallback or sippuac-only?
- Queue member login automation — **v1 = static**; dynamic later.
- Default queue strategy locked: **`rrmemory`**; `ringall` optional.
- **`freephone-trunk`:** CDR specimen; origin countries / dest mix; static vs day-part split.
