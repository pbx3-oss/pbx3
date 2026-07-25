# GenAst characterize fixtures

Phase **A** of the hermit-crab track (`AST_CONFIG_GENERATOR_SUBPROJECT.md`).

## Tools

| Script | Role |
|--------|------|
| `pbx3-1/opt/pbx3/scripts/genast-normalize.php` | Strip volatile banners; sort PJSIP sections; stabilize dialplan exten lines |
| `pbx3-1/opt/pbx3/scripts/genast-characterize.sh` | Normalize two dirs and `diff` |

```bash
# On a node after Commit, copy ready outputs:
mkdir -p /tmp/genast-cap/baseline
cp /opt/pbx3/etc/asterisk/local/pjsip_ready_phones.conf \
   /opt/pbx3/etc/asterisk/local/extensions.conf \
   /tmp/genast-cap/baseline/   # adjust ASTLOCALCONF paths as installed

# After a generator change + Commit:
mkdir -p /tmp/genast-cap/candidate
cp ... same files ... /tmp/genast-cap/candidate/

/opt/pbx3/scripts/genast-characterize.sh \
  /tmp/genast-cap/baseline /tmp/genast-cap/candidate
```

## What to capture (minimum)

- `pjsip_ready_phones.conf`
- `extensions.conf`
- Optional: `pjsip_ready_webrtc.conf`, `pjsip_ready_trunks.conf`, `pjsip_transport.conf`

## Baselining

1. Capture **before** Phase B/C on golden (or from a known-good Commit).
2. After `$row` fix, expect possible dialplan-only diffs if any tenant had `appl` rows — review, then re-baseline.
3. After G2, expect phone ready files to track tmpl (not frozen staging) — re-baseline.

Checked-in golden blobs are optional; lab capture is enough for early phases.
