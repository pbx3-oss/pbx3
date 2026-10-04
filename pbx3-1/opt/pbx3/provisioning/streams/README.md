# Vendor-grain provision stream fragments (Phase A).

Resolved by `#INCLUDE <name>` from `ipphone.provision` (and nested includes).
No Device table. No per-SKU matrix. BLF templates (`*.Fkey` / `*.Lkey` / `*.Pkey`) are skipped.

## Seeded (Snom + Yealink + Panasonic + Fanvil + Poly mule)

| Grain | Role |
|-------|------|
| `snom.Common` / `yealink.Common` | Shared site defaults. **Snom** stock is still **line** format; **TODO #23c** → OEM XML (`<settings>` / `idx=` — sample **`workingdocs/samples/snom-settings-xml-example.xml`**). |
| `snom.Extension` / `yealink.Extension` | Preferred extension entry (`$sipdomain` + `$outbound`) |
| `fanvil.Common` / `fanvil.Extension` | **Mule v0** — FDPS-era **module XML** (`VOIP_CONFIG_FILE`). Lab soak via manual Static Provision URL. Not a full OEM template. |
| `poly.Master` / `poly.Common` / `poly.Extension` | **Mule v0** — UCS master (`poly.Master` → `{mac}.cfg` / `000000000000.cfg`) + **closed XML** settings (`polycomConfig` on `{mac}-reg.cfg`). STUN + UDPOnly + both ports. See **`POLY_PROVISION_SUBPROJECT.md`**. |
| `grandstream.Common` / `grandstream.Extension` | **Mule v0** — `<gs_provision>` P-values for **GRP2602P**; phone GET **`cfg{mac}.xml`**. Dial plan **P290** includes `*xx*`. See **`GRANDSTREAM_PROVISION_SUBPROJECT.md`**. |
| `snom` / `Yealink` / `Panasonic` | Legacy Device-table vendor aliases — same split: SIP domain vs SBC outbound |
| `{snom,yealink,panasonic,fanvil}.{udp,tcp,tls}` · `poly.udp` · `grandstream.udp` | Transport stubs. **Snom** outbound uses `$outbound_hostport` / `$outbound` (fleet = SBC). `poly` transport is **UDPOnly** inside Extension. |
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

Poly mule (VVX UCS single-file):

```text
#INCLUDE poly.Extension
#INCLUDE poly.udp
```

Grandstream mule (GRP2602P XML):

```text
#INCLUDE grandstream.Extension
#INCLUDE grandstream.udp
```

Panasonic (sail65 shape):

```text
#INCLUDE Panasonic
#INCLUDE panasonic.udp
#INCLUDE panasonic.ipv4
```

Placeholders: `$ext` (dialable) `$sipuser` / `$shortuid` (PJSIP auth) `$password` `$desc`
`$sipdomain` `$outbound` `$outbound_enable` `$outbound_hostport` `$proxy`
`$localip` `$bindport` `$tlsport` `$provurl` `$provpath` `$padminpass` `$puserpass` + LDAP tokens (see `ProvisionKernel`).
`$provpath` = `$provurl` without `https://` (Grandstream **P192**).
Legacy `$registrar` = alias for `$sipdomain` (tenant SIP domain — **not** the SBC).
REGISTER / auth usernames use **`$sipuser`** (= `ipphone.shortuid`), not dialable `$ext`.

**Grandstream notes:** Phone GET **`cfg{mac}.xml`**. Edge + kernel extract MAC from that name. Auth ID (**P36**) omitted — shortuid in **P35** only. Dial plan **P290** includes `*xx*`. NAT **`P52=4` (Auto)**. Config path **`P237`** (not **P192** firmware). Admin web **P2**=`$padminpass` ← **cluster.padminpass**. INVITE source filter: **`P2347=1`** (Accept Incoming SIP from Proxy Only — not CLI **P129**). Recipe **`PROVISIONING_LAB_RECIPE.md` §6** · **`GRANDSTREAM_PROVISION_SUBPROJECT.md`**.

**Fanvil notes:** stock is **`sysConf`** XML (X3U Pro ≥2.2.10). `#INCLUDE` lines are stripped by the kernel before the phone sees the body. First boot: set **Static Provisioning Server** on the phone UI (see `PROVISIONING_LAB_RECIPE.md` §5). `FlashProtocol` **5** = HTTPS. **`BanAnonymous=1`** (CLI). **`SignalPort=5160`** (local SIP off 5060 — ghost-call obscurity; no proxy-only INVITE filter on X3U).

**Poly notes:** UCS closed XML. `{mac}.cfg` / `000000000000.cfg` = **master** (`poly.Master`); settings = `{mac}-reg.cfg` (`poly.Extension` + `poly.Common`). Point Provisioning Server at our HTTPS **directory** base. Password attribute is on its own `<reg …/>` line so sndcreds No can omit it. Keep `poly.udp` **empty** so nothing trails after `</polycomConfig>`. STUN only via stream (§0.2). INVITE source filter: **`voIpProt.SIP.requestValidation.1`** `request=INVITE` / `method=source`. Recipe **`PROVISIONING_LAB_RECIPE.md` §7**.

**Desk ghost-call / INVITE-source (fleet):** Yealink **`sip_trust_ctrl=1`** · Snom **`filter_registrar=on`** · Grandstream **`P2347=1`** · Poly **`requestValidation` source** · Fanvil **`BanAnonymous=1`** + **`SignalPort=5160`** (no true proxy-only filter).