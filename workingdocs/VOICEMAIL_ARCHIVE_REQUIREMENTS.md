# Voicemail archive storage — requirements

**Status:** Direction locked **2026-09-08**. Keep it simple.  
**Related:** **`RECORDINGS_STORAGE_DESIGN.md`** · **`AUDIO_TRANSCRIPTION_REQUIREMENTS.md`** · **`TODO.md`** #37.

---

## 1. Locked (minimal)

1. **Live leave / retrieve** — Asterisk **filesystem** spool only (current pbx3).  
2. **When we need durable archive or STT** — **async copy to S3** (same idea as recordings), then act on the object or the local file.  
3. **Transcripts (archived)** — **yes, in S3 next to the audio** (same id/prefix, e.g. `.txt` / `.json`). SQLite holds index + optional cached text for the UI — not the only copy of an archived transcript.

### Fleet vs solo S3 (locked)

Same product behaviour; **different plumbing** — isolate so STT/archive code does not care:

| | Fleet | Solo / singleton |
|--|-------|------------------|
| Phones / SBC | Unrelated — do **not** join fleet only for S3 | Stay singleton; no SBC chore |
| Bucket | Org/fleet recordings bucket via gatekeeper | **Home-owned** bucket |
| Objects | Audio + transcript side-by-side | Same |
| Catalog | SQLite `local` / `s3_only` | Same |

Solo S3 is a normal first step for existing singleton sites that want archive/STT without multi-tenant fleet. Implement as a storage backend choice, not a second product.

Do not change how Asterisk stores voicemail day-to-day.

---

## 2. Explicitly out (complexity we do not need)

- Native S3 / s3fs as the live mailbox  
- ODBC voicemail, SQLite audio BLOBs, Litestream-of-media  
- Separate `vm_s3` product surface until recordings-style offload is reused and a real gap appears  

---

## 3. History

| Date | Note |
|------|------|
| 2026-09-08 | File spool + optional async S3; reject FUSE/ODBC-SQLite-blob paths. |
| 2026-09-08 | YAGNI: no Litestream / extra capability flags in v1. |
| 2026-09-08 | Solo home-owned S3 vs fleet gatekeeper — isolate plumbing; no fleet-of-one for archive alone. |
