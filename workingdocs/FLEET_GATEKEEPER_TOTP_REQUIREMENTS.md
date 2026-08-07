# Fleet Gatekeeper TOTP (requirements)

**Status:** Plan locked (requirements draft). **Not implemented.**  
**Plane:** Control plane only — Gatekeeper SQLite users + SPA Fleet mode. Design Rule **10**.  
**Sibling tracks:** Instance Sanctum + SBC Filament — **`TOTP_2FA_REQUIREMENTS.md`**. Do not share secrets across planes.  
**Related:** **`FLEET_AUTH_COOKIE_SSO.md`** (Bearer try-it-out; cookies/SSO still deferred) · **`pbx3spa`**/workingdocs/**`AUTH_PATTERNS.md`** (instance patterns; Fleet mirrors gesture only).

---

## Outcome (short)

| Topic | Outcome |
|-------|---------|
| **Factor** | **TOTP only** (authenticator app) + one-time **recovery codes**. No SMS / email OTP. |
| **Policy v1** | **Opt-in per Gatekeeper user**. Optional later: require for `fleet_admin` (G5). |
| **Secrets** | Gatekeeper `auth.sqlite` only — never instance Sanctum or SBC Filament. |
| **Issuer** | **`Aelintra Fleet`** (env override OK). Distinct from **`Aelintra PBX`** / **`Aelintra SBC`**. |
| **Login contract** | Password OK + 2FA on → `requires_2fa` + short-lived `challenge_id`; **no** session Bearer until verify. |
| **Break-glass** | `GATEKEEPER_API_TOKEN` **unchanged** — not subject to TOTP (ops emergency / paste path). |
| **Create user** | `bin/create-fleet-user.php` and `POST /api/v1/fleet-users` stay password-only; enroll after login. |
| **Cookies / SSO** | Still deferred. TOTP works on today’s Bearer + `sessionStorage` path. |

---

## Why

Fleet console can move tenants, provision instances, and hold break-glass ops. Password-only Gatekeeper login is weak for an internet-facing control host. Instance and SBC already have opt-in TOTP; Fleet needs the same gesture on its **own** identity store (Rule 10).

---

## Non-goals

- One QR / one secret covering Fleet + instance + SBC.
- Applying TOTP to break-glass token paste.
- Cookie sessions or OIDC MFA (IdP’s problem when SSO exists; local TOTP remains for non-SSO users).
- Mandating 2FA for all fleet users in v1.
- Sharing challenge tokens or recovery codes with `pbx3api`.
- Reviving any instance `globals.userotp` ideas on Gatekeeper.

---

## Product UX

**Enroll (while Fleet-authenticated):**

1. Confirm password (step-up).
2. Show QR + manual secret; user adds account in their app.
3. Confirm with a live TOTP code.
4. Show recovery codes once (user must save); mark 2FA enabled.

**Login (when 2FA enabled):**

1. Email + password on Fleet sign-in (`FleetTokenGate`).
2. If OK and 2FA on → challenge screen (no session Bearer yet).
3. Enter TOTP **or** a recovery code → then issue Gatekeeper session token (same shape as today’s successful login).
4. If 2FA off → today’s single-step login.

**Disable:** Authenticated user + password (+ current TOTP if still enrolled); clears secret and unused recovery codes.

**Admin clear:** Fleet operator with user-manage ability clears another user’s 2FA (lockout recovery) without learning their secret; revoke that user’s sessions.

**Help copy:** “Use any authenticator app (e.g. 2FAS, Authy, Google Authenticator).” Do not hard-require one brand.

---

## A — Gatekeeper

**Repos:** `pbx3/pbx3-directory/gatekeeper` (`UserStore`, `public/index.php`).  
**SPA consumer:** `pbx3spa` Fleet mode only.

### A1 — Data

On Gatekeeper `users` (SQLite migrate in `UserStore`):

- `two_factor_secret` — encrypted/opaque at rest if practical (same bar as instance).
- `two_factor_confirmed_at` — null until confirm succeeds.
- Hashed recovery codes column (JSON or text blob of hashes).
- Short-lived **challenge** store (dedicated table or equivalent): opaque `challenge_id` → `user_id` + expiry; single-use on verify; no session token until verify.

Do **not** put TOTP fields on instance `users` or portable tenant export.

### A2 — API shape (illustrative)

Paths stay under `/api/v1/auth/…` to match today’s Gatekeeper auth surface.

| Step | Behaviour |
|------|-----------|
| `POST /api/v1/auth/login` | Password fail → 401. Password OK + no 2FA → today’s `{ token, … abilities }` (existing response shape). Password OK + 2FA confirmed → **no** token; return `requires_2fa: true` + `challenge_id`. |
| `POST /api/v1/auth/2fa/verify` | `challenge_id` + TOTP or recovery code → create session token; same response shape as successful password-only login. Bad/expired challenge → 401/422. |
| Enroll / confirm / disable / recovery regenerate | Authenticated Bearer routes; password step-up where appropriate. |
| Admin clear | e.g. `DELETE` or `POST …/fleet-users/{id}/clear-2fa` — ability-gated like other fleet-user admin actions; clears secret + recovery; revokes sessions for that user. |
| `GET /api/v1/auth/me` | Include `two_factor_enabled` (boolean). List/detail fleet-users may expose the same flag for admin UI (never the secret). |

Break-glass: existing `GATEKEEPER_API_TOKEN` / Auth break-glass path **unchanged** — no challenge step.

### A3 — Issuer

Default **`Aelintra Fleet`**. Account label = user email. Env override (e.g. `GATEKEEPER_TOTP_ISSUER`) OK for lab/custom branding.

### A4 — Tests

PHPUnit under `gatekeeper/tests/`:

- Login without 2FA unchanged.
- Login with 2FA: password alone does not yield usable session token; verify succeeds; bad code fails; recovery code single-use.
- Enroll confirm + disable + admin clear.
- Break-glass still authenticates without TOTP.

**Effort (ballpark):** ~2–4 days Gatekeeper + SPA opt-in v1 together.

---

## B — SPA (Fleet mode)

**Repos:** `pbx3spa` — `FleetTokenGate.vue`, `api/fleetGatekeeper.js`, `FleetUsersView.vue` (+ small self-enroll surface).

### B1 — Login challenge

- Extend `loginFleet` to handle `requires_2fa` + `challenge_id` (mirror instance `parseLoginResponse` / LoginView **gesture**, not shared auth store or secrets).
- Challenge UI in `FleetTokenGate` (or sibling step): TOTP / recovery code → `POST …/2fa/verify` → store Bearer as today.
- Do not issue or keep a partial token in `sessionStorage` during challenge.

### B2 — Enroll / manage

- Self-service enroll/disable in Fleet mode (Account Security analogue or dedicated Fleet panel section reachable when signed in).
- After confirm, show recovery codes once.
- Discoverability: short strip or nav affordance in Fleet layout (kinship with instance Home **Enable 2FA** / topbar **2FA** — wording “Fleet 2FA” OK).

### B3 — Admin clear

- On **Fleet Users** detail/row actions: **Clear 2FA** when `two_factor_enabled`, ability-gated; confirm dialog; no secret shown.

### B4 — Break-glass paste

- Advanced paste of `GATEKEEPER_API_TOKEN` stays as today — no TOTP challenge on that path.

---

## C — Sequencing

| Order | Work | Notes |
|------|------|--------|
| **G0** | This doc accepted | Done when scheduled |
| **G1** | Gatekeeper schema + login challenge + verify | No session token until verify |
| **G2** | Enroll / disable / recovery / admin clear | Authenticated + ability-gated clear |
| **G3** | SPA FleetTokenGate challenge + enroll UI + Fleet Users clear | Ship with G1–G2 |
| **G4** | Tests + Gatekeeper README / ops note | Pack A auth tests extended |
| **G5** | Optional: require 2FA for `fleet_admin` | After opt-in proven |

Not on **`FIRST_OUT_CHECKLIST.md`** must-fix list. Schedule after instance `spa-totp-2fa` merge/lab confidence if desired; not blocked on cookies/SSO.

---

## D — Explicit deferrals

| Item | Status |
|------|--------|
| Cookie sessions for Fleet | Unrelated (`FLEET_AUTH_COOKIE_SSO.md`) |
| SSO / OIDC MFA | IdP when SSO exists; keep local TOTP for non-SSO |
| Passkeys / WebAuthn | Nice later; not v1 |
| SMS | Out |
| Force 2FA for all fleet abilities | G5 optional for `fleet_admin` only |

---

## E — Acceptance (v1)

**Gatekeeper**

- [ ] User can enroll TOTP with any authenticator; issuer **`Aelintra Fleet`** (distinct from PBX / SBC).
- [ ] With 2FA on, password-only login does not grant a Fleet session Bearer.
- [ ] TOTP and one recovery code complete login; recovery codes are single-use.
- [ ] User can disable; admin can clear 2FA for a locked-out fleet user (sessions revoked).
- [ ] Users without 2FA unchanged.
- [ ] Break-glass token path unaffected by TOTP.

**SPA**

- [ ] `FleetTokenGate` challenges when `requires_2fa`; stores token only after verify.
- [ ] Fleet-mode enroll/disable + recovery codes once after confirm.
- [ ] Fleet Users **Clear 2FA** for lockout recovery.

---

## Tip / TODO

- Implement when scheduled (G0 accepted → G1–G4).
- Pointer from instance/SBC doc: **`TOTP_2FA_REQUIREMENTS.md`** §D.
- TODO item: **TOTP 2FA — Fleet Gatekeeper** (parked until scheduled).
- Operator docs: Gatekeeper README + fleet auth page when packaging.
