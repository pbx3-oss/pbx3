# PHP scripts in pbx3 and minimal requirements

The pbx3 package **Depends** on **php-cli** and **php-sqlite3** (see debian/control). The installer and setip require PHP; Asterisk config generation and migrations use the same stack.

## Installer

- **installer.sh** runs **php/utilities/setip.php** once (network detection, shorewall, fail2ban, Asterisk localnet, /etc/issue). It runs **php utilities/genbashconfig.php** only when `php` is available; if not, it uses the shipped bashconfig.

## setip (no systemd)

- **setip** is run **once** by the installer (`php utilities/setip.php`). There is no debsetlan.service; the installer disables/removes it if present. setip uses NetHelperClass (and DbClass for `globals.staticipv4`).

## PHP scripts and what they need

| Script | Used by | Purpose | PHP modules (minimal) |
|--------|---------|---------|------------------------|
| **php/utilities/setip.php** | systemd debsetlan.service | Network detection, shorewall/fail2ban/Asterisk/localnet, /etc/issue | php-cli, php-sqlite3 (NetHelper → DbClass) |
| **php/utilities/genbashconfig.php** | installer (optional), manual | Rebuild `scripts/bashconfig` from `config.php` | none (core only) |
| **php/config.php** | genbashconfig, other PHP | Source of truth for paths; only `define()` | none |
| **php/utilities/runAstGen.php** | genAst.sh | Generate Asterisk config from DB | likely DbClass, GenClass → need **php-sqlite3** (and whatever the classes use) |
| **php/utilities/dumper.php** | migrateLegacyDb.sh | DB dump/restore | **php-sqlite3** |
| **php/utilities/refactorGreetings.php** | migrateLegacyDb.sh | Migration | as per dumper + dependencies |
| **php/utilities/refactorOldDB.php** | migrateLegacyDb.sh | Migration | as per dumper |
| **php/utilities/sanitize-firewall.php** | reloader.sh (currently dead code after `exit`) | Format shorewall rules | core only |
| **php/utilities/sipiaxfix.php** | commented out in reloader | SIP/IAX fixup | unknown |

## Shortuid and password generation (idpwgen)

- **Architecture / OS:** The binary must be built on the **same** machine (or same OS+arch cross-compile target) that runs PHP/pbx3api. A binary built on **macOS arm64** will **not** run on **Linux arm64** (`cannot execute binary file: Exec format error`, shell exit 126). After copying a tree from a Mac, **delete** `/opt/pbx3/golang/idpwgen` and rebuild on the server: `cd /opt/pbx3/golang && go build -o idpwgen idpwgen.go && chmod 755 idpwgen`, or re-run **installer.sh** (it removes the old binary before building).
- **idpwgen** is a Go binary at `/opt/pbx3/golang/idpwgen`, built at install by **installer.sh** (not shipped in the package). It is used for:
  - **Shortuids** (6 chars, charset without vowels/similar): **HelperClass::generate()** in pbx3 and **dumper.php** (via `helper::generate()`), and **generate_shortuid()** in pbx3api.
  - **Phone passwords** (12 chars, mixed charset): **pbx3api** **Helper::ret_password()** only.
- Path in pbx3: **config.php** constant **`IDPWGEN`**. Path in pbx3api: env **`IDPWGEN_PATH`** (default `/opt/pbx3/golang/idpwgen`).

## Minimal PHP for “run generator / migrations”

- **php-cli**
- **php-sqlite3** (DbClass and DB access)
- Any other extensions required by `php/classes/*` (e.g. if GenClass or others use mbstring, gd, etc., add those). Check with `php -r "require 'config.php';"` and fix missing extensions from error output.

## Summary

- **Package Depends:** php-cli, php-sqlite3 (installer and setip require them).
- **With php-cli + php-sqlite3:** Can run genbashconfig, setip, genAst.sh, and migrateLegacyDb.sh; add other extensions if classes need them.
