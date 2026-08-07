# TOTP 2FA — instance SPA + SBC admin (requirements)

**Status:** Plan locked. **SBC Filament slice done** (`pbx3sbc-admin`). **Instance Sanctum + SPA** merged to **`main`** (C2–C5).  
**Planes:** (1) Instance Sanctum — `pbx3api` + `pbx3spa`. (2) SBC Filament — `pbx3sbc-admin`.  
**Out of scope (this track):** Fleet Gatekeeper 2FA (separate track — **`FLEET_GATEKEEPER_TOTP_REQUIREMENTS.md`**); SSO / IdP; SMS / email OTP; WebAuthn/passkeys (optional later).  
**Related:** **`pbx3spa/workingdocs/AUTH_PATTERNS.md`** §2 · **`FLEET_AUTH_COOKIE_SSO.md`** (separate plane) · **`FLEET_GATEKEEPER_TOTP_REQUIREMENTS.md`** · Design Rule **10** (do not merge fleet ↔ instance tokens).

---

## Outcome (short)

| Topic | Outcome |
|-------|---------|
| **Factor** | **TOTP only** (authenticator app). User picks any compliant app (2FAS, Authy, Google Authenticator, …). |
| **SMS / voice callback** | **No** for v1 (and no preference to add later). |
| **Surfaces** | **Two separate enrollments** — SPA/instance and SBC. Same gesture in the app; different product screens OK. |
| **Shared secret across surfaces** | **No** — separate users/DBs; two rows in the authenticator if the operator uses both. |
| **Issuer labels** | Distinct per surface (e.g. product + “PBX” vs “SBC”, and/or host) so same email does not collide in the app list. |
| **Policy v1** | **Opt-in per user**. Optional later: require 2FA for `admin` (instance) / Filament admins (SBC). |
| **Recovery** | One-time **recovery codes** at enroll; admin reset path if locked out. |
| **Contract** | Sanctum **Bearer only after** password + TOTP (or recovery). Whoami unchanged. |

---

## Why

Password-only admin login is weak for internet-facing instance API and SBC panel. TOTP matches familiar AWS Virtual MFA UX without carrier dependency or SIM-swap risk. SPA auth patterns already assume multi-step login; Filament has mature TOTP plugins.

---

## Non-goals

- One QR / one secret covering both SPA and SBC.
- Mandating a specific authenticator vendor.
- Replacing Sanctum abilities or Filament roles with IdP groups.
- Gatekeeper / Fleet console MFA — see **`FLEET_GATEKEEPER_TOTP_REQUIREMENTS.md`**.
- Reviving deprecated `globals.userotp` (unrelated; leave dead).

---

## Product UX (both surfaces)

**Enroll (while authenticated):**

1. Confirm password (step-up).
2. Show QR + manual secret; user adds account in their app.
3. Confirm with a live TOTP code.
4. Show recovery codes once (user must save); mark 2FA enabled.

**Login (when 2FA enabled):**

1. Email + password.
2. If OK and 2FA on → challenge screen (no full session/token yet).
3. Enter TOTP **or** a recovery code → then issue Sanctum token / Filament session.
4. If 2FA off → today’s single-step login.

**Disable:** Authenticated user + password (+ current TOTP if still enrolled); clears secret and unused recovery codes.

**Help copy:** “Use any authenticator app (e.g. 2FAS, Authy, Google Authenticator).” Do not hard-require one brand.

---

## A — Instance (Sanctum + SPA)

**Repos:** `pbx3api`, `pbx3spa`. Ship API + SPA together.

### A1 — Data

- Per-user TOTP secret (encrypted at rest if practical), `two_factor_confirmed_at` (or equivalent), hashed recovery codes.
- Migration on instance users table (Laravel `users` — not tenant mini-DB). Portable tenant users (`tenant` / `recordings`): 2FA secret **travels with the user** on P4 portable export/import (same as password hash). Document in mobility notes when implementing.

### A2 — API shape (illustrative)

| Step | Behaviour |
|------|-----------|
| `POST /auth/login` | Password fail → 401. Password OK + no 2FA → `accessToken` (today). Password OK + 2FA → **no** full token; return e.g. `requires_2fa: true` + short-lived `challenge_id` (or opaque challenge token with ability limited to verify-only). |
| `POST /auth/2fa/verify` | Challenge + TOTP or recovery code → `createToken` + same response shape as today’s successful login. |
| Enroll / confirm / disable / recovery regenerate | Authenticated routes; password step-up where appropriate. Admin may **clear** another user’s 2FA (lockout recovery) without learning their secret. |

Do **not** put user/abilities authority in the login body — whoami remains source of truth after token exists (`AUTH_PATTERNS.md`).

### A3 — SPA

