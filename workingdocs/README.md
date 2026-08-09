# workingdocs

**AI:** Session state is private — start at **`~/GiT/pbx3-ops/AGENT_HANDOFF.md`** (§ Next agent session notes) → this folder’s **`TODO.md`** → **`~/GiT/pbx3-ops/TODO_OPS.md`** → **`~/GiT/pbx3-ops/SESSION_HANDOFF.md`** (top Session end only).

Product stub: **`AGENT_HANDOFF.md`** (behavior + read-order + permanent reference). Do not put tip/host gossip in public **`TODO.md`**.

**Stance (2026-08-09):** Keep **active requirements / locks / install** in product (agent locality). Move **research, audits, tippy lab, stale plans** to **`~/GiT/pbx3-ops/devdocs/`** (public-clone cleanliness). Thin stubs remain where links were heavy.

**User guides (operators):** MkDocs / **`pbx3-docs`** — map: **USER_GUIDES_MKDOCS_CONTENT_MAP.md**. This folder is **developer + AI** only.

## Map (keep this short)

| Kind | Where | Examples |
|------|--------|----------|
| **Live session (private)** | **`~/GiT/pbx3-ops/`** | `AGENT_HANDOFF.md`, `SESSION_HANDOFF.md`, `TODO_OPS.md` |
| **Research / audits (private)** | **`~/GiT/pbx3-ops/devdocs/`** | `*_RESEARCH.md`, audit prototypes, lab rollback |
| **Session archaeology (private)** | **`~/GiT/pbx3-ops/archive/`** | handoff histories |
| **Product roadmap** | `TODO.md` | Suggested order + open product items |
| **Pre-release go/no-go** | `PRE_RELEASE_SAFETY_DEBT.md` | Fix-now safety cluster before release |
| **Closed ledger** | **`archive/TODO_DONE_LOG.md`** | Checked-off items |
| **Session end habit** | **`~/GiT/pbx3-ops/SESSION_END_CHECKLIST.md`** | Stub: `SESSION_END_CHECKLIST.md` |
| **Locked product / fleet** | Prefer **`pbx3-directory/docs/`** when fleet-wide | DESIGN_RULES, runbooks, dialect reqs |
| **Feature plans (instance)** | This folder | TLS, short dial, time-based routing, test packs |
| **Repos / releases** | **REPOS_AND_RELEASES.md** | Multi-repo policy |

**Do not** re-grow closed TODO checkmarks in **TODO.md** — closed ledger → **archive/TODO_DONE_LOG.md**.

**Repos / releases:** **REPOS_AND_RELEASES.md**.  
**Tests:** **TEST_CADENCE.md** · **CRITICAL_PATH_TEST_PACK.md**.  
**TLS index:** **TLS_AND_CERTIFICATES.md**.  
**Fleet auth stance:** **FLEET_AUTH_COOKIE_SSO.md**.
