# AI-assisted operator — requirements (OSS posture)

**Status:** Locked intent 2026-09-28 (docs + prompts first; tooling polish follows).  
**Audience:** Product, docs, org README authors.  
**Operator face:** MkDocs — `getting-started/ai-assisted.md`, `installation/ai-assisted-install.md`, `fleet/agent-assisted.md`.

## 1. Intent

PBX3’s public face should **promote AI coding agents as a normal operator tool** — not only for developers writing code, but for **getting work done**: install, Lab bring-up, fleet onboard/rebuild, routine ops.

Classical CLI / MkDocs steps remain **canonical**. The AI path is the **preferred on-ramp** for newcomers: paste a kickoff prompt, let the agent drive the documented installers, **human owns gates**.

This is **operator co-pilot**, not a chat support bot for live calls, and not a substitute for product installers.

## 2. Non-negotiables

| # | Lock |
|---|------|
| A1 | Agent **runs/follows** published installers and runbooks (`install-home-host.sh`, Lab scripts, directory tools). It must **not** invent a parallel one-off install path. |
| A2 | **Human gates** for destructive or spend-adjacent acts (list in §4). Agent stops and asks. |
| A3 | **No secrets in browser / SPA.** Ops IAM, long-lived cloud keys, and deploy credentials stay on operator Mac / CI secrets — never baked onto nodes or pasted into public issue trackers. Aligns with Design Rules (catalog → SPA one-way; no browser ops IAM). |
| A4 | **Vendor-neutral wording** in public docs: “an AI coding agent (e.g. Cursor)”. Cursor is the dogfood example, not a hard dependency. |
| A5 | Canonical docs stay accurate for **humans without an agent** (break-glass / audit). AI path points *at* them; it does not replace them. |
| A6 | Agent must prefer **in-repo / MkDocs truth** over inventing fleet topology, package floors, or Peer recipes. |

## 3. Surfaces (ship order)

| Surface | Role | Priority |
|---------|------|----------|
| MkDocs **AI-assisted** getting-started + install kickoffs | Primary newcomer story | **P0** (this land) |
| Fleet **agent-assisted** onboard/rebuild (existing) | Interim until S10.7 / S8.9 | P0 (keep; cross-link) |
| Root **`AGENTS.md`** on public repos | Machine-oriented “where truth lives + gates” | P0 thin stubs |
| Org / repo **README** blurb | “Try with an AI agent” above the long CLI | P1 with org move |
| Optional Cursor rules in product trees | Enforce A1–A6 for maintainers | P2 |

## 4. Human gates (minimum set)

Agent **must ask** before:

- Launch / terminate / resize cloud VMs  
- DNS cutover or deletion of live records  
- Let’s Encrypt / cert changes that affect production FQDNs  
- IAM policy changes; creating/disabling long-lived access keys  
- Destroying tenants, wiping instance DBs, or irreversible fleet unregister  
- Spending money (paid carrier, marketplace AMI, non-free APIs) beyond what the human already approved in the kickoff  
- Force-push / history rewrite on shared remotes  

Human **holds**: cloud console login, DNS panel, ops AWS credentials, production admin passwords (agent may use SSH keys already on the Mac when the human has configured them).

## 5. Kickoff prompt contract

Every public kickoff prompt SHOULD include:

1. **Goal** (one sentence)  
2. **Doc path(s)** to follow (MkDocs or in-repo runbook)  
3. **Worksheet facts** as `{placeholders}` (host, email, apex, …)  
4. **Ask-before** list (subset of §4 relevant to that job)  
5. **Done when** (observable check: `/up` 200, preflight green, …)

Prompts live in MkDocs so they stay versioned with the installers.

## 6. Out of scope (v1)

- Hosted “PBX3 GPT” or mandatory cloud LLM  
- Agent controlling the live SIP path or dialplan without human-reviewed GenAst  
- Replacing Gatekeeper / fleet jobs with chat  
- Guaranteeing a specific vendor’s agent quality  

## 7. Related

- MkDocs: `getting-started/ai-assisted.md` · `installation/ai-assisted-install.md` · `fleet/agent-assisted.md`  
- Design Rules 1, 6, 8 (call path; solo; catalog → SPA)  
- OSS org move: promote this on `github.com/pbx3` README when org exists  
- Parked orchestrated onboard: S10.7 / S8.9 — agent-assisted remains interim for fleet rebuild
