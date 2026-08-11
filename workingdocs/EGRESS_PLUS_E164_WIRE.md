# Fleet Egress wire — +E.164 toward SBC

**Related:** [`NUMBER_WIRE_POLICY.md`](../pbx3-directory/docs/NUMBER_WIRE_POLICY.md) (who does what) · [`NUMBER_DIALECT_REQUIREMENTS.md`](../pbx3-directory/docs/NUMBER_DIALECT_REQUIREMENTS.md) · operator manual [`pbx3-docs` `fleet/number-dialect.md`](../../pbx3-docs/docs/fleet/number-dialect.md)

Fleet nodes dial PSTN only via the **Egress** trunk to the SBC. Carrier-specific formats are applied on the SBC Peer dialect. The **node → SBC** userpart should be **`+CC…`** where **CC is the country code of the country that node serves** (UK `+44…`, US `+1…`) — not a hard-coded `+44` everywhere.

**Phase 1 (current policy):** the **node** produces that `+E.164` via Egress transform. Do not empty the transform until Phase 2 is gated — see the policy doc.

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

## Seed transform (US / NANP lab)

US / NANP nodes need a different seed — do **not** use UK `0:+44`. Longer IDD first:

```text
011:+ 1:+1
```

| Habit | Example | After transform |
|-------|---------|-----------------|
| NANP 1+10 | `15139266359` | `+15139266359` (`1:+1` strips `1`, adds `+1`) |
| US IDD overseas | `011441924918076` | `+441924918076` |

Product seed for new US tenants remains TODO **O4** (`SEED_OUTBOUND_ON_TENANT_CREATE.md`); set transform on existing Egress rows for lab (Commit / GenAst after).

Re-seed or set the transform on existing Egress rows after upgrade; run commit / GenAst.

## Inbound from SBC

After SBC `DIALECT_INBOUND_NORMALIZE`, Asterisk sees **+E.164**. Align `inroutes.pkey` regexes to `+CC…` / digit E.164.
