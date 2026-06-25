# Changelog

All notable changes to this fork are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

This is a fork of [`cmagnussen/blitztext-app`](https://github.com/cmagnussen/blitztext-app),
maintained by Atelier 26. Entries below describe what differs from the upstream preview.

## [Unreleased] — Atelier 26 fork

### Added
- **Configurable German spelling (`GermanSpelling`)** — choose "Deutsch (mit ß)" or
  "Deutsch Schweiz (ss statt ß)" in Settings. Applies to all AI text outputs and the
  transcription: Claude is instructed to use Swiss spelling, and every `ß` is
  deterministically replaced with `ss` as a guarantee. Also added "Deutsch (Schweiz)"
  as a dedicated target language in Blitztext Translate.
- **Experimental iOS app target (`BlitztextiOS`)** — a standalone SwiftUI app that reuses
  the shared core (recording, OpenAI/Anthropic services, workflows). Record → transcribe →
  optional Claude rewrite/concept/translate → result on screen with Copy and Share.
  V1 is **online-only** (OpenAI Whisper + Claude); on-device WhisperKit on iOS is deferred
  because the current WhisperKit package pulls a non-iOS transitive dependency (Vapor).
  The cross-platform core was made platform-clean: `HotkeyMode`/`HotkeyCombo` moved to a
  shared file (AppKit-only `flags` guarded), workflow AppKit imports guarded, and
  `AudioRecorder` gained iOS `AVAudioSession` setup + microphone permission.
- **New mode "Blitztext Konzept" (`ConceptWorkflow`)** — turns free, rambling speech
  into a clean, structured concept: a short title, grouped paragraphs, and `–` bullet
  lists, separated by blank lines. Plain text (no Markdown), stays close to what was
  said (organize and smooth only, no invented content). Optional context hint in Settings.
- **New mode "Blitztext Translate" (`TranslateWorkflow`)** — records speech, transcribes
  it, then translates into a target language via Claude with grammar/structure cleanup so
  it reads naturally. Target language is selectable in Settings (English default, plus
  French, Italian, German). Default hotkey `fn + Control + Command`.
- **Configurable hotkeys** — each mode can be assigned an allowed `fn`-combination
  (or "Kein Hotkey") in Settings → Tastenkürzel. Conflicts are resolved automatically.
  Implemented via `HotkeyCombo` and a data-driven `HotkeyService`; menu/badges show the
  configured combo.
- **Anthropic API key field** in Settings, stored in the macOS Keychain alongside the
  OpenAI key.

### Changed
- **Rewriting now uses Claude (Anthropic Messages API)** instead of OpenAI Chat
  Completions. Affects Blitztext+, Blitztext $%&!, Blitztext :), and Blitztext Konzept.
  Models: `claude-haiku-4-5` (fast edits) and `claude-sonnet-4-6` (concept / rage mode).
- **Rewrite workflows respect the transcription backend** — they now transcribe locally
  (WhisperKit) when "Sicherer Lokaler Modus" is on, instead of always using OpenAI.
  With a local model + Anthropic key, no OpenAI key is required at all.
- Workflow availability/labels updated so rewrite modes also work in local mode
  (the previous "Im lokalen Modus pausiert" gating was removed).

### Fixed
- **Whisper end-of-clip hallucinations removed** — known phrases that Whisper appends on
  trailing silence (e.g. "Vielen Dank.", "Untertitel der Amara.org-Community", "Thank you.")
  are stripped from the raw transcript via `cleanedRawTranscript`. Applied only to the
  transcript, never to the LLM output, and never when the phrase is the entire utterance.
- **Auto-paste target resolution** — if no target app was captured at start (e.g. the
  popover had focus), the active app is now used at paste time, with retries until focus
  returns. Previously paste could abort silently (`target == nil`).
- **Clipboard no longer reverts to the previous content** after a paste. The recognized
  text stays on the clipboard so it can also be pasted manually with `Cmd+V`. Previously
  the old clipboard was restored ~1.5 s after paste, which made manual paste insert stale
  text.

### Notes
- The app remains ad-hoc signed for local development. Because TCC ties Microphone and
  Accessibility permissions to the code signature, both permissions must be re-granted
  after each rebuild that changes the binary.
