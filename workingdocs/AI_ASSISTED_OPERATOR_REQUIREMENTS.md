# AI-assisted operator — requirements (OSS posture)

**Status:** Locked intent 2026-09-28; cons mitigations same day; **positioning decision locked:** CLI decks lead — AI is thin optional co-pilot, not a panacea.  
**Audience:** Product, docs, org README authors.  
**Operator face:** MkDocs — classical Install first; AI pages are parallel (`getting-started/ai-assisted.md`, `installation/ai-assisted-install.md`, `fleet/agent-assisted.md`).

## 0. Positioning decision (locked)

| Decide | Lock |
|--------|------|
| **Way forward** | **Classical CLI / MkDocs procedure pages** — what we stand behind, test, and triage. |
| **AI path** | **Thin optional parallel** for people who already use an agent IDE: same scripts, stepwise + gates, austere honesty. |
| **Not** | AI-led marketing, “preferred”/only serious path, unattended install, or a substitute for install UX polish. |
| **Why both** | Agents will hit the repos anyway; kickoffs steer them onto published procedures. Skipping AI docs does not stop freelancing — it only removes our steering. |
| **Panacea** | **AI is not yet a panacea.** Residual SoTA agent error remains after stepwise checks (A11). Docs must not imply otherwise. |
| **Provenance (README)** | Short honest preamble on public READMEs: designed by humans mid/late 2025; most code implemented in Cursor under **human-directed AI** — not unattended. Canonical blurb: `~/GiT/pbx3-ops/devdocs/oss-move/snippets/GITHUB_README_DOCS_BLURB.md`. |

Rollout checklist: `~/GiT/pbx3-ops/devdocs/oss-move/AI_ASSISTED_POSTURE_ROLLOUT.md` (must honor §0).

## 1. Intent

PBX3’s public face may **document** AI coding agents as a **supported optional operator tool** — for install, Lab bring-up, fleet onboard/rebuild, routine ops — without making that the product’s lead story.

Classical CLI / MkDocs steps remain **canonical and complete**. The AI path is a **first-class parallel on-ramp** for people who already use an agent IDE: paste a kickoff, let the agent drive the documented installers, **human owns gates**. It is **not** “the only serious way,” and it must not sound like unattended install.

This is **operator co-pilot**, not a chat support bot for live calls, and not a substitute for product installers or for finishing install UX.

**Operating method (locked):** drive the agent in **small steps** with an observable **check after each step** (the kickoff’s “done when,” or a sub-check called out in the canonical page). That is how maintainers actually limit agent damage. It **reduces** off-script and silent drift; it does **not** eradicate them. Residual agent error is an **existential limit of current coding agents**, not something PBX3 docs can patch away — copy and support stance must stay honest about that (A7, A10, §6).

## 2. Non-negotiables

| # | Lock |
|---|------|
| A1 | Agent **runs/follows** published installers and runbooks (`install-home-host.sh`, Lab scripts, directory tools). It must **not** invent a parallel one-off install path. |
| A2 | **Human gates** for destructive or spend-adjacent acts (list in §4). Agent stops and asks. |
| A3 | **No secrets in browser / SPA.** Ops IAM, long-lived cloud keys, and deploy credentials stay on operator Mac / CI secrets — never baked onto nodes or pasted into public issue trackers. Aligns with Design Rules (catalog → SPA one-way; no browser ops IAM). |
| A4 | **Vendor-neutral wording** in public docs: “an AI coding agent (e.g. Cursor)”. Cursor is the dogfood example, not a hard dependency. |
| A5 | Canonical docs stay accurate for **humans without an agent** (break-glass / audit). AI path points *at* them; it does not replace them. **Equal citizenship:** classical pages must remain a full install path. |
| A6 | Agent must prefer **in-repo / MkDocs truth** over inventing fleet topology, package floors, or Peer recipes. |
| A7 | **Austere promise:** never market “AI installs PBX3 for you,” “unattended,” or “no Linux required.” Always: co-pilot + gates + same scripts. |
| A8 | **Secrets vs chat:** kickoffs tell humans to put passwords/keys in **shell env / SSH agent**, and tell the agent **variable names only** — do not paste secret values into the chat. Warn that third-party LLM logs are outside our control. |
| A9 | **PSTN / dialplan / Peer changes** are human-gated (subset of §4). Agent does not “fix signaling” by freelancing OpenSIPS or GenAst. |
| A10 | **Support stance:** project reproduces against **canonical docs/scripts**. Agent transcripts are optional context; “the model did X” is not a defect in PBX3 unless the **documented** path is wrong. |
| A11 | **Stepwise execution:** kickoffs and getting-started tell operators to proceed **one step (or short phase) at a time**, verify the check, then continue. Discourage “do the whole install in one shot” prompts. |

## 3. Surfaces (ship order)

