# Ops: Asterisk after Egress / genAst

**Audience:** Operators on fleet nodes (golden / AMI).  
**Why:** After some PJSIP trunk/template changes, **`module reload res_pjsip.so` / `pjsip reload` is not enough** — Asterisk must be fully restarted or the Egress peer stays wrong/unusable.

---

## Rules of thumb

| Change | What to run |
|--------|-------------|
| SPA **Commit** (normal tenant dialplan / extensions / inroutes) | Panel Commit is enough — it runs **`genAst.sh`** and reloads as designed. |
| **`genAst.sh`** by hand (or after DB restore / rollback) | Prefer **`sudo /opt/pbx3/scripts/genAst.sh`**, then confirm calls. If PJSIP trunks look stale, restart Asterisk (below). |
| Edit **Egress** template / packaged `pjsip_trunk_egress.tmpl` / seed-fleet-egress | **`sudo systemctl restart asterisk`** — do **not** rely on **`pjsip reload` alone**. |
| **Mode 4 / backup restore** of `/etc/asterisk` | **`refresh-pjsip-externip.sh`** (runs from `restore-backup-zip.sh`) — rewrites donor `external_*` to this node's public IP/EIP, then full restart. |
| Hot-patch under `/etc/asterisk/` that only touches non-trunk dialplan | `dialplan reload` or generator reload may suffice; if unsure, full restart. |

**Lab lesson (2026-07-09 Phase A):** After egress template / identify changes on **08jzwn** and **bzy54n**, **`systemctl restart asterisk`** was required. `pjsip reload` alone left the Egress path broken.

---

## Commands (fleet node)

```bash
# Regenerate Asterisk configs + sqlite.rdonly.db from live DB
sudo /opt/pbx3/scripts/genAst.sh

# Required after Egress / PJSIP trunk template changes
sudo systemctl restart asterisk

# Smoke
sudo asterisk -rx "pjsip show endpoint Egress"
sudo asterisk -rx "pjsip show identifies"
sudo systemctl is-active asterisk
```

Commit from the SPA still runs genAst for ordinary admin saves — use a full restart when you change **instance-level Egress** plumbing, not when you only Commit an extension.

---

## Related

- **`FLEET_EGRESS_LAB_ROLLBACK.md`** — lab rollback tags / host recovery  
- **`pbx3-directory/docs/FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** — future OPTIONS qualify (not this note)  
- **`pbx3-directory/docs/FLEET_TRUNK_PEERING_DECISION.md`** — fleet = Egress only on the node  

*Last updated: 2026-07-13*
