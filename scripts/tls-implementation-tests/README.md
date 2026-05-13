# TLS Option A — implementation step tests

Shell checks for **`workingdocs/TLS_IMPLEMENTATION_STEPS.md`**. They are **gates**: pass means the step’s artefacts/behaviour appear present; fail means fix before relying on that step.

## Layout

| Script | What it checks |
|--------|------------------|
| **`step0.sh`** | SQLite **`globals`/`cluster`** (default tenant FQDN), optional **pbx3api** GET/PUT **`/api/sysglobals`**, tenant **`fqdn`** immutability smoke |
| **`step1.sh`** | **pbx3** repo / install tree: multi-SAN first-cert script, **`update-fqdn-inline`**, **`NetHelperClass`** SIP inline behaviour (grep) |
| **`step2.sh`** | **pbx3api** source + optional live **`/certificates/*`** if token + base URL set |
| **`step3.sh`** | **pbx3spa** source grep for Certificates / tenant FQDN UI |
| **`step4.sh`** | Cron / renew script references, doc pointers (non-destructive) |
| **`run-all.sh`** | Runs **step0** → **step4**; exit non-zero if any step failed |

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| **`PBX_SQLITE`** | `/opt/pbx3/db/sqlite.db` | Instance DB (on PBX or copied to your machine) |
| **`PBX3API_BASE`** | *(empty)* | e.g. `https://pbx.example.com:44300` — no trailing slash |
| **`PBX3API_TOKEN`** | *(empty)* | Sanctum **Bearer** token; if unset, API checks are **skipped** |
| **`PBX3_ROOT`** | Auto: parent of **`scripts/`** | **pbx3** repo root (for grepping packaged scripts) |
| **`PBX3API_ROOT`** | `$PBX3API_ROOT` env if set; else **`/opt/pbx3api`** when that tree exists; else **`$PBX3_ROOT/../pbx3api`** | **pbx3api** tree for greps (on PBX, home clone is often stale — default prefers **`/opt/pbx3api`**) |
| **`PBX3SPA_ROOT`** | `$PBX3_ROOT/../pbx3spa` | **pbx3spa** repo |
| **`PBX3_OPT`** | `/opt/pbx3` | On-box install prefix for **step1** “installed script” checks |

## Run

From clone (macOS / Linux with **bash**, **sqlite3**, **curl**). **Do not** run with **`sh step0.sh`** — on Ubuntu **`sh`** is **dash**, which ignores the **`#!/usr/bin/env bash`** line and then **`set -o pipefail`** fails. Use **`./step0.sh`** (after **`chmod +x`**) or **`bash step0.sh`**.

```bash
cd pbx3/scripts/tls-implementation-tests
chmod +x *.sh
./step0.sh
```

All steps:

```bash
PBX_SQLITE=/path/to/sqlite.db PBX3API_BASE=https://host:44300 PBX3API_TOKEN='…' ./run-all.sh
```

**Note:** Step **0** API tests need a token that can call **`sysglobals`** and **`tenants`**. Step **2** live tests need cert routes implemented; until then they mostly **grep** the repo and **skip** HTTP checks.

## When to run

- After each merge on **`certificates`** (or your feature branch).
- On the **PBX host** for SQLite + `/opt/pbx3` checks; from **CI** point **`PBX_SQLITE`** at a fixture DB if you add one later.
