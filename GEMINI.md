# GEMINI.md

This file provides guidance to Gemini (Antigravity) when working with the PersonalAgent codebase.

## System Details
- **macOS**: 26.2 on Apple Silicon
- **Xcode**: 26.2
- **Swift**: 6.2.3

## Project Overview
PersonalAgent is a multi-platform Swift application (iOS, macOS, visionOS) built with SwiftUI. It emphasizes modern declarative UI patterns and leverages the latest features of Swift 6.

- **Bundle ID**: `com.leon.PersonalAgent`
- **Deployment Targets**: iOS 26.2, macOS 26.2, visionOS 26.2
- **Core Technologies**: SwiftUI, Swift Concurrency
- **Development Status**: Initial setup / Starter project

## Build & Development Commands

### Common Tasks
- **Build**: `xcodebuild -project PersonalAgent.xcodeproj -scheme PersonalAgent -configuration Debug build`
- **Run (macOS)**: `xcodebuild -project PersonalAgent.xcodeproj -scheme PersonalAgent -destination 'platform=macOS' run`
- **Run (iOS Simulator)**: `xcodebuild -project PersonalAgent.xcodeproj -scheme PersonalAgent -destination 'platform=iOS Simulator,name=iPhone 16' run`
- **Clean**: `xcodebuild clean -project PersonalAgent.xcodeproj -scheme PersonalAgent`

## Architecture & Coding Standards

### Structure
- **Entry Point**: `PersonalAgent/PersonalAgentApp.swift`
- **Root View**: `PersonalAgent/ContentView.swift`
- **Assets**: `PersonalAgent/Assets.xcassets/`

### Principles
- **Swift 6 Concurrency**: Strict concurrency checking is enabled. Always use `async/await`, `Task`, and actors where appropriate.
- **SwiftUI First**: All UI should be implemented using SwiftUI. Avoid UIKit/AppKit unless absolutely necessary.
- **Preview Everything**: Use `#Preview` macros for all views to enable rapid iteration.
- **MVVM Pattern**: As complexity increases, separate state and logic into ViewModels.
- **Clean Code**: Prioritize readability and follow standard Swift naming conventions (camelCase, descriptive names).
- **No Dependencies**: Currently, the project aims to have zero external dependencies to keep it lightweight.

## Gemini Guidelines
- Be proactive in suggesting improvements to SwiftUI layouts.
- Always check for concurrency warnings/errors when modifying logic.
- Ensure all new views include a corresponding `#Preview`.
- When adding features, consider how they translate across iOS, macOS, and visionOS.

