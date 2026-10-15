# workingdocs/archive

Historical only. **Do not** read for new-session onboarding.

| File | Source |
|------|--------|
| **TODO_DONE_LOG.md** | Checked-off items formerly in **TODO.md** |
| **snom-d717-settings-exhaustive-lab-402.xml** | Lab D717 full settings export (every key the phone recognises). **#23c** `snomXml.*` OEM-XML twins shipped (classic `snom.*` kept). Tiny shape sample: **`workingdocs/samples/snom-settings-xml-example.xml`**. |
| **yealink-t7x-autoprov-template-common.cfg** | OEM **Yealink SIP Phones AutoProvisioning Template_T7X** — exhaustive `static.*` / site keys (`Yealink-common.cfg`). Line CFG dialect (`#!version:1.0.0.1`); phones do **not** take XML provision params (as of this archive). Stock product grain: **`provisioning/streams/yealink.*`**. |
| **yealink-t7x-autoprov-template-mac.cfg** | Same T7X pack — exhaustive per-MAC / `account.X.*` keys (`Yealink-mac.cfg`). Reference only; do not ship wholesale as soft-fill. |

Agent / SPA **session handoff history** moved to private **`~/GiT/pbx3-ops/archive/`** (`AGENT_HANDOFF_HISTORY.md`, `SESSION_HANDOFF_HISTORY.md`).
