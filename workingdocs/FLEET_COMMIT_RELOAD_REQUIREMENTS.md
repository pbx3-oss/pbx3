# Fleet home — Commit reload & REGISTER via SBC (closed 2026-08-19)

**Status:** **Closed** — lab investigation complete; **no product code change** required for Commit reload.  
**Item:** product **`TODO.md`** **#5j** (was P0; reclassified).  
**Related:** **`OPS_ASTERISK_AFTER_EGRESS_GENAST.md`** · **`FLEET_TRUNK_PEERING_DECISION.md`** §4 · **`pjsip_trunk_egress.tmpl`** · MkDocs **`installation/install-lab-adopt.md`**.

---

## Product decision (2026-08-19)

Operators **Commit** after most admin saves. Same bar as SARK: **`genAst.sh` + reload** — **no** full **`systemctl restart asterisk`** on Commit; **active calls must not drop**.

| Decision | Lock |
|----------|------|
| Commit reload | **`genAst` + `core reload`** — **confirmed OK** on stable fleet home (lab **`.31`**) |
| Active calls on Commit | **Must not drop** — **passed** (101↔102 with Commit ×2 + new ext **103**) |
| **#5j-b** post-Commit reload breaks REGISTER | **Not reproduced** — no code fix; no P0 |
| **#5j-a** REGISTER before phone endpoint in Asterisk | **Expected** — benign log; ops/docs only |
| **Rejected** | Restart-on-Commit; dual-SBC-IP split; treating **#5j-a** log as Commit/reload defect |

---

## Two phenomena (do not conflate)

### #5j-a — Unknown username / pre–first-Commit REGISTER (expected)

Phones register **via SBC** → home sees source IP **= SBC**. **`Egress`** has **`type=identify`** for inbound INVITEs. If REGISTER has **no matching phone endpoint** in running PJSIP (extension **Saved** not **Committed**, stale creds from prior lab tenant, or **bogus username**), username lookup fails → **IP identify → Egress** →:

```text
AOR '' not found for endpoint 'Egress' (192.168.1.85:5060)
AccountID=Egress  RequestType=registrar_requested_aor_not_found
```

**Not** “lost SBC address.” **Not** a reload bug. Phone retries; **Commit** or correct creds → normal **`SuccessfulAuth`** on shortuid.

| Lab repro | Result |
|-----------|--------|
| Bring-up **19:38:18** (before first Commit **19:38:33**) | **Egress** — recovery **19:38:49** **`jxpg8b`** |
| Wrong **username** **22:54:22** | **Egress** (same signature) |
| Wrong **password**, username **`jxpg8b`** **22:52:31** | **`Failed to authenticate`** on **`jxpg8b`** — **not** Egress |

### #5j-b — Post-Commit reload breaks working registration (product bar)

Would be a **P0** if reproduced: committed extensions, registered phones, Commit → call drop or persistent unregistered until restart.

| Lab repro | Result |
|-----------|--------|
| Commit with **active call** (×2) | **Call stayed up** |
| Create ext **103** + Commit with call up | **Call stayed up** |
| **`genAst` + `core reload`** / **`pjsip reload`** (CLI) | Contacts stayed **Avail** |

**Track 1 / 2 / 3 code paths:** **not scheduled** unless **#5j-b** reproduces in the field.

---

## Operator guidance (fleet adopt)

1. **Commit** after creating/editing extensions **before** pointing phones at the SBC (or expect transient **Egress** REGISTER lines until Commit).  
2. Reused lab phones aimed at **`.85`** from a **prior tenant** may REGISTER with stale shortuid until updated — same **#5j-a** log until Commit + correct auth.  
3. Full Asterisk restart: **break-glass** only (**`OPS_ASTERISK_AFTER_EGRESS_GENAST.md`**) — not for normal Commit.

MkDocs: **`installation/install-lab-adopt.md`** § Two phones (ordering note added 2026-08-19).

---

## Optional follow-up (nice, not blocker)

- SPA hint when **`mycommit=YES`** and fleet posture: “Commit before aiming phones at SBC.”  
- Suppress or downgrade **#5j-a** log noise (GenAst / identify split) — **only if** product wants cleaner logs; not required for fitness.

---

## Session log

| Date | Note |
|------|------|
| 2026-08-19 | Locked P0; Track 1; restart-on-Commit rejected |
| 2026-08-19 PM | Historical **19:38:18** Egress; recovery after first Commit |
| 2026-08-19 PM | Operator Commits with active call — pass |
| 2026-08-19 PM | Wrong password → **`jxpg8b`** auth fail; wrong username → **Egress** (matches **#5j-a**) |
| 2026-08-19 PM | **Closed:** **#5j-b** not repro’d; **#5j-a** expected; docs only |
