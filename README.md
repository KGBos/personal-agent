# PersonalAgent

**PersonalAgent** is a next-generation, multi-platform personal AI assistant built natively for macOS, iOS, and visionOS. It combines the power of LLMs (like OpenAI and Apple Intelligence) with deep system integration, allowing you to not just chat with AI, but have it actually *do* things for you—manage your calendar, send reminders, check the weather, and more.

## Features

- **Multi-Model Intelligence**: Switch seamlessly between OpenAI's GPT models and local Apple Foundation Models.
- **System Integration**:
  - **Calendar**: Create, view, and manage events.
  - **Reminders**: Set and check tasks.
  - **Contacts**: Look up contact information.
  - **Files**: Read and list files within the sandbox.
  - **System Control**: Execute shell commands and AppleScripts (macOS).
- **Rich Chat Interface**: Modern UI with Markdown support, code syntax highlighting, and streaming responses.
- **Privacy First**: Secure Keychain storage for API keys and granular permission controls for system access.
- **Cross-Platform**: Designed for macOS, iOS, and visionOS.

## Getting Started

### Prerequisites

- **Xcode 16.2+** (for macOS 26.2 / iOS 26.2 SDKs)
- **macOS 26.2+** (recommended for full development features)
- **OpenAI API Key** (optional, for OpenAI backend)

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/PersonalAgent.git
    cd PersonalAgent
    ```

2.  **Open in Xcode:**
    Double-click `PersonalAgent.xcodeproj`.

3.  **Build and Run:**
    - Select your target (My Mac, iPhone 16 Simulator, etc.).
    - Press `Cmd+R` to build and run.

### Configuration

On first launch, navigate to the **Settings** tab to:
1.  Enter your OpenAI API Key (if using OpenAI).
2.  Choose your default Model Provider.
3.  Configure default settings for tools (e.g., default calendar).

## Architecture for Developers

PersonalAgent follows a clean, modular **MVVM** architecture with **Swift 6 Strict Concurrency**.

### Core Structure

- **`Core/`**: Contains the foundational models (`Message`, `ToolCall`) and protocols (`AIService`, `AgentTool`).
- **`Services/AI/`**: implementations for AI backends.
    - `OpenAI/`: Handles network requests to OpenAI.
    - `Apple/`: Interfaces with local Apple Foundation Models.
- **`Services/Tools/`**: The heart of the agent's capabilities. Each tool (Calendar, Weather, etc.) implements the `AgentTool` protocol and is registered in the `ToolRegistry`.
- **`Data/`**: Manages persistence using **SwiftData** for conversation history and **Keychain** for secrets.
- **`Views/`**: Pure **SwiftUI** views for the interface.

### Key Patterns

- **Tool-Use First**: The system is designed around the concept of "Tools". The AI decides when to call a tool, and the app executes it locally and feeds the result back.
- **Streaming**: Responses are streamed via `AsyncThrowingStream` for a responsive UI.
- **Sandboxed Execution**: All tools run within the app's sandbox (except explicitly entitled system integrations).

## Roadmap

We have big plans for PersonalAgent. Here is where we are heading:

### 🚀 Upcoming Features
- **Deep Apple Intelligence**: Fuller integration with the latest Apple Intelligence capabilities as they evolve.
- **Voice Mode**: Speak to your agent naturally with real-time audio streaming.
- **Vision Support**: Drag and drop images for the agent to analyze.

### 🧪 Wild Ideas (The "Why Not?" List)
- **"Ghost" Mode**: An autonomous mode where the agent proactively checks your schedule and emails in the background to suggest actions before you even ask.
- **Desktop Automation**: Expanded AppleScript/Shortcut integration to control complex Mac workflows (e.g., "Organize my desktop screenshots into folders by date").
- **Plugin System**: A `.bundle` or Lua-based plugin system allowing the community to write their own tools.
- **Personality Engine**: Configurable "personas" that change not just the system prompt, but the UI theme and interaction style.

## License

This project is licensed under the **MIT License**.

```text
MIT License

Copyright (c) 2024 Leon

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
