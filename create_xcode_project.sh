#!/bin/bash

# Script to create Xcode project for ClaudeSynth Audio Unit
# This creates a minimal Xcode project structure

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Creating Xcode project structure for ClaudeSynth..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "ERROR: Xcode is not installed or xcode-select is pointing to Command Line Tools"
    echo "Please install Xcode from the Mac App Store and run:"
    echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

# Create project directory
mkdir -p ClaudeSynth.xcodeproj

# Generate a UUID for the project
PROJECT_UUID=$(uuidgen | tr -d '-')
TARGET_UUID=$(uuidgen | tr -d '-')
GROUP_UUID=$(uuidgen | tr -d '-')
BUILDPHASE_UUID=$(uuidgen | tr -d '-')
BUILDCONFIG_DEBUG_UUID=$(uuidgen | tr -d '-')
BUILDCONFIG_RELEASE_UUID=$(uuidgen | tr -d '-')
BUILDCONFIGLIST_PROJECT_UUID=$(uuidgen | tr -d '-')
BUILDCONFIGLIST_TARGET_UUID=$(uuidgen | tr -d '-')

echo "Project structure created. You'll need to open Xcode to complete setup."
echo ""
echo "IMPORTANT: Full Xcode installation required!"
echo ""
echo "Next steps:"
echo "1. If you don't have Xcode, install it from the Mac App Store"
echo "2. Open Xcode and create a new project:"
echo "   - File → New → Project"
echo "   - macOS → Bundle"
echo "   - Product Name: ClaudeSynth"
echo "   - Save in this directory (replace if needed)"
echo "3. Add source files from Source/ folder to the project"
echo "4. Configure build settings as described in BUILDING.md"
echo ""
echo "Or follow the detailed instructions in BUILDING.md"
