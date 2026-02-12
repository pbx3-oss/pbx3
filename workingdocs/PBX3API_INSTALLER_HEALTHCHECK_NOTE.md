# pbx3api installer hardening note

## Next tightening step

Add a final health-check block to `pbx3api/scripts/installer.sh` that runs after nginx/php-fpm setup and fails the installer with a non-zero exit if validation fails.

## Required checks

1. **DB symlink check**
   - Verify `/opt/pbx3api/database/database.sqlite` exists and is a symlink.
   - Verify symlink target resolves to PBX DB path (`/opt/pbx3/db/sqlite.db` by default, or `PBX3_SQLITE_PATH` override).
   - Verify `www-data` can read and write the resolved target.

2. **nginx upstream check**
   - Verify nginx site has `fastcgi_pass` set to the expected PHP-FPM socket.
   - Verify expected socket exists (default `/run/php/php8.3-fpm.sock` or `PHP_FPM_SOCKET` override).
   - Run `nginx -t` before service reload/restart.

3. **HTTP readiness check**
   - Request local endpoint after service setup, e.g. `curl -k -s -o /dev/null -w "%{http_code}" https://127.0.0.1:44300/`.
   - If status is not `200`, print actionable diagnostics and exit non-zero.

## Suggested diagnostics on failure

- `systemctl status nginx --no-pager`
- `systemctl status php8.3-fpm --no-pager` (or selected `PHP_FPM_SERVICE`)
- tail of `/var/log/nginx/error.log`
- tail of `/opt/pbx3api/storage/logs/laravel.log`
