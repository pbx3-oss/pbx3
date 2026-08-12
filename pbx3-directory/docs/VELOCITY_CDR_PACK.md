# Velocity CDR test pack

**Status:** Pack v1 (2026-08-11) — IRSF query surface.  
**Spec:** **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`**.  
**Code:** `VelocityCdrPack` · artisan **`pbx3:cdr-velocity-pack`** · Pest `VelocityCdrPackTest`.

## Purpose

Repeatable fixture decks against **`VelocityCdrQuery`** so IRSF velocity stays green without SIPp. Scanner notify/act is covered by **`VelocityIrsfScannerTest`**; this pack owns the **CDR input contract**.

## Run

```bash
cd /opt/pbx3api   # or local checkout
php artisan pbx3:cdr-velocity-pack
# or
./vendor/bin/pest tests/Unit/VelocityCdrPackTest.php
```

Exit **0** = all PASS. Lab default premium prefix **`0900` / `+44900` / `0044900`**; threshold **N=10**, window **T=5**.

## Cases (v1)

| Id | Deck / setup | Expect |
|----|----------------|--------|
| `irsf_burst_counts` | `irsf` ×12 | Query total=12 for src |
| `under_threshold_visible` | `irsf` ×3 | total=3 and &lt; N (scanner would not fire) |
| `internal_noise_excluded` | `internal-noise` | total=0 |
| `mixed_premium_only` | `mixed` ×10 | 5–9 premium rows only |
| `failed_scan_counts` | `failed-scan` ×12 | Failed/busy premium still counted (attempt surge) |
| `threshold_gate` | `irsf` ×N | count ≥ N → fires |

## Manual scanner prove (optional)

Point a lab copy, seed, then run scanner with Gatekeeper configured:

```bash
php artisan pbx3:cdr-fixture --deck=irsf --count=12 --src=1001 \
  --path=/tmp/cdr-lab.db --force --probe
# set PBX3_CDR_SQLITE_PATH=/tmp/cdr-lab.db and PBX3_OPS_VELOCITY_ENABLED=true …
php artisan pbx3:ops-velocity
```

Do **not** enable **`PBX3_OPS_VELOCITY_ACT`** on a shared lab phone without choosing a sacrificial extension.

## Later decks (not in pack v1)

Saturday-night / CFIM / dormant / concurrency — add when those detectors ship. Fixture approaches already listed in the requirements § Lab testing.
