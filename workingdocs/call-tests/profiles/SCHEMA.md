# Traffic profile YAML schema

Profiles live as `profiles/<id>.yaml`. Soak knobs (`demo.env` / `busy.env`) stay `.env` for `run-soak.sh` only.

## Required top-level

| Field | Type | Meaning |
|-------|------|---------|
| `id` | string | Stable profile id (`mixed-office`, …) |
| `version` | int | Schema version (start at `1`) |
| `description` | string | One-line intent |
| `source` | object | Optional CDR provenance |
| `concurrency` | object | Target simultaneous answered calls |
| `timing` | object | Hold / interarrival |
| `paths` | object | Mix of Domain / Numbers / queue |
| `queue` | object | Agent pool + strategy (omit for freephone-trunk) |

## `concurrency`

```yaml
concurrency:
  target: 4          # peak answered (v1 mixed-office = CDR peak)
  scale: 1.0         # multiply target later for “busier” wallpaper
```

## `timing`

```yaml
timing:
  hold_ms:
    p50: 50000
    p90: 291000
    default: 50000   # runner uses this until distribution sampling lands
  interarrival_ms:
    busy_p50: 73000  # hour-8 gap from CDR; wallpaper may use faster cadence
  answer_weights:    # disposition mix
    answered: 0.74
    no_answer: 0.22
    busy: 0.04
```

## `paths` (fractions, ≈1.0)

```yaml
paths:
  domain_ext: 0.27      # ext↔ext
  numbers_in: 0.63      # DID / inbound PSTN-shaped
  numbers_out: 0.00     # filled when outbound-heavy / freephone encoded
  other: 0.10
  to_queue: 0.16        # multi-leg / ring-group-ish share → queue path
```

v1 runners may implement a **subset** (e.g. Domain + queue only); unused path weights stay documentary until wired.

## `queue`

```yaml
queue:
  pkey: "2160"          # dedicated soak queue (not L1 2060)
  strategy: rrmemory    # default; ringall optional
  agent_n: 4            # static members from soak answerers 2120+
  member_ext_first: 2120
```

## Example runner binding

- `run-soak.sh` — Domain 1:1 pairs; ignores YAML until a profile driver exists.
- `run-queue-rr.sh` — reads `queue.*` + `concurrency.target` / `timing.hold_ms.default` from a named profile (or flags).
