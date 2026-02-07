# Debian package builder: improvement recommendations

**Path:** `pbx3-1/debian/`  
**Context:** Long-used package builder; reviewed 2025-02-05. These are recommendations only; no changes have been applied.

---

## 1. Debhelper compat (compat 7 → 13+)

**Current:** `debian/compat` contains `7`. Compat 7 is obsolete and triggers Lintian (e.g. `package-uses-old-debhelper-compat-version`).

**Recommendation:**

- Use **debhelper-compat 13** (or 14): add to `debian/control` under the Source stanza:
  ```text
  Build-Depends: debhelper-compat (= 13)
  ```
- Prefer specifying compat via Build-Depends rather than the `debian/compat` file. Remove or stop relying on `debian/compat` so the build uses a supported debhelper sequence.

**Reference:** [debhelper-compat-upgrade-checklist](https://manpages.debian.org/debhelper/debhelper-compat-upgrade-checklist.7.en.html)

---

## 2. prerm bug (line 21)

**Current:** In `debian/prerm`:

```bash
[ -L /etc/fail2ban/filter.d/asterisk.conf ] && /etc/fail2ban/filter.d/asterisk.conf
```

This runs the symlink target as a command instead of removing the symlink.

**Recommendation:**

- If we install that symlink, fix to:
  ```bash
  [ -L /etc/fail2ban/filter.d/asterisk.conf ] && rm -f /etc/fail2ban/filter.d/asterisk.conf
  ```
- If we do **not** install `/etc/fail2ban/filter.d/asterisk.conf`, remove this line from prerm.

---

## 3. postinst vs full installer

**Current:** `postinst` only writes the install date to `/opt/pbx3/.install-date`. The real setup (Asterisk, Apache, fail2ban, DB, ksuid, CDR MySQL, etc.) lives in `installer.sh`, which is **not** invoked from postinst.

**Recommendation:**

- Decide the intended flow:
  - **Option A:** “One-shot install” — `apt install pbx3` should perform full setup. Then have `postinst` call `/opt/pbx3/scripts/installer.sh` (with idempotency and error handling). Optionally use `debconf` for critical questions (e.g. DB root password) if desired.
  - **Option B:** Installer is run separately (e.g. by an admin or another process). Then document this clearly (e.g. in README or package description) so users know they must run the installer after install.
- Ensure `installer.sh` remains idempotent so reinstall or re-run does not break the system.

---

## 4. rules: debhelper usage and install list

**Current:** `debian/rules` manually invokes a subset of `dh_*` steps and does a full-tree copy with `find`/`cp`; it does not use `override_dh_auto_*` or a standard `dh` flow.

**Recommendation:**

- Prefer a minimal-override approach:
  - Use `override_dh_auto_build` only for any custom build steps (none currently, since ksuid comes from the `ksuid` package).
  - Let `dh` handle install by using an install file (e.g. `debian/pbx3.install`) that lists what to install, instead of “copy everything except debian.” That makes the package content explicit and reduces breakage when debhelper behaviour changes.

---

## 5. control

**Current:** Single binary package; long `Depends`; no `debhelper-compat` in Build-Depends.

**Recommendations:**

- Add `Build-Depends: debhelper-compat (= 13)` (see §1).
- Optionally group or comment `Depends` (e.g. by role: CDR, firewall, PHP, etc.) for maintainability.
- Extend the long description (e.g. “PBX3 provides …”) for `apt show` and the archive.

---

## 6. copyright

**Current:** Text still says “debianized by the alien program” and references conversion from a binary RPM.

**Recommendation:**

- Replace with a proper Debian copyright file:
  - Use [Format 1.0](https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/).
  - `Files: *` with correct license (e.g. GPL) and upstream (e.g. Aelintra / PBX3).
  - Remove alien/RPM wording.

---

## 7. changelog

**Current:** Single entry: `1.0.0-1 UNRELEASED`.

**Recommendation:**

- Bump version and add real entries for each release (e.g. “CDR MySQL at install, mariadb-server dep”, “Fail2ban Ubuntu 24.04”, “instance ksuid”, “use ksuid package”).
- Set the distribution (e.g. `unstable` or `noble`) when releasing so the package is uploadable and changes are traceable.

---

## 8. Maintainer scripts and purge

**Current:** `prerm` removes symlinks and disables services; no `postrm` for purge.

**Recommendation:**

- If postinst is ever updated to run the full installer, keep `installer.sh` idempotent.
- Optionally add a `postrm` to clean up `/opt/pbx3` (and any other package-owned state) on **purge**, if a full removal is desired.

---

## 9. Go build (no longer applicable)

**Current:** The package no longer builds Go; it Depends on the `ksuid` package. The `tools/ksuid` directory remains in the tree for optional local build.

**Note:** If a Go build were reintroduced (e.g. for another binary), consider `CGO_ENABLED=0` for a static binary and optionally `go mod vendor` for reproducible, offline builds.

---

## Summary table

| Area        | Current / issue                          | Recommended action                          |
|------------|-------------------------------------------|---------------------------------------------|
| Debhelper  | compat 7, no Build-Depends                 | compat 13+, add `debhelper-compat` in control |
| prerm      | Line 21 runs symlink instead of removing  | Use `rm -f` or remove line                  |
| postinst   | Only writes .install-date                 | Decide: call installer or document manual  |
| rules      | Manual copy + ad-hoc dh_*                 | Prefer install file + override only if needed |
| control    | No compat, long Depends                   | Add debhelper-compat; optional tidy        |
| copyright  | Alien/RPM boilerplate                     | Proper Format 1.0, GPL, upstream            |
| changelog  | Single old entry                          | Real versions and entries per release       |
| postrm     | None                                      | Optional: clean on purge                    |

---

*Document created from review of `pbx3-1/debian/`; apply changes as and when appropriate.*
