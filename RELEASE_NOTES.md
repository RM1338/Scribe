## Scribe v0.1.0 — first public release

The first build of Scribe: an AI meeting recorder that keeps your audio on your device and runs on an AI key you control. Record a meeting, and Scribe transcribes it and writes you a summary — decisions, action items, the gist — in seconds.

### What's in this build

- **Record** meetings with pause, resume, and mid-conversation bookmarks
- **Transcribe** with Groq's `whisper-large-v3-turbo`
- **Summarize** with `llama-3.3-70b` into something you'd actually forward on
- **Language detection + translation** of both transcript and summary
- **Folders** — organize meetings, and file one meeting into several folders at once
- **In-app scheduling** with start time, end time, and a description — no calendar app required
- **Reminders** — a heads-up 5 minutes before each meeting and again when it starts
- **Join now** — turn a scheduled meeting into a live recording in one tap, already named
- **Bring your own Groq key**, or route through the built-in server-side proxy that keeps the shared key out of the app binary
- **Export** transcripts and summaries to PDF
- **Search** across everything you've recorded
- Light / dark / system themes with a custom accent color

### Install (Android)

1. Download **`Scribe.apk`** from the Assets below
2. Open it on your phone — if prompted, allow installing from unknown sources
3. Launch Scribe, sign up, and grant the microphone and notification permissions

### Notes

- **Bring your own key:** for the fastest, most private setup, add your own [Groq API key](https://console.groq.com) in Settings. Without one, transcription and summaries run through the shared server-side proxy.
- **Reminders:** on first schedule, Scribe asks for notification permission — allow it so reminders can fire. Some phones also require enabling "exact alarms" for on-time reminders.
- This is an early release. If something breaks or feels off, please [open an issue](https://github.com/RM1338/Scribe/issues) — feedback shapes what ships next.

### Coming next

Cloud sync across devices · speaker diarization ("who said what") · shareable summary links · a web build.