| Surface | Role | Priority |
|---------|------|----------|
| MkDocs **AI-assisted** getting-started + install kickoffs | Parallel newcomer story (with classical) | **P0** (landed 2026-09-28) |
| Fleet **agent-assisted** onboard/rebuild (existing) | Interim until S10.7 / S8.9 | P0 (landed; cross-linked) |
| Root **`AGENTS.md`** on public repos | Machine-oriented “where truth lives + gates” | P0 thin stubs (`pbx3`, `pbx3-docs` done; rest in rollout) |
| Org / repo **README** blurb | Shared MkDocs pointer + CLI-first / optional AI lines (**same block** on each public README) | P1 |
| GitHub **About** sidebar | Short per-repo description + **Homepage** = MkDocs site URL | P1 |
| Bug / issue hygiene | Template fields: doc page + step; optional agent note | P1 |
| Optional Cursor rules in product trees | Enforce A1–A11 for maintainers | P2 |

**Execution checklist (docs-only posture):** private ops **`~/GiT/pbx3-ops/devdocs/oss-move/AI_ASSISTED_POSTURE_ROLLOUT.md`**.

## 4. Human gates (minimum set)

Agent **must ask** before:

- Launch / terminate / resize cloud VMs  
- DNS cutover or deletion of live records  
- Let’s Encrypt / cert changes that affect production FQDNs  
- IAM policy changes; creating/disabling long-lived access keys  
- Destroying tenants, wiping instance DBs, or irreversible fleet unregister  
- Spending money (paid carrier, marketplace AMI, non-free APIs) beyond what the human already approved in the kickoff  
- Force-push / history rewrite on shared remotes  
- Changing **live** Peer / drouting / dialplan / GenAst behaviour on a non-Lab system (Lab: still ask if destructive or off-doc)

Human **holds**: cloud console login, DNS panel, ops AWS credentials, production admin passwords (agent may use SSH keys already on the Mac when the human has configured them).

## 5. Kickoff prompt contract

Every public kickoff prompt SHOULD include:

1. **Goal** (one sentence)  
2. **Doc path(s)** to follow (MkDocs or in-repo runbook)  
3. **Worksheet facts** as `{placeholders}` — for secrets: “set `ADMIN_PASSWORD` in your shell; do not paste the value here”  
4. **Ask-before** list (subset of §4 relevant to that job)  
5. **Done when** (observable check: `/up` 200, preflight green, …)  
6. **Constraint line:** follow that doc/scripts only; no parallel installer  
7. **Pace:** prefer phased prompts (“do Step N only; stop and report the check”) over one-shot “install everything”  

Long installs SHOULD be split into **multiple kickoffs** (or explicit “stop after step N”) so humans naturally check between phases.

Prompts live in MkDocs so they stay versioned with the installers.

## 6. Cons → mitigations (locked)

Honest risks. Mitigations are **process/docs**, not code theater.

| Con | Mitigation |
|-----|------------|
| **Wrong promise** (“AI will just install it”) | **A7.** Getting-started opens with co-pilot + gates. README: classical docs link **before** AI blurb. Ban unattended / “no CLI” language in OSS face. |
| **Agent quality not controlled** | **A1 + A6 + A10 + A11.** Scripts only; **small steps + check after each**. Issues: canonical-page repro; off-script agent = user/environment. No “prompt support” desk. |
| **Audience split** (telco conservatives / compliance) | AI is **optional parallel**, not mandatory culture. Enterprise one-pagers and compliance talk tracks lead with architecture/rules, **not** AI. Don’t sneer at classical operators in copy. |
| **Harder triage** | Issue template (P1): MkDocs path + step + host role; optional “used an agent? which doc kickoff?”. Maintainers may ask for classical repro. |
| **Doc drift amplified** | Rule: change to installer script or procedure page **updates matching kickoff in the same PR** (rollout W1). Broken kickoff = docs bug, treat as such. |
| **Secrets in LLM chat** | **A8.** Worksheet/kickoff wording; getting-started warning callout. Still cannot control vendor retention — say so plainly. |
| **Looks like unfinished installer** | **A5.** Classical path stays complete and tested. AI is overlay. Don’t use AI copy to excuse missing Lab/solo polish. |
| **Exclusion / cost of agents** | Never require a paid agent. Nav: classical Install and AI-assisted are **siblings**. Soften “preferred” → “if you use an agent IDE.” |
| **Telephony blast radius** | **A9** + loud gates on Peer/dialplan/PSTN spend. Lab vs production in fleet kickoffs. Fail-closed before signaling steps; stepwise check before the next one. |

**What we accept (cannot fully mitigate):** agents will ignore instructions; users will paste secrets; buyers will dismiss the posture; **stepwise checks bound but do not eliminate SoTA agent error**. Document honesty > fake guarantees.

## 7. Out of scope (v1)

- Hosted “PBX3 GPT” or mandatory cloud LLM  
- Agent controlling the live SIP path or dialplan without human-reviewed GenAst  
- Replacing Gatekeeper / fleet jobs with chat  
- Guaranteeing a specific vendor’s agent quality  
- Using AI posture as a substitute for install UX debt  

## 8. Related

- MkDocs: `getting-started/ai-assisted.md` · `installation/ai-assisted-install.md` · `fleet/agent-assisted.md`  
- Design Rules 1, 6, 8 (call path; solo; catalog → SPA)  
- OSS org move: promote carefully on `github.com/pbx3` README when org exists (classical first)  
- Parked orchestrated onboard: S10.7 / S8.9 — agent-assisted remains interim for fleet rebuild  
- Rollout: `~/GiT/pbx3-ops/devdocs/oss-move/AI_ASSISTED_POSTURE_ROLLOUT.md`
