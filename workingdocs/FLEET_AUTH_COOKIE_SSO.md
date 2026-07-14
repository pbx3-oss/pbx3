# Fleet auth — cookies & SSO (settled deferral 2026-07-14)

**Context:** Paste trim + Exit Fleet revoke shipped (`fleetauthpolish` → `main`). Remaining polish item was **cookie sessions** and **SSO step-up**.

## Verdict

**Not the same workstep as paste/exit polish.** Both remain **deferred** until hosting / IdP decisions land. Bearer in `sessionStorage` + gatekeeper login stays the production-shaped path for now.

## Why cookies are blocked today

| Fact | Implication |
|------|-------------|
| Fleet SPA is (or will be) on a **different origin** than `control.pbx3.com` (Pages / node SPA host) | Cookie set by gatekeeper is **cross-site** for browser fetches |
| Gatekeeper CORS is `Access-Control-Allow-Origin: *` | Browsers **reject** `credentials: 'include'` with `*`; cookie auth cannot work without a concrete allowlist + `Allow-Credentials: true` |
| Vite DEV uses `/fleet-gk` **same-origin proxy** | Cookies *could* work in DEV only — misleading if production stays cross-origin |

**Paths that unlock HttpOnly cookies (pick one later):**

1. **Serve Fleet UI from the control host** (e.g. `https://control.pbx3.com/fleet/` or `fleet.pbx3.com` same-site as API) — preferred for cookie sessions.  
2. Keep SPA on Pages but use a **BFF / same-site reverse proxy** in front of both.  
3. Stay on **Bearer** (current) and harden XSS surface separately.

Until (1) or (2), **do not implement Set-Cookie login** — it would either be DEV-only theatre or a broken prod path.

## Why SSO is deferred

Design §2.5 still leaves **identity model** open: shared central IdP (SSO, ACL-scoped) vs separate fleet credentials. Lab user `fleet@pbx3.com` is good enough for soak. SSO needs:

- Chosen IdP (e.g. Google Workspace / Microsoft Entra / Auth0)  
- How `fleet` / `fleet_*` abilities map from groups  
- Whether Enter Fleet is step-up re-auth or ambient SSO

**Soft step-up already shipped** without SSO: Exit Fleet revokes the gatekeeper session; next Enter Fleet requires Sign in again.

## What remains when unblocked

1. Gatekeeper: issue `HttpOnly; Secure; SameSite=Lax` (or `None` only if truly cross-site with allowlist) session cookie on login; accept cookie **or** Bearer; CSRF strategy for cookie mode.  
2. SPA: `credentials: 'include'` only when same-site; stop storing Bearer when cookie mode is on.  
3. CORS: replace `*` with allowlist when credentials are used.  
4. SSO: OIDC/SAML against chosen IdP; map groups → abilities; optional step-up on Enter Fleet.

## Related

- **`TEST_CADENCE.md` / Pack A** — auth unit tests stay valid for Bearer + break-glass.  
- **`CONTROL_HOST.md`** — login UI is live; update ops notes if this doc changes deployment of SPA onto control.
