# PBX3 dbstruct Smoke Checklist

- [√] **Build/boot sanity**
  - [√] `pbx3cagi` starts and AGI scripts execute on target
  - [√] No runtime errors in Asterisk/AGI logs on first call

- [ ] **Inbound baseline**
  - [ ] Inbound DID to local extension rings/answers normally
  - [ ] No unexpected early answer

- [ ] **Outbound baseline**
  - [ ] Local extension can place outbound call through trunk
  - [ ] Audio and CLID behavior unchanged from expected baseline

- [ ] **Route fail behavior (tenant flags)**
  - [ ] Busy scenario honors tenant `play_busy`
  - [ ] Congestion/unavailable scenario honors tenant `play_congested`
  - [ ] Multi-path failover honors tenant `play_beep`

- [ ] **Transfer/forward behavior**
  - [ ] `allow_hash_xfer=enabled` allows `#` transfer feature
  - [ ] `allow_hash_xfer=disabled` blocks `#` transfer feature
  - [ ] External forward with `cfwd_progress=enabled` gives early-media behavior
  - [ ] External forward with `cfwd_progress=disabled` suppresses that behavior
  - [ ] External forward with `cfwd_answer=enabled` answers channel pre-dial
  - [ ] External forward with `cfwd_answer=disabled` does not pre-answer

- [ ] **Ingress controls**
  - [ ] `lterm` toggle changes answer timing as expected
  - [ ] `ringdelay` value is respected on inbound SIP/IAX legs
  - [ ] `maxin` cap enforced (reject/tones once exceeded)

- [ ] **IVR timing**
  - [ ] `ivr_key_wait` affects silence/retry timing
  - [ ] `ivr_digit_wait` affects inter-digit timeout behavior

- [ ] **Tenant API schema alignment**
  - [ ] `PUT /tenants/:id` accepts `spy_pass` and `syspass` as strings
  - [ ] `monitor_out`, `monitor_stage`, `leasedhdtime` save successfully
  - [ ] `GET /tenants/:id` returns expected persisted values/types

- [ ] **SPA tenant views**
  - [ ] Tenant Create shows Monitoring/Hot Desk section
  - [ ] Tenant Detail shows Monitoring/Hot Desk section
  - [ ] Save/reload round-trips `monitor_out`, `monitor_stage`, `leasedhdtime`
  - [ ] Advanced fields round-trip with updated types (`spy_pass`, `syspass`, `usemohcustom`, `emergency`)

- [ ] **Sysglobals scope clarity**
  - [ ] Sysglobals page displays scope note (instance globals vs tenant settings)
  - [ ] No accidental overwrite of tenant-specific values via sysglobals edit

- [ ] **Regression spot-check**
  - [ ] Local extension to local extension still works
  - [ ] Voicemail deposit/retrieval unaffected
  - [ ] Queue/agent login path still functional (quick smoke)