- Keep login logic in one place (`LoginView` / small auth helper).
- Challenge step after password when `requires_2fa`.
- Profile (or Users self-service) enroll/disable UI; admin clear-2FA on user detail.
- Public routes allow-list: add challenge path if it is a distinct route.

### A4 — Issuer string

Example: `Aelintra PBX` or `{sitename} PBX` + account = user email. Prefer stable product issuer + email so multi-instance operators can tell rows apart via account label / host if we include FQDN in the otpauth label.

### A5 — Tests

- Login without 2FA unchanged.
- Login with 2FA: password alone does not yield usable panel token; verify succeeds; bad code fails; recovery code single-use.
- Enroll confirm + disable.

**Effort (ballpark):** ~3–5 days for opt-in v1; +~1 day for “require 2FA for admin” policy.

---

## B — SBC (Filament)

**Repos:** `pbx3sbc-admin` (session auth, not Sanctum).  
**Implementer map:** **`pbx3sbc-admin/workingdocs/TOTP_2FA_SBC.md`**.

### B1 — Approach (shipped)

- Package: **`jeffgreco13/filament-breezy` ^2.6** (Filament **3** line). Do not use Breezy 3.x until Filament 4.
- Opt-in TOTP + recovery codes via `BreezyCore::make()->myProfile(…)->enableTwoFactorAuthentication(force: false)`.
- No Sanctum token UI; no passkeys.
- Custom SPA-kinship topbar **hides** Filament avatar menu → **Profile** link in `topbar-user.blade.php` is required for enroll discoverability.
- Issuer: `config('panel.totp_issuer')` default **`Aelintra SBC`** (`PBX3_TOTP_ISSUER`); overridden on `User::getTwoFactorQrCodeUrl()`.

### B2 — Behaviour

- Same product rules: TOTP only, opt-in v1, recovery codes, distinct issuer.
- Fleet Bearer API (`/api/fleet/*`) stays **token/break-glass** — not Filament session 2FA. Do not conflate.
- `install.sh` create-admin stays password-only; 2FA is post-login enroll.

### B3 — Lab

Enroll on scratch/lab SBC → logout → password + authenticator code → Home. Confirm recovery path once. See **`TOTP_2FA_SBC.md`**.

**Effort (ballpark):** ~0.5–1.5 days if plugin fits; more if package fight.

---

## C — Sequencing

| Order | Work | Notes |
|------|------|--------|
| **C0** | This doc accepted | Done when scheduled |
| **C1** | **SBC first** | **Done** (Breezy + Profile link + issuer) — see `pbx3sbc-admin/workingdocs/TOTP_2FA_SBC.md` |
| **C2** | **Instance API challenge + schema** | **Done** on `spa-totp-2fa` — no SPA token until verify |
| **C3** | **SPA challenge + enroll UI** | **Done** with C2 — LoginView + Account Security |
| **C4** | Recovery + admin clear | **Done** |
| **C5** | Docs / help | API auth.md + AUTH_PATTERNS; MkDocs when packaged |
| **C6** | Optional policy “require for admin” | After opt-in proven |

Combined opt-in both surfaces: ~**1–1.5 weeks** calendar with review/lab — not a shared codebase, shared UX vocabulary only.

---

## D — Explicit deferrals

| Item | Status |
|------|--------|
| Fleet Gatekeeper TOTP | Separate track — **`FLEET_GATEKEEPER_TOTP_REQUIREMENTS.md`** (G0–G5) |
| Cookie sessions for Fleet | Unrelated (`FLEET_AUTH_COOKIE_SSO.md`) |
| SSO / OIDC MFA | IdP’s problem when SSO exists; local TOTP remains for non-SSO users |
| Passkeys / WebAuthn | Nice later; not v1 |
| SMS | Out |

---

## E — Acceptance (v1)

**Instance**

- [x] User can enroll TOTP with any authenticator; issuer distinguishable from SBC.
- [x] With 2FA on, password-only login does not grant panel API access.
- [x] TOTP and one recovery code complete login; recovery codes are single-use.
- [x] User can disable; admin can clear 2FA for a locked-out user.
- [x] Users without 2FA unchanged.

**SBC**

- [x] Filament admin can enroll/disable TOTP; login challenges when enabled.
- [x] Fleet API token path unaffected.
- [x] Issuer label distinct from instance SPA.

---

## Tip / TODO

- Instance Sanctum + SPA: on **`main`** (was **`spa-totp-2fa`**).
- Fleet Gatekeeper TOTP: **`FLEET_GATEKEEPER_TOTP_REQUIREMENTS.md`** (requirements locked; not implemented).
- Not on **`FIRST_OUT_CHECKLIST.md`** must-fix list.
- Operator docs: update pbx3-docs auth pages when packaging.
