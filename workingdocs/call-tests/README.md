# Call / SIP tests (SIPp L1+)

Strategy: **`../CALL_TEST_STRATEGY.md`**. Full call-type map: **`../CALL_TYPE_INVENTORY.md`**. Pack B home for pathway recipes.

## Status

| Item | State |
|------|--------|
| SIPp on operator Mac | Installed (v3.7.x) |
| Layout | This tree |
| `in-open-ext` green on VIP | **Done 2026-07-27** — Mac→VIP→DID `01924918076`→1000; Snom auto-answer; BYE clean after `rrs="true"` |
| **SIPp catcher** | **Lab 2026-07-27** — golden tenant `sipp` (`pb0wsk.pbx3.com`), exts **2000/2001**, queue **2060**; Twilio DID `+15139279738` |
| **L1 pack** | **`./run-pack.sh` green 2026-07-27** — open + CFIM + closed + queue (catcher UAS) |
| CFIM / closed / queue scenarios | Pack-greened on catcher path |
| **SIPp off-box host** | **Live 2026-07-27** — EIP `98.93.98.162`; Peer gwid **99**; pack green on host (`SIPP_LAB_HOST.md`) |

## Layout

```text
call-tests/
  README.md
  lab.env.example → lab.env   # gitignored
  run-sipp.sh                 # ./run-sipp.sh <scenario-id> [catcher]
  run-in-open-ext.sh          # → Magrathea DID / Snom path
  run-in-open-ext-catcher.sh  # → Twilio DID / SIPp UAS path
  run-catcher.sh              # REGISTER smoke or UAS auto-answer
  run-pack.sh                 # L1 automated pack (catcher + state + scenarios)
  lab-state.sh                # open|cfim|closed|queue on golden catcher tenant
  SIPP_LAB_HOST.md            # EC2 off-box install sketch (caller+catcher)
  scenarios/
    in-open-ext.xml
    catcher-register.xml
    catcher-answer.xml
    in-cfim-local.xml
    in-closed-ivr-or-dest.xml
    feat-master-closed.xml
    in-queue-answer.xml
  notes/                      # SIPp traces (gitignored)
```

## Path model

| Entry | When |
|-------|------|
| **VIP / SBC** | Fleet-realistic inbound (default) |
| Direct to node | Optional thinner bootstrap — not default |
| L0 CAGI `make test` | Offline — not this tree |

Mac-only for now (no jump host).

## Shared prerequisites (all VIP scenarios)

1. **SIPp** — `brew install sipp`
2. **VIP** — `3.93.26.82` (`sbc.pbx3.com`); SG UDP 5060 from your Mac public IP
3. **Inbound trust Peer** — `dr_gateways` row for that IP (`is_from_gw` → `FROM_CARRIER`). **Do not leave a lab Peer on the office public IP** — it steals real phone INVITEs (phones show “No inbound route”). Temp gwid **99** `sipp-lab` was removed 2026-07-27 for this reason. Re-add only for a SIPp pack run, then delete + `dr_reload`.
4. **DID** — Magrathea `01924918076` → `dhbm8x` / 1000 (Snom path); Twilio `+15139279738` → catcher tenant / 2000
5. **`lab.env`** — copy from example; set `LOCAL_IP` to `en0` IPv4 if auto-detect fails; set `CATCHER_*` from golden
6. **Answer** within `RECV_TIMEOUT` (60s) — Snom auto-answer **or** SIPp catcher UAS

Public IP: `curl -4 -s ifconfig.me`.

### SIPp catcher (unattended answerer)

Dedicated golden tenant **`sipp`** (`pb0wsk.pbx3.com`), General SIP exts **2000** / **2001**. Phones REGISTER to SBC VIP as `{shortuid}@{tenant.fqdn}` (same fleet path as Snom). Twilio DID `+15139279738` openroutes to **2000**.

```bash
# terminal A — stay up, auto-answer
./run-catcher.sh uas

# terminal B — inbound VIP → Twilio DID → catcher
./run-in-open-ext-catcher.sh
# or: ./run-sipp.sh in-open-ext catcher
```

One-shot REGISTER smoke: `./run-catcher.sh register`.

**Ops note:** After inserting a new SBC `domain` row, reload cache:
`curl -sS -X POST http://127.0.0.1:8888/mi/ -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"domain_reload","id":1}'` (on VIP).

### L1 pack (automated)

After PBX3 / cagi / GenAst / SBC changes on golden:

```bash
cd pbx3/workingdocs/call-tests
./run-pack.sh                 # open + CFIM + closed + queue
./run-pack.sh in-open-ext     # single id
```

