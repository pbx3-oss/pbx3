# Call / SIP test strategy (open-source)

**Status:** L1 pack on SIPp EC2 (2026-07-27) — build what we can; **no commercial generators**.  
**Full call-type map (majors + `*NN*` + test columns):** **`CALL_TYPE_INVENTORY.md`**.  
**Recipes:** **[aelintra/sipplabs](https://github.com/aelintra/sipplabs)** (`./run-pack.sh`; catcher + VIP). Stub: **`workingdocs/call-tests/README.md`**.  
**Cadence home:** **`TEST_CADENCE.md`** · inventory **`CRITICAL_PATH_TEST_PACK.md`**.  
**Existing call logic:** **pbx3cagi** `make test` · **`TEST_HARNESS.md`** · **`TEST_RECIPE.md`**.

---

## 1. Intent

We need a **repeatable way to exercise call pathways** (and later light load) on lab, without Spirent/Ixia-class spend. Industry default for SIP shops is **SIPp** for scenarios + load, plus whatever offline unit/AGI coverage you already have.

This doc locks **layers**, **tooling**, **scenario inventory**, and a **build order**. Implementation follows when scheduled — not under release pressure.

---

## 2. Three jobs (do not blur)

| Job | Question | Tooling we will use |
|-----|----------|---------------------|
| **A — Logic** | Did CAGI / helpers choose the right dial string / CF / route? | Existing **offline AGI harness** (`make test`) |
| **B — Pathway** | Does a real SIP call through our stack take the right branch? | **SIPp** (or AMI originate) against **golden / bzy** |
| **C — Load** | How many CPS / concurrent before quality or CPU breaks? | **SIPp** rate/limit + media; lab only |

Chaos (SBC promote under light load, Asterisk restart) stays **ad-hoc lab recipes** — document when run; not a merge gate.

**Non-goals:** commercial load gear; full media MOS in CI; replacing operator PSTN smoke; Playwright as SIP coverage.

---

## 3. Architecture of the pack we will build

```text
┌─────────────────────────────────────────────────────────────┐
│  Pack Call-L0  — already have                                 │
│  pbx3cagi make test (CFIM …)  CI / every CAGI change          │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│  Pack Call-L1  — SIPp scenarios (correctness)                 │
│  Lab box → VIP / DID / extensions on golden (or bzy)          │
│  Assert SIP codes + optional AMI/CDR fingerprints             │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│  Pack Call-L2  — SIPp load profiles (capacity)                │
│  Ramp → soak → spike; record CPS / concurrent / CPU           │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│  Pack Call-L3  — PSTN smoke (operator)                        │
│  Magrathea / Twilio matrix — keep manual; checklist only      │
└─────────────────────────────────────────────────────────────┘
```

L0 stays the **merge-gate** for CAGI. L1 becomes the **lab regression** for dialplan/SBC/CAGI contracts. L2 is **occasional** (after dial-locus or SBC changes). L3 stays human.

---

## 4. Tooling choices (locked)

| Choice | Decision |
|--------|----------|
| Generator | **SIPp** (Debian/Ubuntu package or build from source) |
| Where it runs | Operator Mac or a small lab jump host — **toward golden**, not from CI runners (no public SIP from GitHub Actions) |
| Media | Start **signalling-only** where possible; add RTP (`-m` / pcmu) when measuring capacity |
| Auth / tenants | Use **lab DIDs + lab extensions** already on golden; no production tenants. On fleet nodes the lab tenant **must** be a **catalog** shortuid (Fleet Create) — **`LAB_FLEET_TENANTS.md`**; never SQLite-only. |
| Assertions | SIPp scenario success/fail; optionally `asterisk -rx` / AMI event grep / CDR row for key cases |
| Not used (for now) | pjsua as primary (optional later); Asterisk Test Suite (upstream-focused); commercial |

---

## 5. Scenario inventory (L1 target)

Grow as a **checklist of SIPp XML (or `.sip`) scenarios**. Names are stable IDs for Pack B.  
**Complete call-type list (including shortcodes and L0/L3):** **`CALL_TYPE_INVENTORY.md`**. This §5 is the **near-term L1** subset only.

### 5.1 Inbound / tenant

| ID | Pathway | Assert (sketch) |
|----|---------|-----------------|
| `in-open-ext` | DID → openroute → extension ring/answer | 200 + BYE clean |
| `in-closed-ivr-or-dest` | Force closed (timer or AstDB) → closeroute | Lands on expected dest |
| `in-cfim-local` | CFIM to local ext | No wrong hold clip; answer path |
| `phone-302-local` | Phone SIP **302** → local ext | Lands on Contact user (not AstDB CFIM) |
| `in-cfim-external` | CFIM off-box | Comfort / dial out as designed |
| `in-queue-answer` | DID → queue → agent answer | Bridge up |
| `in-queue-cancel-vm` | Queue agent **486** → failover ext → PostDial VM | Voicemail app |
| `in-multi-tenant-a-b` | Tenant A ↔ B via SBC AoR | No 404 / hairpin |
| `site-dial-a-b` | Site-code short dial A→B | Rings B ext — **sipplab** `site-dial-a-b` + `run-site-dial-a-b.sh` (skeleton 2026-08-04; `SITE_DIAL_DIGITS`; not full pack) |

### 5.2 Outbound / edge

| ID | Pathway | Assert |
|----|---------|--------|
| `out-egress-ok` | Local originate → SIPP_MAIN → Egress (not SIPp phone UAC from Peer EIP) | Egress channel Up |
| `out-busy-or-reject` | Local originate → catcher **486** → PostDial | Voicemail (busy) / Busy() |

### 5.3 Feature / override

| ID | Pathway | Assert |
|----|---------|--------|
| `feat-master-closed` | STAT/OCSTAT CLOSED | DID uses closeroute |
| `feat-holiday-override` | Active holiday route | Dest matches override |

### 5.4 Deferred until day-parts land

Mode/profile scenarios (`in-mode-lunch`, …) — add when **`TIME_BASED_ROUTING_REQUIREMENTS.md`** ships; until then open/close cover the binary fork.

**Expand L0 in parallel:** more `make test` scenarios for CheckState / PrepDial / PostDial where fixtures beat SIPp.

---

## 6. Load profiles (L2)

Keep **separate** from L1 pass/fail.

| Profile | Intent | Starting sketch |
|---------|--------|-----------------|
| `demo` | Demo wallpaper / light DB fill | **~10 concurrent** ext↔ext, 45s hold — `./run-soak.sh start demo` on extension EC2 / sippuac |
| `busy` | Busy-hour stand-in | **~20 concurrent** ext↔ext — `./run-soak.sh start busy` |
| `ramp-find-ceiling` | Find break point | Ramp CPS until error rate or CPU pegs (later) |
| `spike` | Short burst | 2–3× soak rate for 60s (later) |

Provision once: `sipplab/targets/pbx3/provision-soak-phones.sh` (exts 2100–2139 on catcher tenant). Signalling-only is enough for CDR/Home + live demo backdrop. Answerer UAS must echo Magrathea **Record-Route** (`[last_Record-Route:]` in 180/200) or Magrathea leaves state-3 — see **sipplab** `docs/LEANINGS.md` / `docs/NAT_AND_DIALOG.md`.

---

## 7. Build order (when we implement)

| Step | Deliverable | Done when |
|------|-------------|-----------|
| **0** | This doc + Pack pointers | Done |
| **1** | Lab: install SIPp; one **loopback or DID** scenario green (`in-open-ext`) | **Done 2026-07-27** (Mac→VIP→DID→1000) |
| **2** | Scenario dir layout + README | Done → moved to **sipplab** (2026-08-01); stub under `call-tests/` |
| **3** | Grow L1 matrix (§5) | **Pack 11 ids** incl. queue-cancel-vm + out-busy (2026-07-27). Holiday / site-dial / day-parts deferred. **site-dial:** bring **2nd SIPp** (extension platform) when dial-alias starts — **sipplab** `docs/HOST_SETUP.md` / `docs/examples/aelintra-lab.md`. |
| **4** | Optional AMI helper to force OCSTAT / confirm channel | Less manual setup |
| **5** | One soak profile documented on golden | L2 started |
| **6** | Wire L0 (+ later selected L1) into **`CRITICAL_PATH_TEST_PACK.md`** Pack B | Cadence updated |

Do **not** block product tracks on finishing §5. Grow scenarios when dial-locus / SBC / timer work lands (same habit as unit tests in **`TEST_CADENCE.md`**).

---

## 8. Repo layout

Harness lives in **[aelintra/sipplabs](https://github.com/aelintra/sipplabs)** (`scenarios/`, `run-*.sh`, `docs/`, `targets/pbx3/`).  
pbx3 keeps strategy docs here; **`workingdocs/call-tests/`** is a redirect stub only.

---

## 9. Acceptance (strategy level)

1. L0 remains green on every CAGI change.  
2. At least **one** automated SIPp pathway runs against golden by a documented recipe.  
3. Critical pathways from §5 have either SIPp **or** explicit “L0 covers this” **or** “manual L3 only” — no silent gaps.  
4. Load runs are **scheduled lab**, not CI.  
5. No commercial tooling required.

---

## 10. Relation to other work

| Track | Interaction |
|-------|-------------|
| CAGI refactor / day-parts | Add L0 + L1 scenarios when CheckState contract changes |
| GenAst dial-locus | L1 after deploy; L2 before calling capacity “known” |
| SBC HA | Chaos recipe + light L2 during promote (optional) |
| Pack A (API/unit) | Unchanged — different layer |

---

## 11. Revision

| Date | Note |
|------|------|
| 2026-07-26 | Initial strategy: L0–L3, SIPp-only generators, scenario inventory, build order. |
| 2026-08-01 | Recipes extracted to **aelintra/sipplabs**; `workingdocs/call-tests/` stub only. |
| 2026-07-27 | Step 1–2 scaffold: `workingdocs/call-tests/` + `in-open-ext` (Mac→VIP); green run still pending lab allow. |
| 2026-07-27 | `in-open-ext` green: Mac SIPp → Magrathea VIP → DID 01924918076 → golden 1000. Temp Peer gwid 99 (`sipp-lab`). |
| 2026-07-27 | L1 recipes: `in-cfim-local`, `in-closed-ivr-or-dest`, `feat-master-closed`, `in-queue-answer` + `run-sipp.sh`. |
| 2026-07-27 | SIPp catcher tenant + `./run-pack.sh` green (open/CFIM/closed/queue via Twilio DID). |
| 2026-07-27 | `phone-302-local` in pack (catcher A `uas-302` → B answers). |
| 2026-07-27 | `in-multi-tenant-a-b` — peer catcher on affcot + DID→sipp A (AoR domain discrimination). |
| 2026-07-27 | L1 grow: `feat-master-closed` (STAT/OCSTAT), `in-cfim-external`, `out-egress-ok` + catcher `SIPP_MAIN` OutRoute. |
| 2026-07-27 | Status → L1 9/9; `out-egress-ok` assert = Local→Egress Up (Peer EIP blocks phone UAC). |
| 2026-07-27 | + `in-queue-cancel-vm` (agent 486→VM) + `out-busy-or-reject` (Local 486→PostDial). |
