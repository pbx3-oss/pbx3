# SIPp lab host (EC2) — install sketch

**Why:** Mac/office public IP must **not** sit in SBC `dr_gateways` as a carrier Peer (steals phone INVITEs → “No inbound route”). Put **caller + catcher** on a dedicated tiny EC2 with its own EIP.

**Status:** Lab host live — EIP **`98.82.58.59`** (was `98.93.98.162`), Peer gwid **99**, `./run-pack.sh` green from host.

**Residue:** pack kill of catcher UAS can leave OpenSIPS dialogs Confirmed until timeout — prefer graceful BYE teardown (**`TODO.md`**, **`call-tests/README.md`**).

---

## 1. Instance

| Item | Suggestion |
|------|------------|
| Region | **us-east-1** (same as Magrathea VIP / golden) |
| Size | **t4g.nano** or **t3.micro** — SIPp signalling is tiny |
| OS | **Ubuntu 24.04** LTS |
| Disk | 8 GB fine |
| EIP | Yes — stable Peer address |
| Key | Reuse lab key (e.g. `pbx3test.pem`) or a dedicated `sipp-lab.pem` |

**Security group** (lab-only):

| Direction | Proto | Port | Source / dest |
|-----------|-------|------|----------------|
| Inbound | UDP | 5060–5080 | Magrathea VIP SG or `3.93.26.82/32` (SBC→catcher INVITE/REGISTER replies) |
| Inbound | UDP | 10000–10100 | SBC / golden RTP later (optional; pack is signalling-first) |
| Inbound | TCP | 22 | Operator / control IP only |
| Outbound | all | | Needed for REGISTER/INVITE to VIP `3.93.26.82:5060` |

Do **not** open 5060 to the world.

**Name tag:** `pbx3-sipp-lab` (or similar).

---

## 2. Host bootstrap (on the instance)

```bash
sudo apt-get update
sudo apt-get install -y sip-tester   # Ubuntu package name; provides `sipp`
# (sketch originally said `sipp` — on 24.04 use sip-tester)

# Recipes live in pbx3 repo (clone shallow or rsync from Mac)
git clone --depth 1 --filter=blob:none --sparse \
  <pbx3-git-url> pbx3
cd pbx3 && git sparse-checkout set workingdocs/call-tests
cd workingdocs/call-tests
cp lab.env.example lab.env
```

If the repo is private, prefer **rsync from Mac** instead of a deploy key:

```bash
# on Mac
rsync -av -e "ssh -i …/pbx3test.pem" \
  pbx3/workingdocs/call-tests/ \
  ubuntu@<SIPP_EIP>:~/call-tests/
```

---

## 3. `lab.env` on the lab host

```bash
SBC_HOST=3.93.26.82
SBC_PORT=5060
DID_CATCHER=+15139279738

# Bind to the instance primary private IP (SIPp Contact); SBC uses received=
LOCAL_IP=$(hostname -I | awk '{print $1}')
LOCAL_PORT=5061
CATCHER_PORT=5070
CATCHER_PORT_B=5071

# Same catcher tenant as golden (already provisioned)
CATCHER_DOMAIN=pb0wsk.pbx3.com
CATCHER_USER=0zr3hp
CATCHER_PASS=…          # from golden / operator vault — not git
CATCHER_USER_B=hxy8rk
CATCHER_PASS_B=…
CATCHER_EXT_A=2000
CATCHER_EXT_B=2001
CATCHER_QUEUE=2060

# Lab-state still SSHes golden (install key on this host or ProxyJump)
GOLDEN_SSH='ssh -i ~/.ssh/pbx3test.pem -o BatchMode=yes ubuntu@08jzwn.pbx3.com'
```

Copy the catcher passwords from Mac `lab.env` or `/tmp/sipp-catcher.env` on golden once; do not commit.

**SSH to golden from the lab host:** place `pbx3test.pem` mode 600 on the instance, or run `lab-state.sh` from the Mac while SIPp runs on EC2 (split control). Prefer key on lab host so `./run-pack.sh` is one-box.

---

## 4. SBC Peer (lab host EIP only)

After EIP is known (`SIPP_EIP`):

```sql
-- on Magrathea (VIP holder)
INSERT INTO dr_gateways (gwid, type, address, strip, say_ok, probe_mode, attrs, description)
VALUES (
  99, 0, 'sip:SIPP_EIP:5060', 0, 1, 0,
  'carrier=sipp-lab;role=inbound',
  'SIPp lab EC2 (pack only)'
);
```

Then MI: `dr_reload`.

**Rules:**

- Peer address = **lab EIP**, never the office/Mac IP.
- Safe to leave permanently if this host is SIPp-only.
- If you delete/recreate the instance, update `address` + `dr_reload`.

Filament: Peering → add inbound Peer with same attrs (numeric gwid allocate after sbc-admin fix is deployed).

Catcher **REGISTER** does **not** need this Peer (phone path). Peer is only for **UAC INVITE** (DID → VIP as FROM_CARRIER).

---