Requires `GOLDEN_SSH` + `CATCHER_*` in `lab.env`. Starts catcher UAS (A + B for CFIM), toggles lab state via `lab-state.sh`, runs each scenario against Twilio DID, restores OPEN. Exit **0** = pack green. Log: `notes/pack-*.log`.

| Pack id | Lab state | Answerer |
|---------|-----------|----------|
| `in-open-ext` | openroute 2000 | catcher A |
| `in-cfim-local` | CFIM 2000→2001 | catcher B |
| `in-closed-ivr-or-dest` | tenant OCSTAT CLOSED; closeroute 2000 | catcher A |
| `in-queue-answer` | openroute queue **2060** | catcher A |

### Snom auto-answer (unattended L1)

Snom can auto-answer when the **INVITE that hits the phone** carries e.g.:

```text
Call-Info: Answer-After=0
```

**PBX field:** extension **Ext alert** (`ipphone.extalert`) → LepDial `SIPAddHeader` on the **phone** INVITE.

**Gotcha — ring groups:** Lab DID `01924918076` openroutes to a **ring group**, not a single LepDial. Group dial does **not** apply per-member `extalert`, so Ext alert on 1000 will **not** auto-answer that DID path. Carrier-leg SIPp `Call-Info` / `Alert-Info` are noise (stripped / new INVITE) — remove from scenarios when convenient.

| Approach for unattended `in-open-ext` | Works? |
|--------------------------------------|--------|
| Ext alert on 1000 + DID → **single** extension | **Yes** |
| Ext alert on 1000 + DID → **ring group** | **No** |
| Snom **always** auto-answer (phone setting) | **Yes** (any dial path) |
| Inject headers on group Dial() (product change) | Not today |

**Lab recommendation:** either point a dedicated test DID/openroute at **one** extension with Ext alert set, or enable Snom always-auto-answer on the ringing set.

**gwid allocate:** Filament used to suggest `10` (string MAX). Fixed in **pbx3sbc-admin** (numeric CAST) — deploy with that tip.

## Scenarios

SIP INVITE is the same shape for these IDs; **lab state** chooses the pathway. SIPp asserts **200 + BYE/200** on whatever answers.

| ID | Lab setup before run | Who answers |
|----|----------------------|-------------|
| `in-open-ext` | Magrathea DID openroute → **1000** (or ring group); not CLOSED | **1000** / Snom |
| `in-open-ext` + `catcher` | Twilio DID → catcher **2000**; `./run-catcher.sh uas` running | SIPp catcher |
| `in-cfim-local` | On openroute ext, set **CFIM → local ext** (e.g. 1000→1001) | CFIM target |
| `in-closed-ivr-or-dest` | Force **CLOSED** (day timer / `cluster.oclo` / tenant OCSTAT); `closeroute` = answerable dest | closeroute dest |
| `feat-master-closed` | Master AstDB **`STAT/OCSTAT` = CLOSED**; closeroute answerable | closeroute dest |
| `in-queue-answer` | openroute (or DID) → **queue**; agent logged in / ringing (lab often **Q1060**) | agent |

Restore open/CFIM/queue after each run so the next scenario is not poisoned.

## Run

```bash
cd pbx3/workingdocs/call-tests
cp lab.env.example lab.env   # once
# LOCAL_IP=$(ipconfig getifaddr en0)  # recommended on Mac

./run-sipp.sh in-open-ext
./run-sipp.sh in-open-ext catcher   # Twilio DID → SIPp UAS (start ./run-catcher.sh uas first)
./run-sipp.sh in-cfim-local
./run-sipp.sh in-closed-ivr-or-dest
./run-sipp.sh feat-master-closed
./run-sipp.sh in-queue-answer
```
Exit **0** + “Successful call” = green for that ID. Traces: `notes/<id>-*.log`.

### Manual one-liner

```bash
LOCAL_IP=$(ipconfig getifaddr en0)
sipp 3.93.26.82 -i "$LOCAL_IP" -p 5061 \
  -sf scenarios/in-open-ext.xml -s 01924918076 \
  -m 1 -recv_timeout 60000 -timeout_error
```

## Failure hints

| Symptom | Likely cause |
|---------|----------------|
| Timeout / no response | SG blocked; wrong VIP; UDP filtered |
| 403 / reject / non-carrier | Mac IP not in `dr_gateways` |
| 404 | DID / alias / dispatcher |
| 180 then timeout | Expected dest not answering |
| Wrong party rings | Lab state (still OPEN, CFIM unset, not queued) |
| ACK/BYE fail / OpenSIPS **500** on BYE | Missing `rrs="true"` on INVITE 200 (Record-Route not stored) — fixed in scenarios; re-pull XML |

## Next

- Green-lab the new IDs when convenient; multi-tenant / CFIM-external later.
- L2 soak under `profiles/` later.
