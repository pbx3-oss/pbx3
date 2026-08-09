# PBX3 Copilot Instructions

## Project Overview

PBX3 is a **backend-only** Asterisk PBX configurator that generates configs from a SQLite database. It's designed for Ubuntu 24.04 LTS and works with a separate `pbx3api` package (nginx + PHP-FPM) that provides the HTTP API.

**Core Architecture:**
- **SQLite Database**: Multi-schema design (`instance`, `tenant`) in `/opt/pbx3/db/sqlite.db`
- **Asterisk Config Generation**: PHP classes generate configs from DB data via `genAst.sh` → `runAstGen.php`
- **Network Management**: `setip.php` handles IP detection, shorewall, fail2ban, and Asterisk localnet
- **Package Structure**: All runtime files are under `pbx3-1/` (what gets installed to `/opt/pbx3`, `/etc`, etc.)

## Key File Paths

```
pbx3-1/opt/pbx3/php/config.php          # Source of truth for all paths
pbx3-1/opt/pbx3/scripts/bashconfig      # Generated from config.php via genbashconfig.php
pbx3-1/opt/pbx3/scripts/installer.sh    # Post-install setup (run manually, not from postinst)
pbx3-1/opt/pbx3/scripts/reloader.sh     # Rebuild SQLite DB from SQL files
pbx3-1/opt/pbx3/db/db_sql/               # Current schema: sqlite_create_{instance,tenant,laravel}.sql, sqlite_message.sql
pbx3-1/opt/pbx3/db/db_legacy_sql/        # Fleet repair: sqlite_normalize_cluster_to_shortuid.sql (SARK migrate SQL/PHP → aelintra/sark-to-pbx3)
pbx3-1/opt/pbx3/db/db_mysql/             # MySQL schema: mysql_create_catalog.sql
pbx3-1/opt/pbx3/php/classes/             # DbClass, GenClass, NetHelperClass, etc.
pbx3-1/opt/pbx3/php/utilities/            # Asterisk config generation (runAstGen.php, etc.) and other scripts
```

## Development Patterns

### Configuration Management
- **Always edit `config.php` first**, then run `php utilities/genbashconfig.php` to sync changes to `bashconfig`
- Path constants use `SYSROOT=/opt` + `SYSPREFIX=/pbx3` pattern
- Use `CODENAME=pbx3` (not SYSPREFIX) for package queries and system identification

### Database Operations
- Use `reloader.sh` to rebuild DB: backs up current DB to `db_database_dumps/last.db`, recreates from SQL
- Multiple schemas: instance (system-wide), tenant (per-customer), legacy (migration compatibility)
- **Important**: Instance `globals` table lacks LDAP columns; they exist in tenant `cluster` table

### PHP Dependencies
- Package depends on `php-cli` and `php-sqlite3` for core functionality
- Optional: install PHP for config generation and migrations
- All classes require DbClass; generator needs GenClass + full PHP stack

### Build & Deploy
```bash
# Build package (from repo root)
dpkg-buildpackage

# Install and setup
apt install ./pbx3_*.deb
sudo /opt/pbx3/scripts/installer.sh  # Run once manually

# Regenerate configs after DB changes
sudo /opt/pbx3/scripts/genAst.sh
```

## Critical Conventions

### Shell Scripts
- Use POSIX-compatible syntax (support dash/bash)
- Source `/opt/pbx3/scripts/bashconfig` for path variables
- Scripts must work when invoked via `sh scriptname` or `./scriptname`

### Asterisk Integration
- Config generation is **one-way**: DB → Asterisk configs via PHP generator
- Use `genAst.sh` after database changes to regenerate all Asterisk configs
- Generated configs go to `/etc/asterisk/` with proper ownership (asterisk:asterisk)

### Service Architecture
- **No HTTP server** in this package - pbx3api handles nginx/API
- `setip` runs once during install (not as systemd service)
- Use `installer.sh` for one-time setup, not package postinst

## Working with Components

### Database Schema Changes
1. Edit appropriate SQL file in `db/db_sql/`
2. Test with `reloader.sh` to verify schema loads
3. Update PHP classes if new tables/columns added
4. Run `genAst.sh` to regenerate Asterisk configs

### Network Configuration
- `NetHelperClass` handles interface detection and network config
- Shorewall rules generated from DB + templates in `etc/shorewall/`
- FQDN / domain: installer sets `globals.domain` (apex) and `globals.fqdn` (`{subdomain}.{domain}`); subdomain from `idpwgen` unless `INSTANCE_FQDN` legacy override; apex from `DOMAIN_TLD` env, prompt, or default `pbx3.com`

### Asterisk Config Generation
- Generator logic in `php/utilities/` (runAstGen.php, etc.) creates config fragments
- Each tenant can have different Asterisk settings
- Use existing GenClass patterns when adding new config generation

## Common Issues

- **LDAP Config**: LDAPHelperClass reads from `globals` but LDAP columns are in tenant `cluster` table
- **Path Consistency**: Always use constants from `config.php`, never hardcode `/opt/pbx3`
- **Permissions**: Asterisk configs need `asterisk:asterisk` ownership and correct permissions
- **PHP Availability**: Code should gracefully handle missing PHP (installer skips genbashconfig if no PHP)

## Documentation References

- `workingdocs/AGENT_HANDOFF.md` - Comprehensive project context
- `workingdocs/PHP_SCRIPTS_AND_MODULES.md` - PHP dependency mapping
- `workingdocs/TODO.md` - Known issues and open items
- `workingdocs/APACHE_CONFIG_TO_PBX3API.md` - Architecture decisions (backend vs API split)