# Call tests moved → sipplab

SIPp lab harness (runners, scenarios, profiles, docs) now lives in a dedicated repo:

**https://github.com/aelintra/sipplab** (private)

```bash
git clone https://github.com/aelintra/sipplab.git
cd sipplab
cp lab.env.example lab.env   # or restore your local secrets
# Domain:  rsync to sippuac
# Peer:    rsync to catcher
```

pbx3 strategy / inventory docs stay here (`CALL_TEST_STRATEGY.md`, `CALL_TYPE_INVENTORY.md`, …).  
Provision soak phones/queue: `sipplab/targets/pbx3/`.

This directory is a **stub only** — do not add runners here.
