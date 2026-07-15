# Fleet auth — identity, cookies, SSO, abilities (settled 2026-07-14)

**Status:** Settled product stance for this stage of the project.  
**Also covers:** cookie topology deferral; when (not) to adopt a big IdP engine.

---

## Outcome (short)

| Topic | Outcome |
|-------|---------|
| **Try-it-out / lab auth** | **Done enough** — gatekeeper email/password, Bearer session, break-glass, soft step-up (Exit Fleet revokes). No big IdP required. |
| **HttpOnly cookies** | **Deferred** — needs same-site Fleet UI (or BFF); blocked by cross-origin SPA + CORS `*`. |
| **SSO / external IdP** | **Deferred** — optional later; **not** a barrier to try the product. |
| **SSO-agnostic design** | **Yes** — we own **abilities**; external IdPs only assert identity (+ groups). Wire OIDC (etc.) **as and when needed**. |
| **Fleet abilities (`fleet` / `fleet_*`)** | **Can be built with what we have** (SQLite users + route checks) without Keycloak/Authentik/etc. |

Do **not** pull a big identity engine until a customer/compliance requirement forces shared SSO. Do **not** implement Set-Cookie login until Fleet UI is same-site with the gatekeeper (or behind a same-site proxy).

---

## What we already shipped (auth path)

- Gatekeeper SQLite users + session tokens (`login` / `me` / `logout`).
- SPA Fleet Sign in (email/password) → Bearer in `sessionStorage`.
- Break-glass `GATEKEEPER_API_TOKEN` retained; paste UX collapsed (“ops only”).
- Exit Fleet / reset call `logoutFleet` — next Enter Fleet must Sign in again (**soft step-up** without SSO).
- Pack A tests: UserStore lifecycle + break-glass Auth.

**Implicit product rule:** local fleet login remains the default **demo / try-it-out** path forever. SSO is an add-on for orgs that already have a central IdP.

---

## Abilities — independent of IdP

Design §2.5: node `admin` / panel abilities → **pbx3api** only; `fleet` / `fleet_*` → **gatekeeper** only. Most customer admins get **zero** fleet.

Today gatekeeper enforces `fleet_*` abilities on routes (S10.1). SPA hides actions the session lacks; **server still decides**.

**Abilities without an IdP (shipped S10.1):**

1. Persist abilities on the gatekeeper user (SQLite `users.abilities` JSON).
2. Return them from `login` / `me`.
3. Enforce on gatekeeper routes; SPA only hides UI (server still decides).
4. Break-glass = `fleet_admin` (full ops set).

That mirrors Sanctum abilities on the node — just on control-plane users.

**When an IdP arrives later:** it supplies identity + optional groups/roles via standard protocols; **one mapper** turns claims → our ability names. The ability vocabulary stays ours.

---

## SSO-agnostic stance

**IdP** = Identity Provider — central authority for *who* someone is (and often group membership), e.g. Keycloak, Authentik, Google Workspace, Microsoft Entra. Almost all expose **APIs** and, more importantly for us, **OIDC/SAML**.

**Mindful split:**

1. **PBX3 owns abilities** and enforces them on gatekeeper APIs.  
2. **Whoever authenticates** must only hand us a stable subject (+ optional groups) via a **standard protocol**.

Then Keycloak vs Authentik vs Entra vs “SQLite login only” are **identity backends**, not product rewrites. We stay **SSO-agnostic**: optional OIDC connector(s) when needed — not “we are a Keycloak app.”

Open-source peers usually ship local users for trial and optional OIDC so the deployer brings their own IdP. We follow that shape.

**Big engines are a hell of a barrier for “let’s try it out.”** Correct: IdP/SSO stays tip-blocked; password login stays the open-box path.

---

## Cookies — why same-site Fleet UI

| Fact | Implication |
|------|-------------|
| SPA often on a **different origin** than `control.pbx3.com` | Gatekeeper `Set-Cookie` is cross-site for browser calls |
| Gatekeeper CORS is `Access-Control-Allow-Origin: *` | Cannot use `credentials: 'include'` with `*` |
| Vite `/fleet-gk` proxy is same-origin **in DEV only** | Cookie auth in DEV alone would mislead |

**Unlock paths (later):** serve Fleet UI from control (`/fleet/` or same-site subdomain); or a BFF/reverse proxy; or stay on Bearer and harden XSS separately.

Until unlocked: **Bearer + sessionStorage** remains correct.

---

## What to build when (priority)

| **When** | **Work** |
|------|------|
| **UX (open)** | Restyle Fleet sign-in (`FleetTokenGate`) for kinship with **`LoginView`** — see TODO “Fleet login UI kinship” |
| **Now / next need** | Optional: gatekeeper **abilities** (SQLite + enforce) if we have more than one fleet operator role |
| **Customer asks for SSO** | OIDC connector → map groups → abilities; keep local login |
| **Fleet UI hosted same-site** | Optional HttpOnly cookie sessions + CORS allowlist + CSRF |
| **Never as a lab gate** | Mandatory Keycloak/Authentik install just to click Fleet |

---

## Related

- §2.5 abilities / modes — **`pbx3-directory/docs/TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`**
- Control host ops — **`pbx3-directory/docs/CONTROL_HOST.md`**
- Pack A auth tests — **`CRITICAL_PATH_TEST_PACK.md`**, gatekeeper `tests/`
- Tip order — **`TODO.md`** item “Fleet auth cookie/SSO (blocked)”
