# Fleet egress lab — rollback reference (2026-07-09)

**Purpose:** Known-good git tags and recovery steps if post-push issues appear on golden, SBC, or SPA dev. Pushed **2026-07-09** after successful PSTN outbound with audio (phone → SBC → golden → Egress → SBC → carrier).

**Important:** Pushing git does **not** change production. Live hosts were hot-patched during the lab session; rollback requires redeploy/revert on each host as below.

---

## What was validated

- Outbound PSTN from fleet node (**08jzwn**) via **Egress** trunk
- SBC peering **Phase 0–2** (outbound `do_routing(0)` to test carrier **ael.vcloudpbx.com**)
- Early media, ringback, answer, two-way audio

---

## Git tags (on GitHub — permanent escape route)

| Repo | Branch pushed | Good commit (validated) | Rollback tag → commit |
|------|---------------|-------------------------|------------------------|
| **pbx3** | `fleet-phase-a` | `117340f` · tag `fleet-egress-lab-validated-20260709` | `rollback/pre-egress-qualify-20260709` → `94d6203` |
| **pbx3spa** | `fleet-phase-a` | `c27e6d5` · tag `fleet-spa-lab-validated-20260709` | `rollback/pre-nav-accordion-fix-20260709` → `11b023d` |
| **pbx3sbc** | **`main`** | `8c702fb` · tag `fleet-peering-lab-validated-20260709` | `rollback/pre-fleet-peering-egress-20260709` → `1d9433d` |

List tags anytime:

```bash
git fetch --tags
git tag -l 'rollback/*20260709' 'fleet-*-20260709'
```

---

## Code changes in the validated commits

### pbx3 (`117340f`)

- `pjsip_trunk_egress.tmpl` — **`qualify_frequency=0`** (OPTIONS to SBC marked Egress Unavail → `invalid URI 'Egress'`)
- `seed-fleet-egress-trunk.sh` — repoints **`PDH%` / `%IAX%`** routes to **Egress**

### pbx3sbc (`8c702fb`)

- **`opensips.cfg.template`**
  - Asterisk outbound PSTN **before** `is_from_gw()` (golden IP is also in `dr_gateways` for inbound)
  - **`record_route()`** on egress INVITE
  - Asterisk ACK: **`t_relay()`** first (carrier leg), `forward()` fallback (phones)
  - OpenSIPS 3.6: `do_routing(0)` / `do_routing(1)` (integer, not quoted)
  - `failure_route[DR_FAILOVER]`: `t_relay()` not `route(RELAY)`
- **`scripts/apply-peering-phase0-2.sh`**, **`scripts/peering-seed-lab.sh`**

### pbx3spa (`c27e6d5`)

- **`AppLayout.vue`** — `navGroups.value` in accordion helpers (computed ref fix)

---

## Rollback options (pick one)

### A. Git revert (safest on shared `main`, especially pbx3sbc)

Creates a new commit that undoes the change; no history rewrite.

```bash
# pbx3sbc (on main)
cd pbx3sbc && git revert 8c702fb && git push

# pbx3 (on fleet-phase-a)
cd pbx3 && git revert 117340f && git push

# pbx3spa (on fleet-phase-a)
cd pbx3spa && git revert c27e6d5 && git push
```

Then redeploy hosts from reverted templates (see § Production below).

### B. Checkout rollback tag (templates only)

```bash
git fetch --tags
git checkout rollback/pre-fleet-peering-egress-20260709 -- config/opensips.cfg.template
# apply to live SBC, validate, restart opensips
```

Same pattern for pbx3 / pbx3spa files listed in § Code changes.

### C. Reset local branch (only if commit was never pushed or team agrees)

Not needed now — tags preserve both states. Prefer **revert** on **`pbx3sbc/main`**.

---

## Production rollback (live hosts)

### SBC (`sbc.pbx3.com`)

1. In repo: checkout **`rollback/pre-fleet-peering-egress-20260709`** template (or revert on `main`).
2. Apply template to **`/etc/opensips/opensips.cfg`** (or re-run **`apply-peering-phase0-2.sh`** from rollback tag).
3. `sudo opensips -c` then `sudo systemctl restart opensips`.
4. Optional: `dr_*` seed data is unchanged; only routing script order/ACK behavior reverts.

### Golden fleet node (`08jzwn.pbx3.com`)

1. **`pjsip_trunk_egress.tmpl`**: restore from rollback tag or set **`qualify_frequency=30`** again (will break egress dial until fixed another way).
2. **`/opt/pbx3/etc/asterisk/configs/pjsip_ready_trunks.conf`**: match template, `sudo asterisk -rx "module reload res_pjsip.so"`.
3. **Routes**: if needed, restore legacy `path1` from backup or undo seed SQL (`path1='Egress'` → prior trunk names).
4. `sudo /opt/pbx3/scripts/genAst.sh` to refresh **`sqlite.rdonly.db`**.

### SPA dev

Rebuild from **`rollback/pre-nav-accordion-fix-20260709`** if sidebar accordion regresses.

---

## Live state vs git (2026-07-09 session)

These were applied **on hosts** during the lab; align with validated tags when installing debs or re-running genAst:

| Host | Live patch |
|------|------------|
| Golden | `qualify_frequency=0` on Egress; routes repointed to Egress; template under `/opt/pbx3/etc/asterisk/templates/` |
| SBC | Peering route order, Record-Route, ACK `t_relay()`; carrier seed **gwid 1** → ael, **gwid 10** → golden |

---

## Related docs

- **`pbx3-directory/docs/FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** — future: OPTIONS qualify, EgressFailover, trunk health
- **pbx3sbc/workingdocs/PEERING-PLAN.md** — peering phases
- **pbx3sbc/docs/guides/troubleshooting/AUDIO-FIX-ACK-HANDLING.md** — endpoint ACK patterns (egress uses carrier leg)
- **AGENT_HANDOFF.md** § Next agent session notes

---

*Last updated: 2026-07-09 — fleet egress lab validated, tags pushed.*
