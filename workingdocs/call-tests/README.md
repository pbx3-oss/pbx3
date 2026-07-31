# Call / SIP tests (SIPp L1+)

Strategy: **`../CALL_TEST_STRATEGY.md`**. Full call-type map: **`../CALL_TYPE_INVENTORY.md`**. Pack B home for pathway recipes.

## Status

| Item | State |
|------|--------|
| SIPp on operator Mac | Installed (v3.7.x) |
| Layout | This tree |
| `in-open-ext` green on VIP | **Done 2026-07-27** — Mac→VIP→DID `01924918076`→1000; Snom auto-answer; BYE clean after `rrs="true"` |
| **SIPp catcher** | **Lab 2026-07-27** — golden tenant `sipp` (`pb0wsk.pbx3.com`), exts **2000/2001**, queue **2060**; Twilio DID `+15139279738` |
| **L1 pack** | **`./run-pack.sh`** — **11 ids** green (incl. queue-cancel-vm + out-busy) |
| CFIM / closed / queue / 302 / multi-tenant / outbound | Pack IDs on catcher path |
| **SIPp off-box host** | **Live** — EIP **`98.82.58.59`** (Peer gwid **99**); pack green on host (`SIPP_LAB_HOST.md`) |
| **SIPp extension platform** | **Live** — lab EC2 **`13.222.41.98`** (non-Peer phone UAC) + office VM **`sippuac`** `192.168.1.51`; §9 |
| **L2 soak / demo** | **Green** — sippuac + graceful `stop`; see **`TRAFFIC_PROFILE_SIM.md`** for profile library next |

### Known residue — stuck Active Calls after pack (2026-07-30)

**Not an SBC cfg bug.** Catcher UAS (`catcher-answer.xml`) waits for BYE; `run-pack.sh` **kills** SIPp between scenarios / at end. Abrupt UAS death → no BYE → OpenSIPS `dialog` stays Confirmed until the long default timeout (lab saw ~overnight). Home “Active dialogs” / Filament Active Calls look busy until MI `dlg_end_dlg` or timeout.

**Wanted:** graceful teardown (BYE before kill, or post-pack MI cleanup). Tracked in **`TODO.md`**.

## Layout

```text
call-tests/
  README.md
  lab.env.example → lab.env   # gitignored
  run-sipp.sh                 # ./run-sipp.sh <scenario-id> [catcher]
  run-in-open-ext.sh          # → Magrathea DID / Snom path
  run-in-open-ext-catcher.sh  # → Twilio DID / SIPp UAS path
  run-catcher.sh              # register | uas | uas-302
  run-pack.sh                 # L1 automated pack (catcher + state + scenarios)
  lab-state.sh                # open|cfim|cfim-external|closed|master-closed|queue|…
  SIPP_LAB_HOST.md            # EC2 off-box install sketch (caller+catcher)
  scenarios/
    in-open-ext.xml
    phone-302-local.xml
    in-multi-tenant-a-b.xml
    catcher-register.xml
    catcher-answer.xml
    catcher-answer-302.xml
    in-cfim-local.xml
    in-cfim-external.xml
    in-closed-ivr-or-dest.xml
    feat-master-closed.xml
    in-queue-answer.xml
    out-egress-ok.xml
  notes/                      # SIPp traces (gitignored)
```

## Path model

| Entry | When |
|-------|------|
| **VIP / SBC** | Fleet-realistic inbound (default) |
| Direct to node | Optional thinner bootstrap — not default |
| L0 CAGI `make test` | Offline — not this tree |

Mac-only for now (no jump host).

## L2 soak / demo wallpaper (ext↔ext)

Steady concurrent calls on catcher tenant for CDR/Home fill and live demos. Runs on **extension platform** (lab EC2 or `sippuac`), not Peer-99.

