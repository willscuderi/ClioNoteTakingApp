# Clio — AI Meeting Notes for Mac

Clio is a native macOS app that transcribes your meetings in real time and generates AI-powered summaries, notes, and action items. It runs locally on your Mac, supports multiple AI providers, and integrates with your calendar to detect meetings automatically.

## Features

- **Real-time transcription** — Captures system audio and microphone simultaneously, transcribes live using local [whisper.cpp](https://github.com/ggml-org/whisper.cpp) or OpenAI Whisper API
- **AI-powered notes** — Generates summaries, key decisions, and action items via OpenAI, Claude, Gemini, or local Ollama models
- **Smart meeting detection** — Detects when you join a Zoom, Teams, Meet, or Webex call by monitoring microphone activity (not just app launch), and prompts you to start recording with a floating overlay
- **Calendar integration** — Reads upcoming meetings from macOS Calendar (Google, Outlook, iCloud) and shows them in the sidebar
- **Multiple export options** — Export notes to Apple Notes, Notion, or Markdown files
- **Menu bar app** — Quick-access recording controls from the menu bar
- **Folder organisation** — Group and organise meeting recordings into folders
- **Bookmarks** — Mark key moments during a meeting for quick reference
- **Global hotkeys** — Start/stop recording and create bookmarks from anywhere

## Requirements

- macOS 14 Sonoma or later
- Xcode 16+ (to build)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An API key for at least one AI provider (OpenAI, Anthropic, or Google), or a local Ollama instance

### Whisper Model

The local transcription engine requires the whisper.cpp base English model (`ggml-base.en.bin`, ~141 MB). It's too large for Git so you'll need to download it:

```bash
# Download into the Resources/Models directory
curl -L -o Clio/Resources/Models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
```

Alternatively, you can skip local transcription and use the OpenAI Whisper API instead (requires an API key).

## Build & Run

```bash
# 1. Clone the repo
git clone https://github.com/willscuderi/ClioNoteTakingApp.git
cd ClioNoteTakingApp

# 2. Download the whisper model (optional, for local transcription)
curl -L -o Clio/Resources/Models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin

# 3. Generate the Xcode project
xcodegen generate

# 4. Build
xcodebuild build -scheme Clio -destination "platform=macOS" -project Clio.xcodeproj

# Or open in Xcode
open Clio.xcodeproj
```

## Architecture

Clio is built with Swift, SwiftUI, and SwiftData — no third-party dependencies beyond whisper.cpp.

```
Clio/
├── Models/              # SwiftData models (Meeting, TranscriptSegment, Bookmark, MeetingFolder)
├── Services/
│   ├── Audio/           # System audio + mic capture, mixing, buffering
│   ├── Calendar/        # EventKit integration, meeting app detection
│   ├── Export/          # Markdown, Apple Notes, Notion exporters
│   ├── LLM/            # OpenAI, Claude, Gemini, Ollama providers
│   ├── Transcription/  # Local whisper.cpp + OpenAI Whisper API
│   └── Protocols/      # Service protocol definitions
├── ViewModels/          # MVVM view models
├── Views/
│   ├── Main/           # Sidebar, content, transcript/summary/notes tabs
│   ├── Recording/      # Floating indicators, meeting detection panel
│   ├── MenuBar/        # Menu bar extra
│   ├── Settings/       # Preferences (API keys, audio, general)
│   ├── Onboarding/     # First-launch setup
│   └── Components/     # Reusable UI components
├── Utilities/          # ServiceContainer (DI), helpers
└── Resources/          # Whisper model, assets
```

All services are protocol-based and wired through a `ServiceContainer` injected via SwiftUI's environment. The audio pipeline flows: `AudioCaptureCoordinator` → `AudioMixer` → `AudioBufferManager` → chunks → `TranscriptionCoordinator`.

## Permissions

Clio requests the following system permissions on first launch:

| Permission | Why |
|---|---|
| Microphone | Capture your voice during meetings |
| Screen Recording | Capture system audio from meeting apps |
| Calendar | Show upcoming meetings and match recordings to events |
| Automation (Apple Notes) | Export meeting notes to Apple Notes |

## Configuration

On first launch, the onboarding flow walks you through granting permissions and entering API keys. You can change these at any time in **Clio → Settings**.

**Supported AI providers:**

| Provider | What you need |
|---|---|
| OpenAI | API key — used for GPT summarisation and/or Whisper transcription |
| Anthropic (Claude) | API key — used for summarisation |
| Google (Gemini) | API key — used for summarisation |
| Ollama | Local install at `http://localhost:11434` — no API key needed |

## Meeting Detection

Clio detects meetings by monitoring your Mac's microphone at the system level. When the mic becomes active and a meeting app is running (Zoom, Teams, Webex, GoToMeeting, or a browser for Google Meet), a floating overlay appears asking if you'd like to start recording. This works even when Clio is minimised.

## License

GPL-3.0. See [LICENSE](LICENSE) for details.
