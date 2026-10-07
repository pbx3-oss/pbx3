# Instance API security — industry review backlog

**Status:** Review item (not locked; not scheduled). Captured **2026-10-04**.  
**Scope:** Home **pbx3api** on **`:44300`** (SPA / Sanctum admin API). Not provision `:41363`, not SBC Filament, not Gatekeeper (except cross-links).  
**Related:** `pbx3api/docs/auth.md` · `TOTP_2FA_REQUIREMENTS.md` · `UFW_SHOREWALL_MIGRATION.md` · SBC **`SBC_MANAGEMENT_ACCESS_REQUIREMENTS.md`** (stricter IP model for edge admin) · TODO **#38**.

---

## Current posture (baseline)

What protects someone from poking the instance API directly today:

| Layer | What we have |
|-------|----------------|
| Transport | HTTPS on `:44300` (LE on fleet) |
| AuthN | Laravel Sanctum Bearer; unauthenticated surface ≈ `POST /auth/login` + `POST /auth/2fa/verify` |
| AuthZ | Abilities (`admin`, `tenant`, `recordings`, …) on routes |
| Tenant scope | `EnforcesClusterScope` / `allowed_clusters` for non-admin users |
| MFA | Opt-in TOTP (instance Sanctum) |
| Control plane split | Fleet mobility uses `PBX3_FLEET_SERVICE_TOKEN`, not SPA Sanctum |
| Host | UFW/SG; fail2ban `pbx3-api-badbots` (scanner UAs) |
| Unknown routes | Opaque JSON fallback `Unauthorised/Page Not Found` |

**Assessment (2026-10-04):** Credible **mid-tier** self-hosted admin API — aligned with common good practice for SPA → per-home API. Not bank-grade zero-trust. Deliberately keeps `:44300` reachable so **`app.pbx3.com`** can call homes with a token (unlike optional SBC Filament IP lockdown on `:443`).

---

## Gaps vs industry best practice (candidate work)

These make sense as a future hardening pass. **Do not implement without product lock** (esp. anything that breaks shared Pages SPA → home reachability).

### H1 — Login / 2FA abuse controls (high value)

- Rate-limit / progressive delay / lockout on **`/auth/login`** and **`/auth/2fa/verify`**.
- Fail2ban (or equivalent) on repeated auth failures — not only bad-bot UAs.
- Industry: expected on any internet-facing login.

### H2 — Token lifetime / rotation (high value)

- Sanctum PATs are often long-lived today.
- Prefer idle expiry, absolute max age, and/or refresh-style rotation; revoke on password / ability / scope change (partially already on ability/scope update).
- Industry: short-lived access tokens common for browser clients.

### H3 — MFA policy for admins (medium — policy)

- Today: opt-in TOTP.
- Candidate: **require** 2FA for `admin` (or all instance users) in fleet / production posture.
- Related parked stance: Fleet Gatekeeper G5 “admins must enroll” — same class of decision.

### H4 — Optional admin API IP allowlist (medium — product tradeoff)

- High-security orgs restrict management APIs to VPN/office.
- Candidate: optional UFW/nginx allowlist on `:44300` (sibling spirit to SBC Management access / Provision access).
- **Conflict risk:** default-off required if shared SPA on Pages must keep working from arbitrary operator IPs. Document “strict sites only.”

### H5 — Browser token architecture (lower urgency / larger design)

- SPA holds Bearer in the client (normal for this architecture).
- Gold standard: BFF or same-site cookie + CSRF.
- Revisit only if threat model or enterprise SSO (#16) forces it — do not casually rewrite SPA auth.

### H6 — Edge WAF / bot score (ops / optional)

- CDN/WAF in front of admin APIs is common at scale.
- We rely on host UFW + nginx + fail2ban. Acceptable for current fleet size; optional later.

---

## Out of scope here

- Provision edge (`:41363`) — MAC / mTLS / SBC-only UFW / C10 allowlist (separate specs).
- SBC Filament lockdown — already has optional IP allowlist model.
- SIP / OpenSIPS door-knock — call path, not Sanctum.

---

## Suggested review outcome (when scheduled)

1. Pick **H1 + H2** as first implementable slice (login throttle + token TTL) without breaking Pages SPA.  
2. Decide **H3 / H4** as product policy (defaults off vs fleet-required).  
3. Leave **H5 / H6** parked unless an enterprise ask lands.

Update this file when decisions lock; promote chosen items into requirements docs or mark won't-do with date.
