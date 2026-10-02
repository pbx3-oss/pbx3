# Phone provision — lab recipe (A6 + C edge)

**Law:** `PROVISIONING_SERVER_REQUIREMENTS.md` · plan `PROVISIONING_IMPLEMENTATION_PLAN.md`.  
**Edge ops:** `pbx3sbc/workingdocs/PROVISION_EDGE_PROXY.md`.

Automated coverage: `php /opt/pbx3/scripts/tests/provision-kernel-test.php` (and package-tree equivalent). This recipe is **handset / curl soak**.

---

## 0. Pre-flight (home)

1. Packages/tip include provision kernel + streams + `install-provision-listener.sh`.
2. Schema: `sudo /opt/pbx3/scripts/apply-sqlite-add-provision-columns.sh`
3. Listener + firewall:
   - After nginx/php-fpm: `sudo /opt/pbx3/scripts/install-provision-listener.sh solo` **or** `fleet`
   - UFW: new installs get `:41363` in baseline. Fleet: **SBC IP(s) only**. Mirror in AWS SG if used.
4. Solo HTTPS needs `apply-active-cert.sh` (snippet `pbx3-ssl-active.conf`).

**Solo URL:** `https://{instance-fqdn}:41363/provisioning/{mac}.cfg`  
**Fleet phone-facing:** `https://provision.{apex}:41363/provisioning/{mac}.cfg` (edge) → HTTP home.

### Manual URL (non-Snom/Yealink lab)

For brands without near-term mTLS/RPS (e.g. Grandstream, Gigaset, Fanvil soak): enter the fleet or solo provision URL **on the phone UI** (same paths as above). Enough to exercise stream/REGISTER; does **not** prove RPS or vendor client-cert.

### C5 mTLS tip (Snom + Yealink)

On SBC (after ops builds Snom+Yealink PEM — see `pbx3sbc` **`PROVISION_EDGE_PROXY.md`** § C5):

```bash
sudo VENDOR_CLIENT_CA_BUNDLE=/path/to/vendor-client-cas-snom-yealink.pem \
     PROVISION_MTLS=optional \
     PROVISION_FQDN=provision.pbx3.com \
     ./scripts/install-provision-edge.sh
```

`optional` keeps curl + manual-URL brands working. Prove Snom/Yealink phone GET still **200** with vendor client cert presented.

### Operator allow (lab eyeball — keep temporary)

Fleet baseline is **SBC-only** on home `:41363`. Temporary laptop allow: UFW/SG from your IP; **remove when done**.

---

## 1. Extension row

| Field | Value |
|-------|--------|
| `macaddr` | Phone MAC |
| `provision` | Prefer `#INCLUDE yealink.Extension` / `snom.Extension` (+ transport). **SIP host = tenant FQDN** (`$sipdomain`); **outbound proxy = SBC** (`$outbound`) when fleet. |
| `sndcreds` | `Once` (preferred) |
| `passwd` | Known SIP secret |

Commit/PJSIP as usual — provision GET does **not** require Commit.

---

## 2. Curl prove — home (Phase A)

```bash
MAC=aabbccddeeff
FQDN=xxxxxxxx.pbx3.com
curl -sk "https://${FQDN}:41363/provisioning/${MAC}.cfg" | head   # solo
curl -s "http://${FQDN}:41363/provisioning/${MAC}.cfg" | head    # fleet home (SBC or temp allow)
```

Expect: substituted body; Once → No after first send; audit obfuscated.

---

## 3. Fleet edge (Phase C) — lab 2026-09-30 green

**DNS:** `provision.pbx3.com` A → edge VIP (`3.93.26.82`). **LE** on SBC for that name.  
**Gatekeeper:** claim MAC → tenant + instance; conflict **409**; map at `catalog/provision-mac.map`.  
**SBC:** `install-provision-edge.sh` + `sync-provision-mac-map.sh` (`PBX3_ORG_BUCKET=…`).

```bash
# known MAC → 200; unknown / y000000 → 404
curl -sS -o /dev/null -w '%{http_code}\n' \
  "https://provision.pbx3.com:41363/provisioning/${MAC}.cfg"
```

Body must show **`sip_server_host` = tenant FQDN** (e.g. `{shortuid}.pbx3.com`) and **`outbound_host` = `sbc.pbx3.com`** with **outbound proxy enabled** — not SBC in the SIP-server field, not `127.0.0.1` / proxy off.

**Handset:** RPS or manual URL → `https://provision.pbx3.com:41363/provisioning/{mac}.cfg` (Yealink) or `…/provisioning?mac={mac}` (Snom). Both forms route on the edge when the MAC is in the map.

After claim from Gatekeeper (until api tip-hot): re-run **`sync-provision-mac-map.sh`** on SBC if map lag.

---

## 4. Exit checks

### A6
- [x] Known MAC → 200; unknown → 404  
- [x] Once flip + audit  
- [x] A7 suite  
- [x] Reset Once (SPA)  

### C lab
- [x] Edge LE URL → home via MAC map  
- [x] #11 no-MAC / y000000 → 404  
- [x] Yealink handset provision + SIP via SBC  
- [ ] C7/C8 automated exit  
- [ ] Tenant move → next provision without RPS edit  

**Next:** merge C2/C3 PRs · **B2** MkDocs RPS · api MAC claim tip on homes.
