# Vendor-grain provision stream fragments (Phase A).

Resolved by `#INCLUDE <name>` from `ipphone.provision` (and nested includes).
No Device table. No per-SKU matrix. BLF templates (`*.Fkey` / `*.Lkey` / `*.Pkey`) are skipped.

## Seeded (Snom + Yealink + Panasonic + Fanvil mule)

| Grain | Role |
|-------|------|
| `snom.Common` / `yealink.Common` | Shared site defaults |
| `snom.Extension` / `yealink.Extension` | Preferred extension entry (`$sipdomain` + `$outbound`) |
| `fanvil.Common` / `fanvil.Extension` | **Mule v0** — FDPS-era **module XML** (`VOIP_CONFIG_FILE`). Lab soak via manual Static Provision URL. Not a full OEM template. |
| `snom` / `Yealink` / `Panasonic` | Legacy Device-table vendor aliases — same split: SIP domain vs SBC outbound |
| `{snom,yealink,panasonic,fanvil}.{udp,tcp,tls}` | Transport / SRTP override fragments. **Snom** outbound uses `$outbound_hostport` / `$outbound` (fleet = SBC). `panasonic.udp` / `fanvil.udp` empty stubs. |
| `{snom,yealink,panasonic}.{ipv4,ipv6}` | IPv4 vs IPv6 hints |
| `panasonic.Ldap` | Optional LDAP fragment |

Typical ETL / migrated extension:

```text
#INCLUDE snom
#INCLUDE snom.Fkey
#INCLUDE snom.udp
#INCLUDE snom.ipv4
```

(`*.Fkey` is ignored; transport + ipv4 fragments apply.)

Preferred new authoring (Snom/Yealink):

```text
#INCLUDE snom.Extension
#INCLUDE snom.udp
```

Fanvil mule:

```text
#INCLUDE fanvil.Extension
#INCLUDE fanvil.udp
```

Panasonic (sail65 shape):

```text
#INCLUDE Panasonic
#INCLUDE panasonic.udp
#INCLUDE panasonic.ipv4
```

Placeholders: `$ext` (dialable) `$sipuser` / `$shortuid` (PJSIP auth) `$password` `$desc`
`$sipdomain` `$outbound` `$outbound_enable` `$outbound_hostport` `$proxy`
`$localip` `$bindport` `$tlsport` `$provurl` `$padminpass` `$puserpass` + LDAP tokens (see `ProvisionKernel`).
Legacy `$registrar` = alias for `$sipdomain` (tenant SIP domain — **not** the SBC).
REGISTER / auth usernames use **`$sipuser`** (= `ipphone.shortuid`), not dialable `$ext`.

**Fanvil notes:** stock is **XML** (not Yealink line CFG). `#INCLUDE` lines are stripped by the kernel before the phone sees the body. First boot: set **Static Provisioning Server** on the phone UI (see `PROVISIONING_LAB_RECIPE.md` §5). `Download_Protocol` 4 = HTTPS — some firmwares want 5; tweak on mule if GET fails. `FDPS_Enable=0` for lab static URL.