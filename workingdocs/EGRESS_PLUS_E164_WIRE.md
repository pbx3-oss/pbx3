# Fleet Egress wire — +E.164 toward SBC

**Related:** [`pbx3-directory/docs/NUMBER_DIALECT_REQUIREMENTS.md`](../pbx3-directory/docs/NUMBER_DIALECT_REQUIREMENTS.md) · operator manual [`pbx3-docs` `fleet/number-dialect.md`](../../pbx3-docs/docs/fleet/number-dialect.md)

Fleet nodes dial PSTN only via the **Egress** trunk to the SBC. Carrier-specific formats are applied on the SBC Peer dialect. The **node → SBC** userpart should be **`+CC…`** where **CC is the country code of the country that node serves** (UK `+44…`, US `+1…`) — not a hard-coded `+44` everywhere.

## DNID vs CLID on the node

| Field | Mechanism | Notes |
|-------|-----------|--------|
| **DNID** (dialled) | Egress / trunk **transformation mask** | pbx3cagi `Mangle` before `Dial` |
| **CLID** | `outboundClip` (extension / cluster / trunk) | Sent **as stored** — masks do **not** rewrite CLI |

Store CLIDs as `+CC…` for that node’s serving country. Gamma/Magrathea PAID formatting is SBC outbound dialect, not a node mask.

## Seed transform (UK lab today)

[`pbx3-directory/tools/seed-fleet-egress-trunk.sh`](../pbx3-directory/tools/seed-fleet-egress-trunk.sh) sets Egress `transform` to:

```text
00:+ 0:+44
```

Longer prefix first (`00` before `0`) so overseas IDD is not mis-written as `+4400…`.

| Habit | Example | After transform |
|-------|---------|-----------------|
| UK national | `01924918076` | `+441924918076` |
| UK IDD overseas | `0015139266349` | `+15139266349` |

US / NANP nodes need a different seed (e.g. `011:+` for overseas; do **not** use UK `0:+44`). Example US→UK: `011441924918076` → `+441924918076`.

Re-seed or set the transform on existing Egress rows after upgrade; run commit / GenAst.

## Inbound from SBC

After SBC `DIALECT_INBOUND_NORMALIZE`, Asterisk sees **+E.164**. Align `inroutes.pkey` regexes to `+CC…` / digit E.164.