```bash
# once — create exts 2100–2139 on golden + GenAst + soak-phones.env
./provision-soak-phones.sh
rsync -av soak-phones.env scenarios/soak-*.xml run-soak.sh profiles/ lab.env ubuntu@<EXT_EIP>:~/call-tests/
# on extension host
./run-soak.sh start demo    # ~10 up
./run-soak.sh start busy    # ~20 up
./run-soak.sh status
./run-soak.sh stop          # graceful: drain hold+BYE then kill UAS
./run-soak.sh stop force    # immediate (may litter Active Calls)
./clear-sbc-dialogs.sh      # Mac: MI/restart cleanup if residue
```

Profiles: `profiles/demo.env` / `busy.env`. Dialer holds then BYEs (clears SBC dialogs). **`stop`** drops the run flag and waits for in-flight dialers to BYE before killing answerers — avoids Magrathea Active Calls litter. Spec: **`CALL_TEST_STRATEGY.md`** §6 L2.

---

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

# phone 302 divert: A redirects to CATCHER_EXT_B; B answers
./run-catcher.sh uas-302 &          # A on :5070
CATCHER_USER=$CATCHER_USER_B CATCHER_PASS=$CATCHER_PASS_B CATCHER_PORT=$CATCHER_PORT_B \
  ./run-catcher.sh uas &            # B on :5071
./lab-state.sh open
./run-sipp.sh phone-302-local catcher
```

One-shot REGISTER smoke: `./run-catcher.sh register`.

**Ops note:** After inserting a new SBC `domain` row, reload cache:
`curl -sS -X POST http://127.0.0.1:8888/mi/ -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"domain_reload","id":1}'` (on VIP).

### L1 pack (automated)

After PBX3 / cagi / GenAst / SBC changes on golden:

```bash
cd pbx3/workingdocs/call-tests
./run-pack.sh                      # full pack incl. phone-302 + multi-tenant
./run-pack.sh in-multi-tenant-a-b  # single id
```

Requires `GOLDEN_SSH` + `CATCHER_*` in `lab.env`. Starts catcher UAS (A + B for CFIM / 302; **peer** on affcot for multi-tenant), toggles lab state via `lab-state.sh`, runs each scenario against Twilio DID, restores OPEN. Exit **0** = pack green. Log: `notes/pack-*.log`.

