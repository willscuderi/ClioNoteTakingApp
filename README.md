# Clio — AI Meeting Notes for Mac

Clio is a native macOS app that transcribes your meetings in real time and generates AI-powered summaries, notes, and action items. It runs locally on your Mac, supports multiple AI providers, and integrates with your calendar to detect meetings automatically.

## Download

**[Download Clio v0.2.0](https://github.com/willscuderi/ClioNoteTakingApp/releases/latest)** — Unzip and drag to Applications. No Xcode required.

> **Note:** This build is ad-hoc signed (not notarised). On first launch, right-click the app and choose **Open** to bypass Gatekeeper.

Clio auto-updates via [Sparkle](https://sparkle-project.org/) — once installed, you'll be notified when new versions are available.

## Features

- **Real-time transcription** — Captures system audio and microphone simultaneously, transcribes live using local [whisper.cpp](https://github.com/ggml-org/whisper.cpp), OpenAI Whisper API, or AssemblyAI
- **Speaker diarization** — Identifies different speakers in recordings using [AssemblyAI](https://www.assemblyai.com). Ideal for podcasts, interviews, and multi-participant meetings. Speakers are labelled (Speaker A, Speaker B, etc.) with colour-coded transcript segments
- **Per-meeting AI chat** — Ask questions about a specific meeting directly from the meeting detail view. An inline chat bar at the bottom of each completed meeting lets you query its transcript and summary
- **AI-powered notes** — Generates summaries, key decisions, and action items via OpenAI, Claude, Gemini, or local Ollama models
- **Streaming summaries** — AI-generated summaries stream in progressively as they're written, so you can start reading immediately
- **Unified search bar** — A single search bar in the toolbar toggles between keyword search (filters meeting list in real time) and AI search (asks questions across all your meetings)
- **Smart meeting detection** — Detects when you join a Zoom, Teams, Meet, or Webex call by monitoring microphone activity (not just app launch), and prompts you to start recording with a floating overlay
- **Calendar integration** — Reads upcoming meetings from macOS Calendar (Google, Outlook, iCloud) and shows them in the sidebar
- **Crash recovery** — If Clio or your Mac restarts unexpectedly during a recording, the meeting is automatically recovered on next launch with all segments intact
- **Multiple export options** — Export notes to Apple Notes, Notion, Obsidian, OneNote, or Markdown files. Notion exports include a direct link to open the page, with automatic retry on transient errors
- **Markdown notes editor** — Rich formatting toolbar with headings, bold, italic, bullet lists, and checkboxes for meeting notes
- **Folder organisation** — Group and organise meeting recordings into folders with drag-and-drop support
- **Menu bar app** — Quick-access recording controls from the menu bar
- **Bookmarks** — Mark key moments during a meeting for quick reference
- **Global hotkeys** — Start/stop recording and create bookmarks from anywhere
- **Audio watchdog** — Monitors the audio pipeline during recording and warns you if no audio is detected for more than 10 seconds
- **Auto-updates** — Checks for new versions daily via Sparkle

## Requirements

- macOS 14 Sonoma or later
- An API key for at least one AI provider (OpenAI, Anthropic, or Google), **or** Ollama installed locally

### No API Key? Use Ollama

[Ollama](https://ollama.com) runs AI models entirely on your Mac — no API key, no cloud account, no cost. During Clio's setup, select **Ollama** and click **Install** — Clio will install it for you via Homebrew in Terminal. Or install it manually:

```bash
brew install ollama
ollama serve &
ollama pull llama3.2
```

## Supported AI Providers

| Provider | What you need |
|---|---|
| OpenAI | API key — used for GPT summarisation and/or Whisper transcription |
| Anthropic (Claude) | API key — used for summarisation and AI Search |
| Google (Gemini) | API key — used for summarisation and AI Search |
| AssemblyAI | API key — used for transcription with speaker diarization |
| Ollama | Local install — free, no API key needed. Clio can install it for you |

## Export Destinations

| Destination | How it works |
|---|---|
| Markdown | Save `.md` file anywhere via save panel |
| Apple Notes | Creates a note directly in Apple Notes |
| Notion | Creates a page via Notion API — shows "Open in Notion" link |
| Obsidian | Writes `.md` file to your vault's `Clio Meeting Notes` folder |
| OneNote | Opens formatted meeting notes in Microsoft OneNote |

## Meeting Detection

Clio detects meetings by monitoring your Mac's microphone at the system level. When the mic becomes active and a meeting app is running (Zoom, Teams, Webex, GoToMeeting, or a browser for Google Meet), a floating overlay appears asking if you'd like to start recording. This works even when Clio is minimised.

## Permissions

Clio requests the following system permissions on first launch:

| Permission | Why |
|---|---|
| Microphone | Capture your voice during meetings |
| Screen Recording | Capture system audio from meeting apps |
| Calendar | Show upcoming meetings and match recordings to events |
| Automation (Apple Notes) | Export meeting notes to Apple Notes |

## Build from Source

If you want to build Clio yourself instead of using the pre-built download:

```bash
# 1. Clone the repo
git clone https://github.com/willscuderi/ClioNoteTakingApp.git
cd ClioNoteTakingApp

# 2. Install XcodeGen if you don't have it
brew install xcodegen

# 3. Download the whisper model (optional, for local transcription)
curl -L -o Clio/Resources/Models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin

# 4. Generate the Xcode project and build
xcodegen generate
xcodebuild build -scheme Clio -destination "platform=macOS" -project Clio.xcodeproj

# Or open in Xcode
open Clio.xcodeproj
```

**Build requirements:** Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), macOS 14+

## Architecture

Clio is built with Swift, SwiftUI, and SwiftData. The only external dependency is [Sparkle](https://sparkle-project.org/) for auto-updates (pulled via SPM).

```
Clio/
├── Models/              # SwiftData models (Meeting, TranscriptSegment, Bookmark, MeetingFolder)
├── Services/
│   ├── Audio/           # System audio + mic capture, mixing, buffering
│   ├── Calendar/        # EventKit integration, meeting app detection
│   ├── Export/          # Markdown, Apple Notes, Notion, Obsidian, OneNote exporters
│   ├── LLM/            # OpenAI, Claude, Gemini, Ollama providers + streaming
│   ├── Transcription/  # Local whisper.cpp, OpenAI Whisper API, AssemblyAI (diarization)
│   ├── Recovery/       # Crash recovery service
│   └── Protocols/      # Service protocol definitions
├── ViewModels/          # MVVM view models (Recording, MeetingDetail, AISearch, MeetingChat, Transcript)
├── Views/
│   ├── Main/           # Sidebar, content, transcript/summary/notes tabs, AI Search
│   ├── Recording/      # Floating indicators, meeting detection panel
│   ├── MenuBar/        # Menu bar extra
│   ├── Settings/       # Preferences (API keys, audio, general)
│   ├── Onboarding/     # First-launch setup with Ollama install
│   └── Components/     # Reusable UI (ProviderModelButton, MeetingChatBar, UnifiedSearchBar, MarkdownNotesEditor)
├── Utilities/          # ServiceContainer (DI), helpers
└── Resources/          # Whisper model, assets
```

All services are protocol-based and wired through a `ServiceContainer` injected via SwiftUI's environment. The audio pipeline flows: `AudioCaptureCoordinator` → `AudioMixer` → `AudioBufferManager` → chunks → `TranscriptionCoordinator`.

## License

GPL-3.0. See [LICENSE](LICENSE) for details.
