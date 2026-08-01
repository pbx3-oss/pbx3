# CDR timezone policy (research + lean)

**Status:** Lean locked **2026-07-31**. **SQLite HoR UTC shipped** in package + golden (`STRFTIME`…`UTC`); CSV already `usegmtime=yes`. SPA site-TZ **display** still TODO.  
**Trigger:** Instance Home **Outcomes (today)** empty while **Call volume (24h)** showed soak traffic (golden).  
**Related:** `pbx3api` `CdrIndexService::outcomeToday` / `volumeLast24h`; SPA `HomeCdrCharts`; Asterisk `cdr_sqlite3_custom` → `/var/log/asterisk/master.db`.

---

## 1. What we saw (lab)

| Piece | Clock |
|-------|--------|
| Host / Asterisk | `America/New_York` (EDT) |
| CDR `calldate` | **Local wall** strings (e.g. `2026-07-31 21:59:56`) — Asterisk default; no `usegmtime` on sqlite3 custom |
| Laravel `app.timezone` | **UTC** |
| `outcomeToday` | `(new DateTimeImmutable('today'))` → UTC midnight |
| `volumeLast24h` | Rolling 24h from `now` (still shows local-stamped rows inside the window) |

When UTC had already rolled to **1 Aug** (~02:00 UTC) but local was still **31 Jul evening**, `calldate >= 2026-08-01 00:00:00` matched **0** rows. Volume still counted them. Not a missing CDR bug — **mixed clocks**.

---

## 2. Industry lean (transnational)

| Layer | Usual practice |
|-------|----------------|
| **Storage** | **UTC** (epoch or UTC wall) — Cisco CUCM, 3CX CDR export, billing/mediation |
| **Presentation** | Convert at the edge using **site / tenant / operator** IANA TZ (“today”, invoices, office-hours reports) |
| **Asterisk default** | Host **local** unless `usegmtime` / `cdrzone=UTC` (backend-dependent) |

Rationale for UTC at rest: DST-safe, comparable across nodes/countries, one mediation clock. Local-only strings break when the API process TZ ≠ the writer’s TZ (exactly our Home bug).

---

## 3. UK operating note

In **UK winter**, civil time is **GMT ≡ UTC**, so local CDR and a UTC `today` boundary often **coincide** — the doughnut “works by accident.”

In **UK summer (BST = UTC+1)**, the same class of bug appears (±1h and around midnight). US / multi-region nodes (e.g. golden on Eastern) show it clearly year-round. Do not treat “UK = fine” as a design assumption.

---

## 4. Policy lean (locked 2026-07-31)

1. **Near-term Home fix (no CDR rewrite):** Day buckets (`outcomeToday`, any “today”/calendar CDR filter) must use the **same wall clock CDR was written in** — today that is **node local** (`timedatectl` / host TZ), **not** bare Laravel UTC `today`. Rolling windows (`volumeLast24h`) are less sensitive but hour **labels** should eventually match that same clock.
2. **Transnational end-state:** Prefer **UTC in CDR at rest** (Asterisk `usegmtime` / equivalent where supported) + **site TZ** for SPA “today” and operator-facing day reports (kinship: Network timezone / `sysglobals` — see SPA Network panel). Convert only at presentation.
3. **Until UTC CDR is fleet-default:** treat **written `calldate` strings as canon** for comparisons; never assume they are UTC just because Laravel is.

Do **not** flip golden CDR to UTC in a one-off lab patch without a fleet install/GenAst story and a note on existing local rows.

### Asterisk install / package watch

When installing or re-basing Asterisk (installer, image, `cdr_*.conf` ship):

| Backend | Packaged today | Watch |
|---------|----------------|--------|
| **CSV** (`cdr.conf` `[csv]`) | Already **`usegmtime=yes`** | Keep — archive/S3 path is GMT |
| **SQLite HoR** (`cdr_sqlite3_custom.conf`) | **`STRFTIME(${CDR(start,u)},UTC,…)`** (2026-07-31) | Was bare `${CDR(start)}` (host local). Lab golden reloaded; new rows match `date -u`. Pre-cutover rows stay local wall. |
| **Host TZ** | Node may stay local for office hours / logs | Do not rely on host TZ for new CDR strings |

Checklist item for any Asterisk install review: **“CDR HoR UTC?”** — verify a test call’s `master.db` `calldate` matches `date -u`, not only `date`. Then SPA/API day buckets use **site TZ** over UTC rows (display); Laravel UTC `today` now aligns with **new** HoR rows.

---

## 5. Implement later (checklist)

- [x] **Asterisk SQLite HoR UTC** — `cdr_sqlite3_custom.conf` `values` use `STRFTIME(${CDR(start,u)},UTC,%Y-%m-%d %H:%M:%S)`; golden live 2026-07-31
- [ ] SPA CDR list + Home doughnut: **display** convert via **site TZ** (storage is UTC; “business today” may still prefer site midnight over UTC midnight)
- [ ] Unit test / docs: mixed pre-cutover local rows vs post-cutover UTC in same `master.db`
- [x] Document in `INSTALL_SEQUENCE_UBUNTU.md` — CDR HoR UTC check after Asterisk bring-up
- [ ] SBC Home outcome “today” — confirm same clock story (OpenSIPS acc vs Filament)
- [ ] Existing lab `master.db` local rows — leave; no silent rewrite

---

## Changelog

| Date | Note |
|------|------|
| 2026-07-31 | Lab repro on golden; industry scan; lean locked (near-term match CDR/local; end-state UTC + site TZ). UK GMT≈UTC winter caveat. |
| 2026-07-31 | Install watch: CSV already `usegmtime=yes`; SQLite HoR still local via `${CDR(start)}` — fix at Asterisk install/package. |
| 2026-07-31 | **Shipped package + golden:** SQLite HoR UTC via STRFTIME; verified new `calldate` ≈ `date -u`. |
