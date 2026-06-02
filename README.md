# Blitztext App

Blitztext App is an experimental open-source macOS menubar app for turning speech into text.

It is intentionally small and unfinished. The goal is to make a real workflow visible and hackable: press a hotkey, speak, get text back, optionally rewrite it, and paste it into the app you were using.

This is a learning and experimentation project, not a polished product.

> Preview status: bring your own API key(s), no hosted backend, no warranty, no support guarantee.

## Changes in This Fork

This fork (maintained by Atelier 26) adapts the original preview for a fully local transcription + Claude rewriting workflow. See [CHANGELOG.md](CHANGELOG.md) for details. Highlights:

- **Rewriting runs on Claude (Anthropic) instead of OpenAI.** All text workflows (Blitztext+, $%&!, :), and the new Konzept mode) call the Anthropic Messages API.
- **New mode "Blitztext Konzept"** — turns free, rambling speech into a clean, structured concept (title, grouped paragraphs, `–` bullet lists). Stays close to what was said; only organizes and smooths.
- **Configurable hotkeys** — assign any allowed `fn`-combo (or none) to each mode in Settings → Tastenkürzel.
- **Transcription can be fully local** (WhisperKit/CoreML) so no OpenAI key is needed; OpenAI stays optional for online Whisper.
- **Paste fixes** — the recognized text is reliably pasted into the active app and stays on the clipboard for manual `Cmd+V`.

## What It Does

- **Blitztext**: record speech and transcribe it.
- **Blitztext+**: record speech, transcribe it, then turn the rough draft into cleaner writing.
- **Blitztext $%&!**: turn frustrated speech into a calmer message.
- **Blitztext :)**: add fitting emojis to dictated text.
- **Blitztext Konzept**: turn free-form, rambling speech into a structured concept (title, paragraphs, bullet points).

## Important Preview Notes

- macOS only.
- Bring your own API key(s): an **Anthropic** key for rewriting, and optionally an **OpenAI** key for online Whisper transcription.
- No hosted Blitztext backend is included or provided.
- In online mode, audio/text are sent directly from the app to the provider API (OpenAI for transcription, Anthropic for rewriting).
- Transcription can run fully local via WhisperKit/CoreML if you install a compatible model — then no OpenAI key is needed.
- `./build.sh` creates a locally ad-hoc-signed development app. No notarized release binary is provided.
- Not production ready.
- No warranty and no support guarantee.

You are welcome to use, fork, adapt, and share this project under the license terms.

The intent is not to ship a one-click finished app. The intent is to make a real AI workflow understandable: clone it, build it, read the code, change it, break it, fix it, and suggest improvements. If you only want to download something and never look inside, this preview will probably feel rough. If you want to learn how a small native macOS AI app is put together, you are in the right place.

## Screenshots

<table>
  <tr>
    <td><img src="docs/screenshots/online-mode.png" alt="Blitztext online transcription mode" width="420"></td>
    <td><img src="docs/screenshots/local-mode.png" alt="Blitztext secure local transcription mode" width="420"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/local-model-picker.png" alt="Blitztext local model picker" width="420"></td>
    <td><img src="docs/screenshots/settings-customize.png" alt="Blitztext settings and customization view" width="420"></td>
  </tr>
</table>

## Requirements

- macOS 14 or newer
- Xcode 16 or newer (Swift 5.10), with Command Line Tools installed and selected for `xcodebuild`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project
- For rewriting (Blitztext+, $%&!, :), Konzept): an **Anthropic API key** with access to Claude models (`claude-haiku-4-5`, `claude-sonnet-4-6`).
- For online transcription (optional): an **OpenAI API key** with access to `whisper-1`.
- For local-only transcription (recommended, no OpenAI key needed): a WhisperKit CoreML model in:
  `~/Library/Application Support/Blitztext/models/whisperkit/`

The build also pulls one Swift Package dependency automatically:

- [`argmax-oss-swift`](https://github.com/argmaxinc/argmax-oss-swift) (WhisperKit) — used for local on-device transcription.

Install XcodeGen if needed:

```bash
brew install xcodegen
```

## Build And Run

```bash
git clone https://github.com/cmagnussen/blitztext-app.git
cd blitztext-app
./build.sh --run
```

For a local install into `/Applications`:

```bash
./build.sh --install --run
```

The generated `.app` is ad-hoc signed for local development only. Do not treat it as a trusted redistributable binary. A public binary release would need Developer ID signing and notarization.

On first launch, paste your **Anthropic API key** (Settings → Anthropic API Key) so the rewriting workflows work. For transcription, either install a WhisperKit CoreML model for local mode, or add an OpenAI key for online Whisper.

For fully local transcription, install a WhisperKit CoreML model and enable **Sicherer Lokaler Modus** in the app. Combined with the Anthropic key, this needs no OpenAI key at all.

For a slower, more explicit walkthrough, see [docs/setup.md](docs/setup.md).

## Permissions

Blitztext asks for:

- **Microphone**: to record your voice.
- **Accessibility**: to paste the result back into the app you were using.

If you do not grant Accessibility permission, you can still copy results manually.

Full Disk Access is not required. If auto-paste does not work even though transcription succeeds, open **System Settings -> Privacy & Security -> Accessibility**, enable Blitztext there, restart Blitztext, and try again with the cursor focused in a text field. If macOS shows multiple Blitztext entries, remove or disable the old ones and grant the permission to the app you just built or installed.

## Data Flow

The preview has no custom backend.

```text
Online transcription: Your Mac -> OpenAI Audio Transcriptions API
Text rewriting:       Your Mac -> Anthropic Messages API (Claude)
Local transcription:  Your Mac -> WhisperKit/CoreML on device
```

The app stores your API keys (OpenAI and/or Anthropic) in the user's macOS Keychain.

Read [docs/privacy.md](docs/privacy.md) before using the preview with sensitive content.

## Project Structure

```text
BlitztextMac/
  App/          App lifecycle and paste handling
  Features/     Workflows, menu bar UI, settings
  Services/     Recording, OpenAI/Anthropic calls, hotkeys, local storage
  Views/        Shared SwiftUI views
build.sh        Local build script
docs/           Setup, privacy, roadmap, preflight, landing page notes
```

## Local Models

Local transcription is available as an experimental WhisperKit/CoreML path. The app does not bundle a model; choose one in the app, click install, and then switch on **Sicherer Lokaler Modus** from the menu bar or settings.

See [docs/local-models.md](docs/local-models.md).

## Contributing

Contributions are welcome, especially if they make the preview easier to build, understand, or fork.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## Support And Roadmap

This preview has no formal support promise. See [SUPPORT.md](SUPPORT.md) for how to ask for help without sharing secrets.

The current direction is documented in [ROADMAP.md](ROADMAP.md). Maintainer-facing release checks live in [docs/open-source-preflight.md](docs/open-source-preflight.md).

## License

Code is released under the MIT License. See [LICENSE](LICENSE).

Project names, logos, and app icons are not automatically granted as trademarks or brand assets. See [TRADEMARKS.md](TRADEMARKS.md).

## Legal / Impressum & Datenschutz

This is an experimental, non-commercial open-source project, provided as-is under the MIT License without warranty or support. Nothing is sold here and no installation or operation is performed on your behalf.

The companion website (blitztext.de) is operated by Blackboat Internet GmbH:

- Impressum: https://www.blackboat.com/impressum
- Datenschutz / Privacy: https://www.blackboat.com/datenschutz
