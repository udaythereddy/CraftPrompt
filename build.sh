#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "====================================================="
echo "  CraftPrompt Native macOS Build & Packaging Script   "
echo "====================================================="

# 1. Check dependencies
if ! command -v cargo &> /dev/null; then
    if [ -f "$HOME/.cargo/bin/cargo" ]; then
        export PATH="$HOME/.cargo/bin:$PATH"
    else
        echo "Error: Rust/Cargo is not installed or not in PATH."
        exit 1
    fi
fi

if ! command -v swiftc &> /dev/null; then
    echo "Error: swiftc is not installed or not in PATH."
    exit 1
fi

# 2. Build PhotoCraft release binary
echo "==> Building photocraft-cli (Rust release binary)..."
cargo build --release --manifest-path photocraft/Cargo.toml -p photocraft-cli

# 3. Build CraftPrompt native macOS executable
echo "==> Compiling CraftPrompt native Swift/SwiftUI application..."
mkdir -p /tmp/clang-cache
swiftc -Xcc -fmodules-cache-path=/tmp/clang-cache \
       -module-cache-path /tmp/clang-cache \
       -parse-as-library \
       $(find CraftPrompt/Sources/CraftPrompt -name "*.swift") \
       -o CraftPrompt/CraftPrompt

# 4. Assemble macOS .app bundle
echo "==> Assembling CraftPrompt.app bundle..."
mkdir -p CraftPrompt.app/Contents/MacOS CraftPrompt.app/Contents/Resources
cp CraftPrompt/CraftPrompt CraftPrompt.app/Contents/MacOS/CraftPrompt
cp CraftPrompt/Info.plist CraftPrompt.app/Contents/Info.plist
cp photocraft/target/release/photocraft-cli CraftPrompt.app/Contents/Resources/photocraft-cli
chmod +x CraftPrompt.app/Contents/MacOS/CraftPrompt CraftPrompt.app/Contents/Resources/photocraft-cli

# 5. Codesign with entitlements
echo "==> Codesigning CraftPrompt.app with App Sandbox entitlements..."
codesign --force --deep --sign - --entitlements CraftPrompt/CraftPrompt.entitlements CraftPrompt.app

echo "====================================================="
echo "  Build Complete! CraftPrompt.app is ready to launch."
echo "====================================================="
