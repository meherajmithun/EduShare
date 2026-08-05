#!/bin/bash
set -e

OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
    # ── macOS ──────────────────────────────────────────────────────────────────
    BREW_FLUTTER="/opt/homebrew/share/flutter"   # arm64 Homebrew location
    BREW_FLUTTER_INTEL="/usr/local/share/flutter" # Intel Homebrew fallback

    echo "Detected macOS. Checking Flutter SDK installation..."

    if [ -d "$BREW_FLUTTER/bin" ]; then
        export PATH="$BREW_FLUTTER/bin:$PATH"
        echo "Flutter SDK found at $BREW_FLUTTER"
    elif [ -d "$BREW_FLUTTER_INTEL/bin" ]; then
        export PATH="$BREW_FLUTTER_INTEL/bin:$PATH"
        echo "Flutter SDK found at $BREW_FLUTTER_INTEL"
    else
        echo "Flutter SDK not found. Installing via Homebrew..."
        if ! command -v brew &>/dev/null; then
            echo "ERROR: Homebrew is not installed. Install it from https://brew.sh and re-run."
            exit 1
        fi
        brew install --cask flutter
        export PATH="$BREW_FLUTTER/bin:$PATH"
        echo "Flutter installed via Homebrew."
    fi

else
    # ── Linux ──────────────────────────────────────────────────────────────────
    SDK_DIR="$HOME/flutter"
    DOWNLOAD_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.8-stable.tar.xz"
    DOWNLOAD_DEST="$HOME/Downloads/flutter_linux_stable.tar.xz"

    echo "Detected Linux. Checking Flutter SDK installation..."

    if [ -d "$SDK_DIR/bin" ]; then
        echo "Flutter SDK is already installed in $SDK_DIR"
    else
        echo "Flutter SDK not found. Preparing download..."
        mkdir -p "$HOME/Downloads"

        if [ ! -f "$DOWNLOAD_DEST" ]; then
            echo "Downloading Flutter SDK..."
            curl -L -o "$DOWNLOAD_DEST" "$DOWNLOAD_URL"
        else
            echo "Found existing download archive."
        fi

        echo "Extracting Flutter SDK to $HOME/..."
        tar -xf "$DOWNLOAD_DEST" -C "$HOME"
        echo "Extraction complete."
    fi

    export PATH="$SDK_DIR/bin:$PATH"
fi

echo ""
echo "Verifying Flutter SDK version..."
flutter --version

echo ""
echo "Flutter SDK Setup finished successfully!"
