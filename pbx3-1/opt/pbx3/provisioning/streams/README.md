# Vendor-grain provision stream fragments (Phase A).

Resolved by `#INCLUDE <name>` from `ipphone.provision` (and nested includes).
No Device table. No per-SKU matrix. BLF templates (`*.Fkey` / `*.Lkey` / `*.Pkey`) are skipped.

## Seeded (Snom + Yealink)

| Grain | Role |
|-------|------|
| `snom.Common` / `yealink.Common` | Shared site defaults |
| `snom.Extension` / `yealink.Extension` | Preferred extension entry (uses `$registrar`) |
| `snom` / `Yealink` | Legacy Device-table aliases (ETL often uses these; `$localip`) |
| `snom.udp` / `.tcp` / `.tls` | Transport / SRTP override fragments |
| `yealink.udp` / `.tcp` / `.tls` | Same for Yealink |
| `snom.ipv4` / `.ipv6` | IPv4 vs IPv6 DHCP hints |
| `yealink.ipv4` / `.ipv6` | Same for Yealink |

Typical ETL / migrated extension:

```text
#INCLUDE snom
#INCLUDE snom.Fkey
#INCLUDE snom.udp
#INCLUDE snom.ipv4
```

(`snom.Fkey` is ignored; transport + ipv4 fragments apply.)

Preferred new authoring:

```text
#INCLUDE snom.Extension
#INCLUDE snom.udp
```

Placeholders: `$ext` `$password` `$desc` `$registrar` `$localip` `$bindport` `$tlsport`
`$provurl` `$padminpass` `$puserpass` + LDAP tokens (see `ProvisionKernel`).
