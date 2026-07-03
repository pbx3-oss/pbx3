# Session end checklist

**When the user says:** `session end`, `end session`, or `update handoff` — run this checklist before finishing.

**Purpose:** Keep **one current truth** at the top of handoff files. Do **not** rationalize or rewrite other workingdocs.

---

## Files to update (only these)

| # | File | Action |
|---|------|--------|
| 1 | **`pbx3/workingdocs/TODO.md`** | Check off completed open items. Add new open items from the session. Update **Suggested “what next?”** only if priorities changed. Bump **Last updated** date. |
| 2 | **`pbx3/workingdocs/AGENT_HANDOFF.md`** | Add or replace **`## Next agent session notes (YYYY-MM-DD)`** at the top of that section (below read-order tables). Include: branch(es), what shipped, golden/node follow-ups, resume line. Mark older blocks in that section as historical or leave them below the new block. |
| 3 | **`pbx3spa/workingdocs/SESSION_HANDOFF.md`** | Prepend **`## Session end YYYY-MM-DD — {short title}`** immediately after the “AI: read this first” intro (above older session blocks). Same resume info from the SPA/operator angle. |

---

## Do not

- Rewrite **`PROJECT_PLAN.md`** § Current state (pointer only; handoff + TODO are canonical).
- Edit audit prototypes, **`PANEL_PATTERN.md`**, or feature plans unless the session changed them.
- Create new workingdocs for small fixes.
- **Commit or push** unless the user explicitly asks (e.g. “session end, commit and push”).

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
