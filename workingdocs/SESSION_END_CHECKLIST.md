# Session end checklist

**When the user says:** `session end`, `end session`, or `update handoff` — run this checklist before finishing.

**Purpose:** Keep **one current truth** at the top of handoff files. Do **not** rationalize or rewrite other workingdocs.

**History:** Older session blocks live in **`workingdocs/archive/`** (and SPA **`workingdocs/archive/`**). Session end does **not** append into those archives. Optional garden: when the live handoff grows past ~a few historical stubs, move superseded blocks into the matching archive file.

---

## Files to update (only these)

| # | File | Action |
|---|------|--------|
| 1 | **`pbx3/workingdocs/TODO.md`** | Check off **open** items by removing or flipping and **not** re-building a long closed list here — completed work is git + optional one-liner in handoff. Add new open items from the session. Update **Suggested “what next?”** only if priorities changed. Bump **Last updated** date. Closed ledger archive: **`archive/TODO_DONE_LOG.md`**. |
| 2 | **`pbx3/workingdocs/AGENT_HANDOFF.md`** | Add or replace **`## Next agent session notes (YYYY-MM-DD)`** as the single current block (below read-order tables; above **Session history (archived)** pointer). Include: branch(es), what shipped, golden/node follow-ups, resume line. |
| 3 | **`pbx3spa/workingdocs/SESSION_HANDOFF.md`** | Prepend **`## Session end YYYY-MM-DD — {short title}`** immediately after the “AI: read this first” intro (above the archive pointer / Quick start). Same resume info from the SPA/operator angle. |

---

## Do not

- Rewrite **`PROJECT_PLAN.md`** § Current state (pointer only; handoff + TODO are canonical).
- Edit audit prototypes, **`PANEL_PATTERN.md`**, or feature plans unless the session changed them.
- Create new workingdocs for small fixes.
- **Commit or push** unless the user explicitly asks (e.g. “session end, commit and push”).

---

## Optional — code-review graph (non-trivial code only)

**Skip** when the session was docs-only, handoff-only, or lab/ops with **no** meaningful repo diffs.

**Do** when the session shipped **non-trivial code** (api / spa / sbc / scripts / multi-file behaviour):

1. In each **touched git repo** (e.g. `pbx3api`, `pbx3spa`, `pbx3` — not the holding folder alone), ensure the graph is current:
   ```bash
   cd /path/to/repo
   uvx code-review-graph build   # or status first; incremental is fine if already built
   ```
2. Ask for (or run via MCP) a **graph-backed review** of **branch changes** vs the default base (or **uncommitted** if not committing yet): blast radius, callers, risky hubs — surface anything that should block commit/push.
3. Note in the handoff **Resume** / **Shipped** only if the review found follow-ups worth tracking.

Requires Cursor MCP **`code-review-graph`** (green). No graph for a repo yet → build once before reviewing that repo.

---

## `AGENT_HANDOFF.md` block template

```markdown
## Next agent session notes (YYYY-MM-DD)

**Branch:** **`main`** in pbx3, pbx3api, pbx3spa (note any feature branch).

### Shipped
- …

### Golden / operator follow-up
- …

### Resume
- …
```

---

## `SESSION_HANDOFF.md` block template

```markdown
## Session end YYYY-MM-DD — {title}

**Merged to `main`** / **on branch `…`**: one-line summary.

**Dev against golden:** …

**Docs / TODO:** pointer to **`pbx3/workingdocs/TODO.md`**.

**Resume:** …
```

---

## pbx3api-only sessions

If only **pbx3api** changed: still update **`TODO.md`** and **`AGENT_HANDOFF.md`**. Update **`SESSION_HANDOFF.md`** only if API behaviour affects SPA operators or golden deploy notes.

---

## Cross-references

- **`AGENT_HANDOFF.md`** — read-order table includes this file under session end.
- **Cursor rule:** `.cursor/rules/session-end-handoff.mdc` (workspace and per-repo copies).

---

## New session (for user)

When starting a **new chat**, the user may say: **`New session — read handoff and summarize.`**

1. Read **`AGENT_HANDOFF.md`** § **Next agent session notes** → **`TODO.md`** → **`pbx3spa/workingdocs/SESSION_HANDOFF.md`** (top **Session end** block only).
2. Reply with: branch state, what shipped recently, open priorities (from TODO), suggested next — then **wait for the user’s task** before coding.

Optional task-specific reads: **`FEATURE_PLANS_INDEX.md`**, **`PANEL_PATTERN.md`**, **`pbx3-directory/docs/PLANNING_HANDOFF.md`**.
