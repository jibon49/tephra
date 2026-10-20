# Real-Device Sync Verification Procedure

This document specifies the validation and verification procedures on a physical Android phone and Windows PC pair using a real Google Drive test account.

---

## Prerequisites

1. Physical Windows 11 PC running Tephra Windows build (`flutter build windows --release`).
2. Physical Android device running Tephra APK (`flutter build apk --release`).
3. Google account added as a Test User in the Google Cloud Console OAuth consent screen.
4. Client credentials populated in `secrets/google_oauth.json`.

---

## 1. Fresh Install Pair
- **Steps**:
  1. On PC, create an encrypted remote vault from a copy of a real vault. Set encryption password and save recovery key.
  2. On phone, install Tephra, open/create an empty vault, select "Set up sync", sign in with the Google test user.
  3. Enter an incorrect vault password once. Verify that `WrongPasswordException` is caught and UI asks to re-enter.
  4. Enter the correct password and select "Download vault".
- **Verification**:
  - Compare file counts between PC and phone.
  - Spot-check 10 notes to confirm matching content and metadata.

---

## 2. Real-Time Sync Latency
- **Steps**:
  1. Have both apps open and connected on Wi-Fi.
  2. Edit a note on PC, save, and start stopwatch.
  3. Stop when the phone screen updates with the change.
  4. Repeat 10 times in both directions (PC -> Phone and Phone -> PC).
- **Gate**: Every run <= 60 s. Record median and max latency.

---

## 3. Airplane Mode Concurrent Edits (Airplane Day)
- **Steps**:
  1. Place phone into Airplane Mode.
  2. On phone, make edits across 10 notes.
  3. On PC, edit 5 of the same notes (different paragraphs in 3, same line in 2) and 5 other distinct notes.
  4. Disable Airplane Mode on phone to reconnect.
- **Verification**:
  - 3 notes with different paragraphs merge cleanly without conflict files.
  - 2 notes with same-line edits produce collision copies (`<note> (conflict <timestamp> <device>).md`).
  - All other edits are present on both devices.

---

## 4. Network Loss Mid-Upload
- **Steps**:
  1. Begin uploading a large attachment (e.g., 50 MB video) on PC.
  2. Disconnect network adapter for 2 minutes during upload.
  3. Reconnect network adapter.
- **Verification**:
  - Upload resumes and completes cleanly without duplicating files or corrupting chunks.

---

## 5. Rate Limiting Resilience
- **Steps**:
  1. Sync a folder containing 3,000 small markdown files.
  2. Monitor sync logs for 429 or 403 `userRateLimitExceeded`.
- **Verification**:
  - Exponential backoff with jitter retries automatically and finishes without manual user intervention.

---

## 6. Expired / Invalid Token Recovery
- **Steps**:
  1. On Windows, run debug command `sync.debug-break-token` (or delete access token and corrupt refresh token).
  2. Verify "Reconnect" status banner appears in sync settings / status tray.
  3. Click "Reconnect" and complete browser sign-in.
- **Verification**:
  - Sync resumes immediately without re-prompting for vault encryption password.
  - On Android: revoke permissions at `https://myaccount.google.com/permissions` and verify reconnect flow.

---

## 7. Storage Quota Full Handling
- **Steps**:
  1. Simulate quota exhaustion via `sync.debug-fake-quota` or filled test account.
- **Verification**:
  - Clear warning banner displayed in UI.
  - Uploads pause safely; downloads continue unimpeded.
  - Re-enabling space allows uploads to resume automatically.

---

## 8. 24-Hour Android Background Sync & Battery
- **Steps**:
  1. Unplug phone, close Tephra app, keep Background Sync enabled.
  2. Make periodic edits on PC throughout the day.
  3. After 24 hours, check Settings -> Battery -> Tephra battery percentage.
- **Gate**: Battery consumption < 2% / day. Edits made on PC must have arrived on phone.

---

## 9. Zero-Knowledge Encryption Inspection
- **Steps**:
  1. From web browser (`drive.google.com`), download the entire `Tephra/<vault>` folder as a zip.
  2. Extract on PC.
  3. Run recursive pattern search for 5 distinctive words from note bodies and 5 note file names:
     `Select-String -Path <folder> -Pattern '<word>' -Recurse -SimpleMatch`
- **Verification**:
  - Zero plaintext matches found (vault name in `vault.json` allowed by design).
  - Repeat with unencrypted test vault to confirm plaintext is readable when encryption is off.

---

## 10. Device Clone Detection
- **Steps**:
  1. Copy PC sync support directory (`<appSupportDir>/sync`) to another profile or machine.
  2. Trigger sync on both.
- **Verification**:
  - Clone is detected (`DeviceCloneDetectedException`).
  - Device automatically assigns itself a new device ID; zero data is lost.

---

## 11. Daily 2-Week Beta Usage
- **Steps**:
  1. Install release builds on user's primary phone and PC.
  2. Use daily for 2 weeks.
  3. Record daily notes in `PROGRESS.md`, tracking weekly reconnects due to Testing-mode 7-day token expiration.
