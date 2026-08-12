# Velocity — production prefix seeds (starter)

**Status:** Starter packs **2026-08-11** (research-backed; not a living GSMA feed).  
**Lab / fleet default:** UK premium dial forms **`0900`**, **`+44900`**, **`0044900`**.  
**Research:** ops **`TELEPHONE_FRAUD_RESEARCH.md`** §7 · Uboss snapshot · UK **`070`**.  
**Spec:** **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`**.

Matcher: CDR `dst` **prefix** (`LIKE prefix%`). Include **every dial form** your site actually writes into `master.db`.

**CoS still primary** — these seeds are for **velocity surge** (notify / ACT), not a full Uboss-sized bar list.

---

## Shared offshore core (same destinations, both packs)

Both UK and US packs cover this set. Only the **access / dial form** differs.

| Class | Destinations |
|-------|----------------|
| **NANP Caribbean** | 264 Anguilla, 268 Antigua, 246 Barbados, 284 BVI, 767 Dominica, 473 Grenada, 664 Montserrat, 649 Turks & Caicos, 876 Jamaica |
| **High-cost CC** | 247 Ascension, 252 Somalia, 232 Sierra Leone, 257 Burundi, 261 Madagascar, 265 Malawi, 960 Maldives, 211 South Sudan, 225 Côte d'Ivoire, 213 Algeria, 53 Cuba |
| **Special** | 3708 Lithuania personal, 870/881/882/883 (+871/878) satellite / UPT-class |
| **UK personal (from abroad)** | 4470 (`070` national on UK sites) |

| Pack | How offshore is dialled / matched |
|------|-----------------------------------|
| **UK** | `00` + CC (or `00` + `1` + NPA) and `+` E.164 — e.g. `001268…`, `00252…`, `+1268…` |
| **US** | `1` + NPA (domestic-looking), `011` + CC, and `+` E.164 — e.g. `1268…`, `011252…`, `+1268…` |

---

## UK premium (lab + production)

UK premium-rate national is **`09xx`** (fixture uses **`0900…`**). CDR may also store:

| Form | Example prefix |
|------|----------------|
| National | `0900` |
| E.164 | `+44900` |
| UK intl access | `0044900` |

Do **not** use `00900` — that is not a UK premium form (`00` = international access, not the `09` premium range). Do **not** use bare `44900` as the lab default (prefer `+44900` / `0044900`).

| Locale | File | Notes |
|--------|------|--------|
| Lab / fleet default | `PBX3_OPS_VELOCITY_PREFIXES` / policy | `0900,+44900,0044900` |
| UK starter | `config/velocity/prefixes-uk-starter.txt` | UK premium forms + `070`/`076` + offshore |
| US starter | `config/velocity/prefixes-us-starter.txt` | offshore + `0114470` / `+4470` (no UK `0900`) |

---

## UK pack env example

**Lab:** `0900,+44900,0044900`.

```bash
# Or: cat config/velocity/prefixes-uk-starter.txt
PBX3_OPS_VELOCITY_PREFIXES=0900,+44900,0044900,070,+4470,076,+4476,001264,001268,001246,001284,001767,001473,001664,001649,001876,+1264,+1268,+1246,+1284,+1767,+1473,+1664,+1649,+1876,00247,00252,00232,00257,00261,00265,00960,00211,00225,00213,002135,002136,002137,0021396,0053,003708,00870,008708,00871,00878,00881,00882,00883,+247,+252,+232,+257,+261,+265,+960,+211,+225,+213,+2135,+2136,+2137,+21396,+53,+3708,+870,+871,+878,+881,+882,+883
```

---

## US pack env example

```bash
PBX3_OPS_VELOCITY_PREFIXES=1264,1268,1246,1284,1767,1473,1664,1649,1876,+1264,+1268,+1246,+1284,+1767,+1473,+1664,+1649,+1876,011247,011252,011232,011257,011261,011265,011960,011211,011225,011213,01153,011870,011871,011878,011881,011882,011883,0113708,0114470,+247,+252,+232,+257,+261,+265,+960,+211,+225,+213,+53,+870,+871,+878,+881,+882,+883,+3708,+4470,070
```

---

## Changelog

| Date | Note |
|------|------|
| 2026-08-11 | UK + US starter packs; UK `070` personal. |
| 2026-08-11 | Lab/fleet default: **`0900` / `+44900` / `0044900`** (not `00900`; not bare `44900`). |
