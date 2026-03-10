# idpwgen rollout plan

**Purpose:** Use the shared Go binary `idpwgen` for shortuid and password generation across pbx3 and pbx3api. This is a **new system** — not deployed anywhere yet — so backward compatibility and install-time toggles are not required. idpwgen will be used from the time the package is built.

---

## 1. Current generators (baseline)

- **Shortuids**
  - **HelperClass::generate()** — `pbx3/pbx3-1/opt/pbx3/php/classes/HelperClass`
  - **dumper.php** — `pbx3/pbx3-1/opt/pbx3/php/utilities/dumper.php` (calls `helper::generate()` when allocating a shortuid for any row with a `shortuid` column that doesn’t already have one)
  - Both will use idpwgen with **length 6** and the **default charset** (see below).

- **Phone passwords (12 chars)**
  - **Helper::ret_password()** — `pbx3api/app/Helpers/Helper.php`
  - Uses a **larger charset** (including uppercase) for passwords; override idpwgen’s charset when calling.

---

## 2. Go binary: idpwgen

- **Source:** `pbx3/pbx3-1/opt/pbx3/golang/idpwgen.go`
- **Installed path:** `/opt/pbx3/golang/idpwgen` (built at install time; see §6)
- **Interface:**
  - **Flags:**
    - `-length <int>` — length of generated ID (must be > 0)
    - `-charset <string>` — non-empty set of allowed characters
  - **Output:**
    - Success: prints the ID to **stdout** (one line); exit **0**
    - Error: message to **stderr**; exit **non-zero**
  - **Defaults (when no flags):**
    - **length = 6**
    - **charset = `0123456789bcdfghjkmnpqrstvwxyz`**

This is the **shortuid profile**. For passwords, call with explicit `-length 12` and a larger `-charset` (e.g. including uppercase).

---

## 3. Profiles

### 3.1 Shortuid (default)

- **Length:** 6
- **Charset:** `0123456789bcdfghjkmnpqrstvwxyz`
- **Used by:** HelperClass::generate(), and thus dumper.php (via helper::generate())
- idpwgen’s built-in defaults match this; call with no args or with `-length 6 -charset "0123456789bcdfghjkmnpqrstvwxyz"`.

### 3.2 Password

- **Length:** 12
- **Charset:** Override with a larger set (e.g. digits + upper + lower, and optionally symbols) as required for `ret_password()`.
- **Used by:** pbx3api `Helper::ret_password()` only.

---

## 4. Wiring idpwgen into pbx3 (shortuid)

### 4.1 HelperClass

In `pbx3/pbx3-1/opt/pbx3/php/classes/HelperClass`:

- Add a helper that runs idpwgen and validates output, e.g.:
  - Command: use the path from **config.php** constant **`IDPWGEN`** (do not hardcode the path). Example: `IDPWGEN . ' -length 6 -charset "0123456789bcdfghjkmnpqrstvwxyz"'` or call with no args (defaults are 6 and that charset).
  - Execute via `shell_exec()` or `proc_open()` with proper escaping; optional timeout for safety.
  - Trim stdout; validate length (6) and that every character is in the charset.
  - On failure: log (exit code, stderr) and throw or return error so callers do not get invalid data.
- **Replace** `HelperClass::generate()` implementation so it **only** uses this idpwgen path (no PHP fallback).

### 4.2 dumper.php

- dumper.php already uses `helper::generate()` for shortuid. No code change needed in dumper.php once HelperClass::generate() uses idpwgen.
- **Update the “existing shortuid” check** in dumper.php: the current regex `^[a-zA-Z0-9]{8}$` assumes 8-character shortuids. Change it to match **6** characters and, if desired, the actual shortuid charset (e.g. `^[0-9bcdfghjkmnpqrstvwxyz]{6}$` or a looser pattern) so previously issued shortuids are not overwritten.

---

## 5. Wiring idpwgen into pbx3api (passwords)

In `pbx3api/app/Helpers/Helper.php`:

- Add a helper that runs idpwgen with explicit length and charset:
  - **Path:** pbx3api does not load pbx3’s config.php. Use a Laravel config value (e.g. `config('pbx3.idpwgen_path')`) or an env var (e.g. `env('IDPWGEN_PATH', '/opt/pbx3/golang/idpwgen')`) so the path is not hardcoded. Default to `/opt/pbx3/golang/idpwgen` when unset.
  - Command: `<path> -length 12 -charset "<PASSWORD_CHARSET>"` (define PASSWORD_CHARSET to include digits, upper, lower, etc.).
  - Execute, capture stdout, validate length and charset.
  - On failure: log and treat as error (no fallback).
- **Replace** `ret_password()` implementation so it **only** uses this idpwgen path.

---

## 6. Packaging and deployment

1. **Build at install**
   - Do **not** ship the compiled binary in the .deb. Build it during install so it runs on the target architecture (e.g. arm64 and amd64).
   - Add **golang-go** (or the appropriate package) to `debian/control` Depends so `go build` is available at install time.
   - In postinst (or equivalent), from the package’s golang dir: `go build -o idpwgen idpwgen.go`, then place the binary at `/opt/pbx3/golang/idpwgen` (or the chosen path). Ensure that path is used consistently in PHP.
   - Add the compiled binary to **.gitignore** so it is not committed.

2. **Permissions**
   - `idpwgen` must be executable by:
     - The user that runs pbx3 PHP CLI (e.g. for dumper, scripts).
     - The pbx3api PHP-FPM user (e.g. www-data).

3. **Path (no hardcoding)**
   - **pbx3:** Use the constant **`IDPWGEN`** from `php/config.php` (defined as `SYSPATH . '/golang/idpwgen'`). HelperClass and any pbx3 script that invokes idpwgen should use this constant.
   - **pbx3api:** Does not load pbx3’s config. Use a config key or env var (e.g. `config('pbx3.idpwgen_path')` or `env('IDPWGEN_PATH', '/opt/pbx3/golang/idpwgen')`) so the path is configurable and not hardcoded.

4. **Documentation**
   - Mention idpwgen in:
     - `PHP_SCRIPTS_AND_MODULES.md` (as the generator used for shortuids and by API for passwords).
     - Install/deploy docs if they reference Go or the binary location.

---

## 7. Testing

- **Shortuid:** Call the HelperClass shortuid path (and/or dumper) and verify generated values are length 6 and only use chars from `0123456789bcdfghjkmnpqrstvwxyz`.
- **Password:** Call `ret_password()` and verify length 12 and charset (including uppercase as defined).
- **Failure handling:** If idpwgen is missing or returns an error, confirm PHP logs the failure and does not return invalid data (callers should see an error, not a bad shortuid/password).

---

## 8. Summary

| Use case    | Length | Charset                          | Call sites                                      |
|-------------|--------|-----------------------------------|-------------------------------------------------|
| Shortuid    | 6      | 0123456789bcdfghjkmnpqrstvwxyz   | HelperClass::generate(); dumper.php (via same) |
| Password    | 12     | Override (e.g. + uppercase)       | pbx3api Helper::ret_password()                 |

No backward compatibility or config toggles; idpwgen is the single source from first deploy.
