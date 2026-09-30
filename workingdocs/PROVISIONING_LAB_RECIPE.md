# Phone provision — Phase A lab recipe (A6)

**Branch / code:** pbx3 `feat/provision-a1-home-kernel` (Phase A home listener).  
**Law:** `PROVISIONING_SERVER_REQUIREMENTS.md` · plan `PROVISIONING_IMPLEMENTATION_PLAN.md`.

Automated coverage: `php /opt/pbx3/scripts/tests/provision-kernel-test.php` (and package-tree equivalent). This recipe is **handset / curl soak** — not a substitute for A7.

---

## 0. Pre-flight (home)

1. Packages/tip include provision kernel + streams + `install-provision-listener.sh`.
2. Schema: `sudo /opt/pbx3/scripts/apply-sqlite-add-provision-columns.sh`
3. Listener + firewall:
   - After nginx/php-fpm: `sudo /opt/pbx3/scripts/install-provision-listener.sh solo` **or** `fleet`
   - UFW: new installs get `:41363` in baseline. Existing `/etc/pbx3/firewall.allows.json` — delete and re-run `ufw-apply-baseline.sh fleet|solo`, or add **41363/tcp** in Admin → Firewall (fleet: SBC IP only).
4. Solo HTTPS needs `apply-active-cert.sh` (snippet `pbx3-ssl-active.conf`).

**Solo URL shape:**

```text
https://{instance-fqdn}:41363/provisioning/{mac}.cfg
https://{instance-fqdn}:41363/provisioning?mac={mac}
```

**Fleet home (Phase A behind future edge):** plain `http://{home}:41363/provisioning/…` from SBC only. Phone-facing RPS stays Phase C (`provision.{apex}`).

---

## 1. Extension row

On a lab extension (SPA or SQL):

| Field | Value |
|-------|--------|
| `macaddr` | Phone MAC (any separator OK) |
| `provision` | `#INCLUDE yealink.Extension` or `#INCLUDE snom.Extension` |
| `sndcreds` | `Once` (preferred) |
| `passwd` | Known SIP secret |
| `provisionwith` | `FQDN` or `IP` (solo registrar hint) |

Commit/PJSIP as usual — provision GET must **not** require Commit.

---

## 2. Curl prove (before / instead of handset)

```bash
MAC=aabbccddeeff   # 12 hex
FQDN=xxxxxxxx.pbx3.com

# Solo HTTPS (ignore lab snakeoil verify if needed)
curl -sk "https://${FQDN}:41363/provisioning/${MAC}.cfg" | head

# Unknown MAC → 404
curl -sk -o /dev/null -w '%{http_code}\n' "https://${FQDN}:41363/provisioning/ffffffffffff.cfg"
```

Expect: body with `$ext` / registrar substituted; password present on first **Once** send; second GET omits secret lines; `sndcreds` → `No`; `last_provisioned_at` set; audit line in `/opt/pbx3/var/log/provision-audit.log` with `********` (not clear password).

Reset for re-test:

```bash
sqlite3 /opt/pbx3/db/sqlite.db "UPDATE ipphone SET sndcreds='Once' WHERE lower(replace(replace(macaddr,':',''),'-',''))='${MAC}';"
```

---

## 3. Handset / RPS

1. Enroll MAC in vendor RPS (Yealink / Snom) → solo URL above (or manual provision URL on phone).
2. Factory / reprovision phone; confirm config download and SIP register via normal path (fleet → SBC).
3. Optional: Yealink `y000000*.cfg` → serves `yealink.Common` (no MAC row required).

---

## 4. Exit A6

- [ ] Known MAC → 200 + vendor body; unknown → 404  
- [ ] Once flip + audit obfuscation observed on host  
- [ ] Phone registers after provision (solo or fleet SIP path unchanged)  
- [ ] A7 suite still green on the tip package  

Then Phase **B** (SPA URL / Reset Once) and **C** (edge proxy + MAC index) as scheduled.
