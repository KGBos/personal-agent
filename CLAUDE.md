# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PersonalAgent is a Personal AI Agent app - a multi-platform Swift application (iOS, macOS, visionOS) that allows users to chat with AI and have it take actions on their behalf using tool/function calls.

- **Bundle ID**: `com.kgbos.PersonalAgent`
- **Deployment Targets**: iOS 26.2, macOS 26.2, visionOS 26.2
- **AI Backends**: OpenAI API (implemented), Apple Foundation Models (planned)

## Build & Development Commands

### Building
- **Xcode**: Open `PersonalAgent.xcodeproj` and press Cmd+B
- **CLI**: `xcodebuild -project PersonalAgent.xcodeproj -scheme PersonalAgent -configuration Debug build`

### Running
- **Xcode**: Press Cmd+R to run on selected simulator/device
- **macOS**: `xcodebuild -project PersonalAgent.xcodeproj -scheme PersonalAgent -destination 'platform=macOS' run`

### Cleaning
- **Xcode**: Cmd+Shift+K (Clean Build Folder)
- **CLI**: `xcodebuild clean -project PersonalAgent.xcodeproj -scheme PersonalAgent`

## Architecture & Code Structure

### Project Layout
````
PersonalAgent/
├── Core/
│   ├── Models/          # Message, AIProvider, ToolCall, AnyCodable
│   ├── Protocols/       # AIService protocol
│   └── Errors/          # AIError
├── Services/
│   └── AI/
│       ├── OpenAI/      # OpenAIService implementation
│       └── AIServiceFactory.swift
├── ViewModels/          # ChatViewModel
├── Views/
│   ├── Chat/            # ChatView, MessageBubble, MessageInput
│   ├── Settings/        # SettingsView
│   └── Components/      # ErrorBanner, shared components
├── Data/
│   └── Settings/        # SettingsManager, SecureStorage (Keychain)
└── PersonalAgentApp.swift
```

### Key Abstractions

**AIService Protocol** (`Core/Protocols/AIService.swift`):
- `complete()` - Non-streaming completion
- `stream()` - Returns `AsyncThrowingStream<StreamingChunk, Error>` for streaming

**Message Model** (`Core/Models/Message.swift`):
- Supports text, tool calls, and tool results
- `MessageRole`: system, user, assistant, tool

### Architecture Patterns
- **MVVM**: ViewModels with `@Observable` for state
- **Protocol-based AI layer**: `AIService` protocol for swappable backends
- **Actor-based services**: OpenAIService uses `actor` for concurrency safety
- **Streaming-first**: Real-time response streaming with SSE parsing

### Dependencies & Storage
- **API Keys**: Stored in Keychain via `SecureStorage`
- **Settings**: UserDefaults via `SettingsManager`
- **No external dependencies**: Pure Swift/SwiftUI

### Security & Runtime
- **App Sandboxing**: Enabled
- **Network Access**: Entitlement for OpenAI API calls
- **Strict Concurrency**: Swift 6 strict checking enabled

## Adding New AI Providers

1. Create new service in `Services/AI/{Provider}/`
2. Implement `AIService` protocol
3. Add case to `AIProvider` enum
4. Update `AIServiceFactory.createService()`

## Implementation Status

- **Phase 1**: Foundation (COMPLETE) - Core models, OpenAI streaming, Chat UI
- **Phase 2**: Persistence (COMPLETE) - SwiftData, conversation sidebar
- **Phase 3**: Tool Framework (NEXT)
- **Phase 4**: Full Tool Suite (PENDING)
- **Phase 5**: Apple Foundation Models (PENDING)

## Continuing Development

(References to HANDOFF.md have been removed — HANDOFF.md is deprecated.)

## Adding New Tools

1. Create tool in `Services/Tools/{Category}/`
2. Implement `AgentTool` protocol
3. Register in `ToolRegistry.registerDefaults()`
4. Add required entitlements/permissions
