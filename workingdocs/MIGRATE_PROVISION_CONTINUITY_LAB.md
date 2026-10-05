# Mini-project stub: SARK migrate → provision continuity

**Status:** Open — lab assessment (2026-10-04).  
**Home (procedure + results):** private **`aelintra/sark-to-pbx3`** → **`docs/MIGRATE_PROVISION_CONTINUITY_LAB.md`**.  
**Parent product:** **`PROVISIONING_SERVER_REQUIREMENTS.md`** · TODO **0e** / **#23c**.  
**Stance:** Assist-not-core provision; v2 ETL does **not** transplant SARK Device catalogs. Lab decides whether that is acceptable or needs a narrow ETL/runbook fix.

## Questions to answer in lab

1. After v2 migrate, do desks keep **MAC** + a usable **`ipphone.provision`** stream?
2. How often was the template only on SARK **Device** (empty row `provision`)?
3. What **features** (BLF / site Common) disappear when Device fat is dropped?
4. What must an operator **touch per extension** before the next phone GET works?
5. Should **#23c** (Snom line→XML) wait until this lab’s verdict?

Do not expand “provisioning server transplant” without a new REQUIREMENTS lock in sark-to-pbx3.
