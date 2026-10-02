# Grandstream provision sub-project (D3 slice)

**Status:** **Parked / as-and-when** (2026-10-02). No stock streams yet; **mule handset pending**. Not on the critical path for provision A–C10.  
**Owns:** Optional Grandstream stock streams (`gs_provision` / P-values), lab soak when using our listener, NAT row, GDMS posture docs. **Not** a mandate that GS sites use our provision server.  
**Parent:** `PROVISIONING_SERVER_REQUIREMENTS.md` §0.2 / §4.4–§4.6 · plan **D3** · recipe **`PROVISIONING_LAB_RECIPE.md` §6** (when filled).  
**Siblings:** **`FANVIL_PROVISION_SUBPROJECT.md`** · Gigaset (same D3 bucket; separate when started).

**OEM guide:** [Grandstream SIP Device Provisioning Guide](https://www.grandstream.com/hubfs/Product_Documentation/gs_provisioning_guide.pdf) · P-value templates: [support/tools](https://www.grandstream.com/support/tools).

---

## 0. Stance

| Item | Stance |
|------|--------|
| Format | **XML P-value bag** (`<gs_provision>` → `<config>` → `<Pnnn>…</Pnnn>`). Legacy binary `cfg{mac}.bin` exists; we target **XML only** for stock streams. |
| Authoring | Opaque `P271`, `P237`, … map to web-UI knobs. **Do not invent P-numbers** — lift from the model’s firmware configuration template (CSV/XML from Grandstream tools). |
| File names | Phone requests **`cfg{mac}.xml`** (lowercase mac, no colons), then model / generic **`cfg.xml`** fallback. Our edge today serves `…/provisioning/{mac}.cfg` and `?mac=` — mule may need URL/path alignment or phone Config Server Path + filename convention; settle on first soak. |
| Engine | Dumb `#INCLUDE` + substitute — **no** Grandstream-specific kernel. |
| Discovery | **GDMS free** → preferred operator path for many GS sites. **Two supported postures:** (1) **GDMS end-to-end** (templates in GDMS; **no** our provision listener) — OK / no barrier; (2) GDMS/GAPS **redirect** → our `provision.{apex}` when home-rendered stream wanted. Lab mule may still use manual Config Server Path. |
| mTLS | GS client CA still open for public-edge (ops inventory); lab = manual URL + `optional` edge is fine. Need only if phones hit **our** edge. |

---

## 0.1 Product posture (locked 2026-10-02)

**We do not need Grandstream customers to use our provisioning server.** Free GDMS removes the “must build GS streams day one” pressure. Stock `grandstream.*` remains useful for sites that want secrets/home MAC map / same fleet provision URL as Yealink/Snom — optional, not mandatory for GS to work on PBX3.

---

## 1. Not on `main` yet

| Artifact | Notes |
|----------|-------|
| Streams | Add `grandstream.Common` / `grandstream.Extension` (+ transport stubs) when mule model is known |
| Lab soak | Recipe §6 — mirror Fanvil §5 once streams exist |
| NAT checklist | `FLEET_DESK_PHONE_NAT.md` Grandstream row — blank |

Sketch (placeholders only — P-numbers TBD from template):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gs_provision version="1">
  <mac>$mac</mac>
  <config version="1">
    <!-- SIP / outbound / STUN / admin: map $sipdomain $outbound $password … via real Pnnn -->
  </config>
</gs_provision>
```

Kernel: confirm `$mac` (or equivalent) is available in substitute map before relying on `<mac>` validation — if not, omit `<mac>` (guide says optional).

---

## 2. When the mule arrives (resume checklist)

1. Note **exact model + firmware**; download that release’s **configuration template** from Grandstream tools.
2. Author `grandstream.Common` / `grandstream.Extension` with real P-values for: SIP server = `$sipdomain`, outbound/proxy = `$outbound`, auth = `$sipuser` / `$password`, provision URL, STUN/NAT, admin pass.
3. Tip streams; spare extension MAC + `#INCLUDE grandstream.Extension`; `sndcreds=Once`.
4. Claim MAC / map sync (fleet).
5. Phone UI → Maintenance / Upgrade & Provisioning → **Config Server Path** = our provision HTTPS base (and filename / prefix-postfix if required).
6. Reboot; edge log GET — may be `cfg{mac}.xml` not `{mac}.cfg`. If 404, align edge/home routes or Config File Prefix/Postfix / path.
7. Exit: apply → REGISTER via SBC → audio + BYE; fill NAT row.
8. Export/backup from phone if available → ops `devdocs/provisioning/grandstream/`.

**Out of scope for first pass:** binary `cfg.bin`, AES XML encryption bootstrap, **GDMS API automation** (manual GDMS enroll is fine), BLF matrix, Gigaset/Fanvil.

**If site uses GDMS end-to-end:** sub-project soak (our streams) is **N/A** — still verify REGISTER/NAT on PBX3; document “GDMS-only” in recipe when proven.

---

## 3. Exit (this sub-project slice)

- [ ] One Grandstream model lab-green (provision + REGISTER + call/BYE)
- [ ] `grandstream.*` P-values lifted from that firmware template
- [ ] Request path (`cfg{mac}.xml` vs `{mac}.cfg`) documented + working on edge
- [ ] NAT row filled; recipe §6 exit checks ticked
- [ ] Optional MkDocs blurb under phone-provisioning

Then close GS under D3 or open GDMS / next brand.
