# Audio transcription — requirements (stub)

**Status:** Direction **2026-09-08** (TODO **#37** / **0l**). Keep it simple.  
**Related:** **`VOICEMAIL_ARCHIVE_REQUIREMENTS.md`** · **`RECORDINGS_STORAGE_DESIGN.md`** · **`TODO.md`**.

---

## 1. Direction

- **Pluggable provider interface** — operator/tenant chooses the backend; do not hard-wire a single STT vendor.
- **First uses:** voicemail + call recordings (batch).
- **Audio:** Asterisk stays on **local spool**; STT reads local file or S3 object after optional offload — **`VOICEMAIL_ARCHIVE_REQUIREMENTS.md`**.
- **Transcripts:** when audio is archived to S3, store the transcript **alongside it**; SQLite indexes (and may cache text for the UI).
- **Fleet vs solo:** STT does not require fleet. Solo may use a **home-owned** S3 bucket; fleet keeps gatekeeper/org bucket. Isolate that behind storage plumbing — **`VOICEMAIL_ARCHIVE_REQUIREMENTS.md`** · **`RECORDINGS_STORAGE_DESIGN.md`**. Do **not** force SBC/fleet-of-one just for archive/STT.
- **Adapters:** ship behind the interface as needed (hosted APIs and/or self-hosted engines). Prefer adding a provider over forking the product per deployment.
- **First-out:** **Pharma / PV** is a potential early requirement driver.

---

## 2. v1 scope (YAGNI)

**In:** submit audio → get text → store next to the recording/VM id; choose provider in config.  
**Out unless pulled in:** heavy analytics packs, real-time captions, Litestream, separate VM-only S3 product surface.

---

## 3. History

| Date | Note |
|------|------|
| 2026-09-08 | Pluggable STT direction; solo vs fleet S3 accommodation. |
| 2026-09-08 | Pharma / PV noted as potential first-out driver (no further framing). |
