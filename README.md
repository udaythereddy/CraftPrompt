<p align="center">
  <img src="CraftPrompt/Resources/AppIcon_1024.png" width="140" alt="CraftPrompt macOS App Icon" />
</p>

# CraftPrompt 🎨✨

**CraftPrompt** is a native macOS desktop application built in Swift and SwiftUI that enables users to edit images using natural language text prompts. The core editing backend runs entirely locally on your laptop by interfacing directly with the open-source Rust project [`storytold/photocraft`](https://github.com/storytold/photocraft).

---

## Key Highlights

- **100% Native macOS Application:** Built with Swift and SwiftUI targeting macOS 14+ and macOS 15+. Adheres strictly to the Apple Human Interface Guidelines with translucent sidebars, unified toolbars, native split views, SF Symbols, and smooth spring animations. Absolutely no web wrappers, Electron, or browser windows.
- **Local Rust Backend Integration:** Communicates with `photocraft-cli` via its headless automation server (`serve`) over non-blocking standard input/output pipes. Dispatches engine commands (`crates/engine`) for non-destructive adjustment layers, precision raster filters, and layer management.
- **Natural Language Translation Layer:** Translates colloquial requests (e.g., *"warm up the sunset, boost vibrance, and blur out the distracting background"*) into deterministic PhotoCraft command sequences.
- **Conversational Refinement:** Refines edits across conversational turns (e.g., *"make it stronger"* amplifies adjustments by +40%; *"tone it down"* subdues intensity by -40%).
- **Native Undo / Redo:** Routes conversational undo (*"undo that"*, *"revert"*) and redo requests straight into PhotoCraft's native history stack.
- **Before/After Split Comparison:** Real-time interactive split slider over the canvas for instant before/after visual inspection.
- **Inspector Drawer:** Collapsible sidebar with active layers, opacity controls, blend mode badges, visibility toggles, and step-by-step history timeline.
- **Import / Export:** Native drag-and-drop for PNG, JPG, TIFF, PSD, WebP, EXR, and `.pcraft`, paired with a custom macOS "Export As..." dialog supporting JPEG quality controls and TIFF layer preservation.

---

## Architecture

```
CraftPrompt (Native macOS Frontend - Swift / SwiftUI)
   ├── Main Viewport (CanvasViewportView: Pinch-to-zoom, Pan, Split Slider)
   ├── Floating Prompt Bar (FloatingPromptBar: Status Pill, Suggestion Chips)
   ├── Inspector Drawer (InspectorDrawer: Layers Panel, History Timeline)
   │
   ▼
Natural Language Translation Layer (PromptTranslator.swift)
   ├── Semantic Clause Decomposer
   ├── Conversational Refinement & History Routing
   └── Schema Validator & Parameter Bounding (ParameterValidator.swift)
   │
   ▼
Swift-PhotoCraft Process Bridge (PhotocraftClient.swift / PhotocraftProcess.swift)
   ├── Async FileHandle Readability Handlers (Non-Blocking)
   ├── Capability-Scoped Sandbox Roots (--automation-read-root / --write-root)
   │
   ▼
PhotoCraft Local Engine (storytold/photocraft - Rust)
   ├── photocraft-cli serve (JSON-RPC over stdio)
   ├── crates/engine (Adjustment Layers, Curves, Levels, Filters)
   └── Native History Stack (Undo / Redo)
```

---

## Quick Start & Build Instructions

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0 (Sequoia)
- Xcode 15+ / Command Line Tools with Swift 5.9+ / Swift 6
- Rust toolchain (`cargo`, `rustc`): `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

### 1. Clone the Repository
```bash
git clone --recurse-submodules https://github.com/udaythereddy/CraftPrompt.git
cd CraftPrompt
```

### 2. Build and Package CraftPrompt.app
Run the automated build script:
```bash
./build.sh
```

This will:
1. Compile `storytold/photocraft` into release binary `photocraft-cli`.
2. Compile the native Swift application sources with module caching.
3. Assemble the macOS `CraftPrompt.app` bundle with embedded resources.
4. Sign the app with `CraftPrompt.entitlements` (App Sandbox).

### 3. Launch the App
```bash
open CraftPrompt.app
```

---

## Running the Automated Test Suite

To run all 28 automated security, parameter validation, translation, and live engine integration tests:

```bash
export MACOSX_DEPLOYMENT_TARGET=14.0
swiftc -target arm64-apple-macosx14.0 \
       -Xcc -fmodules-cache-path=/tmp/clang-cache \
       -module-cache-path /tmp/clang-cache \
       CraftPrompt/Sources/CraftPrompt/Model/CommandModels.swift \
       CraftPrompt/Sources/CraftPrompt/Model/LayerInfo.swift \
       CraftPrompt/Sources/CraftPrompt/Model/HistoryStep.swift \
       CraftPrompt/Sources/CraftPrompt/Security/PathSanitizer.swift \
       CraftPrompt/Sources/CraftPrompt/Security/ParameterValidator.swift \
       CraftPrompt/Sources/CraftPrompt/Security/SecurityAuditor.swift \
       CraftPrompt/Sources/CraftPrompt/Engine/PhotocraftProcess.swift \
       CraftPrompt/Sources/CraftPrompt/Engine/PhotocraftClient.swift \
       CraftPrompt/Sources/CraftPrompt/Translator/CommandCatalog.swift \
       CraftPrompt/Sources/CraftPrompt/Translator/ToolSchemaRegistry.swift \
       CraftPrompt/Sources/CraftPrompt/Translator/PromptTranslator.swift \
       CraftPrompt/Tests/RunTests.swift \
       -o /tmp/craftprompt_tests && /tmp/craftprompt_tests
```

---

## Security & Safety Audit Summary

| Security Domain | Defense & Mitigation | Test Status |
| :--- | :--- | :---: |
| **Path Traversal Defense** | `PathSanitizer` rejects all relative path escapes (`../../`) and traps unauthorized filesystem traversal attempts. | **PASSED** |
| **Command Injection Defense** | All user inputs are sanitized against shell metacharacters (`;`, `\|`, `` ` ``, `$`). Subprocesses are spawned directly without shell wrappers. | **PASSED** |
| **Input Poisoning Defense** | Traps and denies null-byte string poisoning (`\0`). | **PASSED** |
| **Parameter Validation** | Bounds all filter radii, adjustment values, curves, and levels against PhotoCraft's schema to prevent memory exhaustion and engine panics. | **PASSED** |
| **macOS Sandboxing** | Configured with least-privilege App Sandbox entitlements (`com.apple.security.app-sandbox`, user-selected read/write). | **PASSED** |
| **Local Data Privacy** | 100% on-device execution. Pixel data remains in local memory and Unix pipes; no image bytes are transmitted externally. | **PASSED** |

---

## License

CraftPrompt is licensed under the Apache 2.0 / MIT license. The core editing backend incorporates [PhotoCraft](https://github.com/storytold/photocraft).
