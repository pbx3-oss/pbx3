# Phone provision — Phase A lab recipe (A6)

**Code:** pbx3 / pbx3api tip on home (Phase A listener + B1 URL / Reset Once).  
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

### Operator allow (lab eyeball — keep temporary)

Fleet baseline is **SBC-only** on `:41363`. To **view** a provision body from a laptop browser/curl (and later to debug **vendor client-cert / mTLS** failures with a clear diagnostic path):

1. Temporarily allow your public IP: Admin → Firewall, or  
   `sudo ufw allow from {your-ip}/32 to any port 41363 proto tcp comment 'pbx3-lab-operator-provision'`
2. Fetch: `curl -s "http://{home-fqdn}:41363/provisioning/{mac}.cfg"` (fleet) or solo HTTPS with `-sk`.
3. **Remove the rule when done** so production posture stays SBC-only (and later edge-mTLS).

Do not leave operator `:41363` open as the standing fleet policy.

---

## 1. Extension row

On a lab extension (SPA **Provision stream** or SQL):

| Field | Value |
|-------|--------|
| `macaddr` | Phone MAC (any separator OK) |
| `provision` | e.g. `#INCLUDE snom` + `snom.udp` + `snom.ipv4`, or `#INCLUDE snom.Extension` / Yealink / Panasonic |
| `sndcreds` | `Once` (preferred) |
| `passwd` | Known SIP secret |
| `provisionwith` | `FQDN` or `IP` (solo registrar hint) |

Commit/PJSIP as usual — provision GET must **not** require Commit. MAC alone is not enough if `provision` is empty.

---

## 2. Curl prove (before / instead of handset)

```bash
MAC=aabbccddeeff   # 12 hex
FQDN=xxxxxxxx.pbx3.com

# Solo HTTPS (ignore lab snakeoil verify if needed)
curl -sk "https://${FQDN}:41363/provisioning/${MAC}.cfg" | head

# Fleet home (HTTP; needs SBC or temporary operator allow — §0)
curl -s "http://${FQDN}:41363/provisioning/${MAC}.cfg" | head

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

Then Phase **B** (SPA URL / Reset Once / stream editor) and **C** (edge proxy + MAC index) as scheduled.
