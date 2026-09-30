# Vendor-grain provision stream fragments (Phase A).

Resolved by `#INCLUDE <name>` from `ipphone.provision` (and nested includes).
No Device table. No per-SKU matrix. BLF templates (`*.Fkey` / `*.Lkey` / `*.Pkey`) are skipped.

## Seeded (Snom + Yealink + Panasonic)

| Grain | Role |
|-------|------|
| `snom.Common` / `yealink.Common` | Shared site defaults |
| `snom.Extension` / `yealink.Extension` | Preferred extension entry (uses `$registrar`) |
| `snom` / `Yealink` / `Panasonic` | Legacy Device-table vendor aliases (ETL often uses these) |
| `{snom,yealink,panasonic}.{udp,tcp,tls}` | Transport / SRTP override fragments (`panasonic.udp` empty in sail65) |
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

Panasonic (sail65 shape):

```text
#INCLUDE Panasonic
#INCLUDE panasonic.udp
#INCLUDE panasonic.ipv4
```

Placeholders: `$ext` `$password` `$desc` `$registrar` `$localip` `$bindport` `$tlsport`
`$provurl` `$padminpass` `$puserpass` + LDAP tokens (see `ProvisionKernel`).