| Pack id | Lab state | Answerer |
|---------|-----------|----------|
| `in-open-ext` | openroute 2000 | catcher A |
| `in-cfim-local` | CFIM 2000→2001 | catcher B |
| `in-closed-ivr-or-dest` | tenant OCSTAT CLOSED; closeroute 2000 | catcher A |
| `feat-master-closed` | **STAT/OCSTAT=CLOSED**; closeroute 2000 | catcher A |
| `in-queue-answer` | openroute queue **2060** | catcher A |
| `in-queue-cancel-vm` | queue; catcher A **486** → failover → VM | Voicemail (CLI assert) |
| `phone-302-local` | openroute 2000; **no** CFIM | A returns **302→2001**; B answers |
| `in-multi-tenant-a-b` | open + peer REG on **affcot** `1199` | catcher A (peer is usrloc noise) |
| `in-cfim-external` | CFIM → `CFIM_EXTERNAL_DEST` (default `01924910444`); SIPP_MAIN→Egress | Magrathea→1000 (Ext alert) / comfort 200 |
| `out-egress-ok` | SIPP_MAIN; **Local originate** on golden (not SIPp phone — Peer IP conflict) | Magrathea→1000 / Egress Up |
| `out-busy-or-reject` | open; catcher A **486**; Local originate to 2000 | PostDial Voicemail/Busy |

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
| `in-cfim-external` | CFIM → off-box digits (`strlen>5`); catcher needs **SIPP_MAIN** OutRoute | far-end / comfort |
| `phone-302-local` | openroute → A; A UAS **302** Contact=`CATCHER_EXT_B`; no AstDB CFIM | catcher B |
| `in-multi-tenant-a-b` | Peer catcher REGISTER’d on **affcot**; DID → sipp A (AoR domain check) | catcher A |
| `in-closed-ivr-or-dest` | Force **CLOSED** (day timer / `cluster.oclo` / tenant OCSTAT); `closeroute` = answerable dest | closeroute dest |
| `feat-master-closed` | Master AstDB **`STAT/OCSTAT` = CLOSED**; closeroute answerable | closeroute dest |
| `in-queue-answer` | openroute (or DID) → **queue**; agent logged in / ringing (lab often **Q1060**) | agent |
| `out-egress-ok` | Catcher **Local/** originate → SIPP_MAIN→Egress (SIPp phone UAC blocked: lab EIP is Peer 99) | Magrathea→1000 / Egress Up |

Restore open/CFIM/queue after each run so the next scenario is not poisoned.

## Run

```bash
cd pbx3/workingdocs/call-tests
cp lab.env.example lab.env   # once
# LOCAL_IP=$(ipconfig getifaddr en0)  # recommended on Mac

./run-sipp.sh in-open-ext
./run-sipp.sh in-open-ext catcher   # Twilio DID → SIPp UAS (start ./run-catcher.sh uas first)
./run-sipp.sh in-cfim-local
./run-sipp.sh phone-302-local catcher
./run-sipp.sh in-closed-ivr-or-dest
./run-sipp.sh feat-master-closed catcher
./run-sipp.sh in-cfim-external catcher
./run-out-egress.sh
./run-sipp.sh in-queue-answer
```
Exit **0** + “Successful call” = green for that ID. Traces: `notes/<id>-*.log`.

**OutRoute lab note:** catcher tenant seeds **`SIPP_MAIN`** (`_XXXXX.` → Egress) via `lab-state.sh ensure-outroute` (DB + hot dialplan). Survive GenAst Commit from DB; re-run ensure after `dialplan reload` if the hot line vanished.

**OutVoip note (2026-07-27):** CAGI `OutVoip` queried nonexistent column `desc` (fixed → `description` + correct `callprogress` col). Needed for any Egress Dial.

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
| `Route: Route: <…>` in ACK/BYE | Scenario had `Route: [routes]`; SIPp `[routes]` already includes `Route:` — use bare `[routes]` |
| **UAS ACK timeout; Magrathea answerer-leg state-3; Asterisk 0 channels** | UAS **180/200 omitted Record-Route**. Asterisk ACKs Contact directly (bypasses SBC). Fix: `rrs="true"` on INVITE recv + **`[last_Record-Route:]`** in 180/200 — **not** `[routes]` (that emits `Route:` for mid-dialog *requests*). Real phones echo RR; compare VIP pcap. See **SIPp leanings** below. |
| BYE no 200 on local VM (answer OK) | Office NAT remaps VM UDP (`rport≠5070`); Mac often keeps `rport=5070`. Pathway still proven; teardown polish later |

## SIPp leanings (recognise next time)

Durable lab lessons — skim before inventing a new “SBC bug”.

1. **UAS must echo Record-Route** — Magrathea inserts `Record-Route` on the answerer INVITE. Real phones copy it into 180/200. SIPp UAS must too (`[last_Record-Route:]`). Without it: dialer leg + Asterisk clear; answerer never gets ACK; Magrathea leaves **state-3**; EC2 tcpdump shows INVITE in / 200 out / **0 ACKs**. **Not** office NAT (same on non-NAT EC2). Tip **`36c9ea8`**.
2. **`[routes]` ≠ Record-Route** — `[routes]` builds **`Route:`** for in-dialog *requests* (ACK/BYE). Response echo needs **`[last_Record-Route:]`**.
3. **Bare `[routes]` on requests** — never `Route: [routes]` (doubles the header name).
4. **Pack kill ≠ hangup** — `run-pack.sh` SIGKILLing catcher UAS leaves Confirmed dialogs until timeout (separate from #1).

## Next

- Optional: `out-busy-or-reject`; L1 pack graceful teardown (BYE before kill / post-pack MI cleanup).
- Optional: wire `soak-unregister` into `run-soak.sh` start.
