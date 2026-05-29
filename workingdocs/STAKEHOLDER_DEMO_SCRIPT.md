# Stakeholder demo script (Track B)

**Purpose:** Repeatable walkthrough for stakeholder reviews. Every step on **Tier 1–2** panels must show a **`?` help icon** with useful text before demo (Phase 4 gate).

**Branch:** `hardening` · **Workplan:** `TRACK_B_RELEASE_HARDENING.md`

---

## Prerequisites (operator, before the meeting)

| Item | Value |
|------|--------|
| SPA | `cd pbx3spa && npm run dev` → **http://localhost:5173** |
| API proxy | `.env.development` → `VITE_API_PROXY_TARGET` (see **Dev baseline** in `TRACK_B_RELEASE_HARDENING.md`) |
| Fleet catalog | `VITE_CATALOG_PROXY_TARGET` + `VITE_INSTANCE_DIRECTORY_URL=/dev-catalog/...` (or omit for solo demo) |
| Login | Admin user on the target node |
| Node | Default demo: **08jzwn** (golden); switch proxy to **bzy54n** to show second fleet instance |
| Commit | After config changes, use top-bar **Commit** (red → green) |

**Do not** demo against HTTP API unless Phase 1 TLS is still pending — prefer HTTPS proxy target.

---

## Demo path (~25–35 min)

Check **Help OK?** during rehearsal: every labelled field on the screen should have **`?`** with non-empty text.

### 1. Login and fleet context (~3 min)

| # | Action | Route / UI | Show stakeholder | Help OK? |
|---|--------|------------|----------------|----------|
| 1.1 | Open SPA | `/login` | Central admin — one app, many PBX instances | ☐ |
| 1.2 | Refresh catalog (if fleet) | Login → **Refresh catalog** | Instance list from S3 (`08jzwn`, `bzy54n`) | ☐ |
| 1.3 | Select instance + sign in | Pick row → email/password | No per-node URL typing in production | ☐ |
| 1.4 | Confirm session chips | Top bar after login | Connected instance label + FQDN | ☐ |

### 2. Dashboard (~2 min)

| # | Action | Route | Show stakeholder | Help OK? |
|---|--------|-------|----------------|----------|
| 2.1 | Land on home | `/` | Overview; **Commit** status in top bar | ☐ |
| 2.2 | Point out Commit | Top bar | Save vs Commit — generator runs on Commit | ☐ |

### 3. Extensions (~5 min) — Tier 1

| # | Action | Route | Show stakeholder | Help OK? |
|---|--------|-------|----------------|----------|
| 3.1 | List extensions | `/extensions` | Sort/filter; tenant column | ☐ |
| 3.2 | Open one extension | `/extensions/:shortuid` | Identity, SIP settings, live status if available | ☐ |
| 3.3 | Create extension (or cancel) | `/extensions/new` | Guided create form; **Save** then **Commit** | ☐ |

### 4. Tenants (~4 min) — Tier 1

| # | Action | Route | Show stakeholder | Help OK? |
|---|--------|-------|----------------|----------|
| 4.1 | List tenants | `/tenants` | Multi-tenant on one instance | ☐ |
| 4.2 | Open tenant detail | `/tenants/:pkey` | Tenant FQDN, recording, advanced settings | ☐ |
| 4.3 | Optional: create tenant | `/tenants/new` | FQDN assigned on create | ☐ |

### 5. Queues (~3 min) — Tier 1

| # | Action | Route | Show stakeholder | Help OK? |
|---|--------|-------|----------------|----------|
| 5.1 | List queues | `/queues` | Key columns visible | ☐ |
| 5.2 | Open one queue | `/queues/:shortuid` | Strategy, members, settings | ☐ |

### 6. Routes and inbound (~4 min) — Tier 1

| # | Action | Route | Show stakeholder | Help OK? |
|---|--------|-------|----------------|----------|
| 6.1 | Outbound routes | `/routes` | Dialplan routing | ☐ |
| 6.2 | One route detail | `/routes/:shortuid` | Path / COS linkage | ☐ |
| 6.3 | Inbound routes | `/inbound-routes` | DDI → destination | ☐ |

### 7. Backup and restore (~5 min) — Tier 2

| # | Action | Route | Show stakeholder | Help OK? |
|---|--------|-------|----------------|----------|
| 7.1 | Open backup panel | `/backup` | Local + S3 archives; UTC time + archive ID | ☐ |
| 7.2 | Create backup | **Create** button | On-demand backup; async S3 upload | ☐ |
| 7.3 | Explain S3-only row | Backups table | DR copy when local zip pruned | ☐ |
| 7.4 | Optional: restore demo | Restore from archive | Only if safe on demo node — **rehearse first** | ☐ |

### 8. Certificates (~3 min) — Tier 2

| # | Action | Route | Show stakeholder | Help OK? |
|---|--------|-------|----------------|----------|
| 8.1 | Open certificates | `/certificates` | LE multi-SAN: node + tenant FQDNs | ☐ |
| 8.2 | Show cert covers | **Cert covers** list | All hostnames on one cert | ☐ |
| 8.3 | Sync with tenant list | **Sync** button | Add tenant → Sync expands SAN | ☐ |

### 9. Instance settings (~3 min) — Tier 2

| # | Action | Route | Show stakeholder | Help OK? |
|---|--------|-------|----------------|----------|
| 9.1 | Instance globals | `/sysglobals` | Domain, FQDN inspect, identity | ☐ |
| 9.2 | Network | `/ip-settings` | LAN/WAN detection | ☐ |
| 9.3 | Firewall | `/firewall` | Shorewall rules (read-only overview) | ☐ |

### 10. Fleet switch (optional, ~2 min)

| # | Action | Show stakeholder |
|---|--------|------------------|
| 10.1 | Log out; change `VITE_API_PROXY_TARGET` to second node; restart dev | Same SPA, different instance |
| 10.2 | Log in via catalog → **bzy54n** | Fleet catalog + per-node API |

---

## Solo demo variant (no fleet catalog)

1. Unset `VITE_INSTANCE_DIRECTORY_URL` in `.env.development`; restart dev.
2. Login with email/password + API URL only (`VITE_DEFAULT_API_BASE_URL` optional).
3. Run steps **2–9** only (skip 1.2, 1.3 fleet picker, 10).

---

## Out of scope for v1 stakeholder demo

- GitHub Pages / public SPA URL (S6.2 — deferred)
- Recordings S3 offload (S7 — parked)
- Extension provisioning / MAC (planned — separate track)
- User admin, logs, help-messages editor (Tier 4)

---

## Rehearsal sign-off (Phase 5)

| Check | Date | Initials |
|-------|------|----------|
| Full script run without operator explaining fields (help text sufficient) | | |
| HTTPS API + Vite proxy; no cert warnings | | |
| Tier 1–2: all **Help OK?** boxes checked | | |
| Backup restore (if shown) rehearsed on non-production or rollback plan | | |

---

## Quick reference — demo routes

```text
/login
/
/extensions          /extensions/new          /extensions/:id
/tenants             /tenants/new             /tenants/:pkey
/queues              /queues/:id
/routes              /routes/:id
/inbound-routes
/backup
/certificates
/sysglobals
/ip-settings
/firewall
```
