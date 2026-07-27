# Call / SIP tests (SIPp L1+)

Strategy: **`../CALL_TEST_STRATEGY.md`**. Full call-type map: **`../CALL_TYPE_INVENTORY.md`**. Pack B home for pathway recipes.

## Status

| Item | State |
|------|--------|
| SIPp on operator Mac | Installed (v3.7.x) |
| Layout | This tree |
| `in-open-ext` green on VIP | **Done 2026-07-27** — Mac→VIP→DID `01924918076`→1000; Snom auto-answer; BYE clean after `rrs="true"` |
| CFIM / closed / queue scenarios | **Recipes added** — lab state + answer dest; not all green-labbed yet |

## Layout

```text
call-tests/
  README.md
  lab.env.example → lab.env   # gitignored
  run-sipp.sh                 # ./run-sipp.sh <scenario-id>
  run-in-open-ext.sh          # → run-sipp.sh in-open-ext
  scenarios/
    in-open-ext.xml
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
3. **Inbound trust Peer** — `dr_gateways` row for that IP (`is_from_gw` → `FROM_CARRIER`). Lab: gwid **99** `sip:74.83.26.203:5060` carrier `sipp-lab` (temp; delete when done)
4. **DID** — `01924918076` → golden tenant `dhbm8x` / duns
5. **`lab.env`** — copy from example; set `LOCAL_IP` to `en0` IPv4 if auto-detect fails
6. **Answer** within `RECV_TIMEOUT` (60s) on the pathway’s expected dest — see **Snom auto-answer** below

Public IP: `curl -4 -s ifconfig.me`.

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
| `in-open-ext` | DID openroute → **1000**; not CLOSED; no CFIM | **1000** |
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
