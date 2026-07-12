<div align="center">

# 🖋️ Scribe

### AI meeting notes that don't hold your data hostage.

**Record it. Transcribe it. Summarize it. In any language. On your key, on your device.**

[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Powered by Groq](https://img.shields.io/badge/AI-Groq%20%C2%B7%20Whisper%20%2B%20Llama-F55036)](https://groq.com)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%C2%B7%20iOS%20%C2%B7%20Linux-lightgrey)](#-platforms)
[![Version](https://img.shields.io/badge/version-0.1.0-1A8C7E)](https://github.com/RM1338/Scribe/releases)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-1A8C7E)](https://github.com/RM1338/Scribe/pulls)

⭐ **If Scribe saves you from ever typing "so what did we decide?" again, drop a star.**

</div>

---

## Why Scribe?

Every meeting-notes app wants the same deal: hand over your audio, your account, your monthly subscription — and trust that their servers do the right thing with the most sensitive conversations you have.

**Scribe flips it.**

- 🔒 **Your recordings live on your device.** Audio and transcripts are stored locally, per user. Nothing sits in someone else's bucket.
- 🔑 **Bring your own AI key.** Point Scribe at *your* Groq API key and pay cents, not a subscription. No key? The built-in server-side proxy keeps the shared key **out of the app binary** entirely — so it can never be scraped from a decompiled APK.
- 🌍 **Speaks your language.** Auto-detects the spoken language, transcribes it natively, and can translate both the transcript *and* the summary into the language you read in.
- 📵 **No calendar app required.** Scheduling is fully in-app, so it works identically on every phone — even the ones without a Google/Samsung calendar installed.

It's the meeting recorder for people who read the privacy policy.

---

## ✨ Features

| | |
|---|---|
| 🎙️ **One-tap recording** | Name it and hit record. Pause, resume, bookmark moments on the fly. |
| 📝 **Groq-fast transcription** | `whisper-large-v3-turbo` turns speech into text in seconds, not minutes. |
| 🧠 **Instant AI summaries** | `llama-3.3-70b` distills the whole meeting into decisions, action items, and highlights. |
| 🌐 **Detect & translate** | Automatic language detection, plus on-demand translation of transcript and summary. |
| 🗂️ **Multi-folder organization** | File one meeting into many folders. Add and remove without moving the original. |
| 📅 **In-app scheduling** | Plan meetings with start/end times and a description — no device calendar needed. |
| 🔔 **Smart reminders** | Two local notifications per meeting: a heads-up **5 minutes before** and one **at start**. |
| ⚡ **"Join now"** | Tap it on a scheduled meeting and Scribe starts recording, pre-named for you. |
| 🔑 **BYOK or proxy** | Use your own Groq key, or route through a Supabase Edge Function that hides the shared key. |
| 🔎 **Search everything** | Full-text search across your meetings with recent-search history. |
| 📄 **Export to PDF** | Share polished transcripts and summaries anywhere. |
| 🎨 **Themed your way** | Light / dark / system, with a custom accent color. |
| 🛰️ **Update banner** | In-app "new version available" prompt that links straight to the latest download. |

---

## 🏗️ How it works

```
        ┌──────────────────────────────────────────────┐
        │                Scribe (Flutter)              │
        │                                              │
        │   🎙️ record  →  local audio file (on device) │
        │                        │                     │
        │                        ▼                     │
        │        transcription + summary request       │
        └───────────────┬───────────────┬──────────────┘
                        │               │
             has own key│               │no key
                        ▼               ▼
                  ┌──────────┐   ┌───────────────────────┐
                  │  Groq    │   │ Supabase Edge Function │
                  │  direct  │   │  (proxy, key hidden,   │
                  │  (BYOK)  │   │   auth-gated)          │
                  └────┬─────┘   └───────────┬───────────┘
                       └───────────┬─────────┘
                                   ▼
                          ┌─────────────────┐
                          │   Groq  API     │
                          │ Whisper + Llama │
                          └─────────────────┘
```

- **State management:** `provider` (`ChangeNotifier` + proxy providers rebound on auth changes)
- **Storage:** local JSON + audio files, scoped per signed-in user
- **Auth & sync:** Supabase (email/password + email OTP)
- **AI:** Groq — Whisper for speech, Llama for summaries — reached directly (BYOK) or through auth-gated Edge Functions
- **Reminders:** `flutter_local_notifications` + `timezone`, anchored to the device's real timezone

---

## 🚀 Getting started

### Prerequisites

- Flutter SDK `^3.11` (Dart `^3.11`)
- A [Supabase](https://supabase.com) project
- A [Groq](https://console.groq.com) API key

### 1. Clone & install

```bash
git clone https://github.com/RM1338/Scribe.git
cd Scribe
flutter pub get
```

### 2. Configure your environment

Create a `.env` file in the project root:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

> **Note:** the Groq key is **never** put in `.env`. Users either add their own key in Settings, or requests are routed through the Supabase Edge Function, where the shared key lives only as a server-side secret.

### 3. Deploy the backend

```bash
# Apply the database schema
supabase db push --linked

# Deploy the Groq proxy functions
supabase functions deploy groq-transcribe
supabase functions deploy groq-chat

# Store the shared Groq key as a server secret (optional if BYOK-only)
supabase secrets set GROQ_API_KEY=gsk_your_key_here
```

### 4. Run it

```bash
flutter run
```

### Build a release

```bash
flutter build apk --release      # Android
flutter build ios --release      # iOS
```

---

## 📦 Platforms

| Platform | Status |
|----------|--------|
| 🤖 Android | ✅ Primary target |
| 🍎 iOS | ✅ Supported |
| 🐧 Linux | 🧪 Desktop preview (renders in a phone-frame) |

---

## 🗺️ Roadmap

- [ ] Cloud sync for recordings across devices
- [ ] Speaker diarization ("who said what")
- [ ] Shareable summary links
- [ ] Calendar import (opt-in)
- [ ] Web build

Have an idea? [Open an issue](https://github.com/RM1338/Scribe/issues) — this project grows with its stargazers.

---

## 🤝 Contributing

Contributions are welcome and appreciated. Fork it, branch it, and open a PR. For anything substantial, open an issue first so we can talk it through.

## ⭐ Support the project

Scribe is built in the open. If it's useful to you, the single most helpful thing you can do is **star the repo** — it's how other people find it.

---

<div align="center">

**Built with Flutter, Groq, and a healthy distrust of subscription meeting apps.**

</div>
