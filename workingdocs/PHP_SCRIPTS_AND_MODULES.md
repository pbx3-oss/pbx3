# PHP scripts in pbx3 and minimal requirements

The pbx3 package does **not** depend on PHP so a backend-only install works (installer uses the shipped `bashconfig`). When you need to run PHP (e.g. after editing `config.php` or for Asterisk config generation), install **php-cli** and the extensions below.

## Installer

- **installer.sh** runs `genbashconfig.php` only when `php` is available; if not, it skips it and uses the bashconfig shipped in the package.

## systemd: debsetlan.service (setip)

- **debsetlan.service** runs **php/utilities/setip.php** at boot / when started. It waits for the network, reads interface/IP/network from NetHelperClass (and optional static IP from DB), then configures shorewall, fail2ban, Asterisk localnet, and /etc/issue. This service **requires PHP**; the package Depends on **php-cli** and **php-sqlite3** so setip can run (NetHelperClass uses DbClass for `globals.staticipv4`).

## PHP scripts and what they need

| Script | Used by | Purpose | PHP modules (minimal) |
|--------|---------|---------|------------------------|
| **php/utilities/setip.php** | systemd debsetlan.service | Network detection, shorewall/fail2ban/Asterisk/localnet, /etc/issue | php-cli, php-sqlite3 (NetHelper → DbClass) |
| **php/utilities/genbashconfig.php** | installer (optional), manual | Rebuild `scripts/bashconfig` from `config.php` | none (core only) |
| **php/config.php** | genbashconfig, other PHP | Source of truth for paths; only `define()` | none |
| **php/generator/runAstGen.php** | genAst.sh | Generate Asterisk config from DB | likely DbClass, GenClass → need **php-sqlite3** (and whatever the classes use) |
| **php/utilities/dumper.php** | migrateLegacyDb.sh | DB dump/restore | **php-sqlite3** |
| **php/utilities/refactorGreetings.php** | migrateLegacyDb.sh | Migration | as per dumper + dependencies |
| **php/utilities/refactorOldDB.php** | migrateLegacyDb.sh | Migration | as per dumper |
| **php/generator/sanitize-firewall.php** | reloader.sh (currently dead code after `exit`) | Format shorewall rules | core only |
| **php/utilities/sipiaxfix.php** | commented out in reloader | SIP/IAX fixup | unknown |

## Minimal PHP for “run generator / migrations”

- **php-cli**
- **php-sqlite3** (DbClass and DB access)
- Any other extensions required by `php/classes/*` (e.g. if GenClass or others use mbstring, gd, etc., add those). Check with `php -r "require 'config.php';"` and fix missing extensions from error output.

## Summary

- **No PHP**: Installer and backend (Asterisk, DB, scripts that don’t call PHP) work. Use shipped bashconfig.
- **With php-cli + php-sqlite3**: Can run genbashconfig, and likely genAst.sh and migrateLegacyDb.sh after fixing any further missing extensions in the classes.