## 5. Smoke on the lab host

```bash
cd ~/call-tests   # or sparse path
./run-catcher.sh register          # 401→200
./run-catcher.sh uas &             # terminal A
./run-in-open-ext-catcher.sh       # terminal B — needs Peer 99 present
./run-pack.sh                      # full L1 pack
```

Expect same green set as Mac pack (open / CFIM / closed / queue).

---

## 6. Operator Mac role (after cutover)

| Keep on Mac | Move to EC2 |
|-------------|-------------|
| Edit recipes / git | SIPp UAC + catcher UAS |
| SSH golden / SBC | `./run-pack.sh` (or trigger via SSH) |
| Optional: `ssh lab './run-pack.sh'` | Peer 99 lifecycle if EIP changes |

```bash
# from Mac
ssh -i …/pbx3test.pem ubuntu@<SIPP_EIP> 'cd ~/call-tests && ./run-pack.sh'
```

---

## 7. Checklist when you spin it up

1. [ ] EC2 + EIP + SG as above  
2. [ ] `sipp` installed; `call-tests/` present; `lab.env` filled  
3. [ ] Golden SSH from lab host works (`lab-state.sh status`)  
4. [ ] SBC Peer gwid **99** → `sip:<EIP>:5060` + `dr_reload`  
5. [ ] `./run-catcher.sh register` green  
6. [ ] `./run-pack.sh` green  
7. [ ] Confirm office phones still dial (no Peer on office IP)

---

## 8. Out of scope (this host)

- Media / RTP soak (open RTP ports; add `-m` / pcmu)  
- Systemd units for always-on catcher  
- CI triggering pack over SSH  
- **Acting as a clean phone/extension UAC** — Peer 99 IP cannot also be a non-Peer phone (see §9)

**In pack now:** `phone-302-local` (catcher A `uas-302` → B).

---

## 9. Second SIPp — extension platform (phone UAC)

**Do when:** demos/load, true OutRoute-from-phone, or dial-alias L1 `site-dial-a-b`. Not required for Peer-99 DID pack.

| Role | Host | Peer? |
|------|------|--------|
| **Carrier / Numbers** | SIPp Catcher EIP **`98.82.58.59`** + gwid **99** | Yes — DID UAC **and** PSTN UAS (UDP 5060) |
| **Extension platform** | **`sippuac`** `192.168.1.51` (or non-Peer EC2) | **No** — never add as `dr_gateways` Peer |

**Why:** Phone REGISTER + dial from the Peer-99 EIP confuses carrier matching / blocks true phone-outbound. Split roles.

**Lab choice (2026-07-31):** Domain soak on **`sippuac`** (RR fix). Numbers bidirectional on Peer **99**.

| Item | Live |
|------|------|
| Host / SSH (Domain) | **`sippuac`** — `ssh tech@192.168.1.51` |
| Host / SSH (Numbers) | SIPp Catcher **`ubuntu@98.82.58.59`** (`pbx3test.pem`) — Peer **99** |
| Recipes | `~/call-tests/` (rsync from Mac) |
| Domain smoke | `./run-phone-a-b.sh`; L2 `./run-soak.sh start demo` / graceful `stop` |
| Numbers smoke | Catcher `./run-peer-pstn-uas.sh start`; DID in `./run-did-lab-in.sh`; out on sippuac `OUT_DIGITS=01924234567 ./run-did-lab-out.sh` |
| Lab DID | **01924234567** — Magrathea Number route prefix **`441924234567`** (UK dialect 0…→44…); golden → pb0wsk **2120** |
| Outbound | Prefix **`019242*`** → Peer **99** only; default empty-prefix stays **`1,20,50`** (Brindley/Magrathea/Twilio). Dial lab numbers under `019242…` for fake PSTN; everything else uses real carriers. |
| Peer | **Never** insert office / sippuac into `dr_gateways` |

**Learning (was “ACK residue”):** Not NAT / not OpenSIPS.cfg. SIPp UAS 180/200 must echo Magrathea **Record-Route** or Asterisk ACKs Contact directly → UAS never gets ACK → Magrathea state-3. Keyword: **`[last_Record-Route:]`**, not `[routes]`. Full note: **`call-tests/README.md`** § SIPp leanings.

**Bootstrap sketch:**

```bash
# on VM
sudo apt-get install -y sip-tester
# from Mac
rsync -av -e ssh pbx3/workingdocs/call-tests/ tech@192.168.1.51:~/call-tests/
# on VM: set LOCAL_IP to guest bridged IP; run smokes above
```

EC2 fallback (own EIP, no Peer): same size/SG as §1 if local NAT fails. Spec pointer: **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** §9 lab hosts.

---

## Related

- Pack home: **`README.md`** in this directory  
- Strategy: **`../CALL_TEST_STRATEGY.md`**  
- Catcher tenant on golden: `sipp` / `pb0wsk.pbx3.com` / Twilio DID `+15139279738`  
- Dial alias: **`../TENANT_SHORT_DIAL_REQUIREMENTS.md`**
