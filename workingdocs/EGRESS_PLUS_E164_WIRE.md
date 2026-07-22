# Fleet Egress wire — +E.164 toward SBC

**Related:** [`pbx3-directory/docs/NUMBER_DIALECT_REQUIREMENTS.md`](../pbx3-directory/docs/NUMBER_DIALECT_REQUIREMENTS.md)

Fleet nodes dial PSTN only via the **Egress** trunk to the SBC. Carrier-specific formats are applied on the SBC Peer dialect. The **node → SBC** userpart should be **+E.164** (e.g. `+441924918076`).

## Seed transform

[`pbx3-directory/tools/seed-fleet-egress-trunk.sh`](../pbx3-directory/tools/seed-fleet-egress-trunk.sh) sets Egress `transform` to:

```text
0:+44 00:+
```

So UK national (`0…`) and IDD (`00…`) become +E.164 before `Dial` via pbx3cagi `Mangle`. Numbers already in `+…` or digit E.164 pass through / are handled at the SBC (`DIALECT_STRIP_PLUS_RURI`).

Re-seed or set the same transform on existing Egress rows after upgrade; run commit / GenAst.

## CLI

Outbound CLIP is chosen on the node (`outboundClip` — trunk / cluster / extension). Prefer storing those CLIDs as **+E.164**. The SBC Magrathea/Gamma dialect then places PAID (and RPID on Magrathea) without guessing national vs international.

## Inbound from SBC

After SBC `DIALECT_INBOUND_NORMALIZE`, Asterisk sees **+E.164** R-URI. Align `inroutes.pkey` regexes accordingly.
