# ClaudeSynth - Audio Unit Synthesizer

A simple polyphonic sine wave synthesizer Audio Unit plugin for macOS.

## Features
- 16-voice polyphony
- Sine wave synthesis
- MIDI note on/off support
- Velocity sensitivity
- Compatible with Logic Pro and other AU hosts

## Requirements
- macOS 10.13 or later
- Xcode (full installation, not just Command Line Tools)
- Logic Pro or other Audio Unit host for testing

## Building

### Option 1: Using Xcode (Recommended)

**Note**: This requires the full Xcode application, not just Command Line Tools.

1. Install Xcode from the Mac App Store if not already installed
2. Open Terminal and create an Xcode project:

```bash
cd ClaudeSynth
# You'll need to create the Xcode project manually or use a template
```

For manual Xcode project creation:
1. Open Xcode
2. File > New > Project
3. Choose "Bundle" under macOS Framework & Library
4. Set Product Name to "ClaudeSynth"
5. Add all files from Source/ to the project
6. Add Resources/Info.plist to the project
7. In Build Settings:
   - Set "Wrapper Extension" to "component"
   - Link frameworks: AudioUnit, AudioToolbox, CoreAudio, CoreFoundation
   - Set "Installation Directory" to "$(HOME)/Library/Audio/Plug-Ins/Components"

### Option 2: Using CMake

```bash
cd ClaudeSynth
mkdir build
cd build
cmake ..
make
```

Note: CMake build may require additional configuration for Audio Unit bundles.

## Installation

1. Build the plugin (it will create ClaudeSynth.component)
2. Copy to your Audio Unit plugins folder:

```bash
cp -r build/ClaudeSynth.component ~/Library/Audio/Plug-Ins/Components/
```

3. Restart your DAW or run:

```bash
killall -9 AudioComponentRegistrar
```

## Validation

Validate the Audio Unit using Apple's auval tool:

```bash
auval -v aumu ClSy Demo
```

Expected output should show "PASSED" tests.

## Usage

1. Open Logic Pro (or another AU host)
2. Create a new Software Instrument track
3. In the instrument slot, browse for "ClaudeSynth" under AU Instruments > Demo
4. Load the plugin
5. Play MIDI notes - you should hear sine wave tones

## Architecture

- **ClaudeSynth.cpp**: Main Audio Unit plugin class, inherits from AUInstrumentBase
- **SynthVoice.h**: Voice class for polyphonic sine wave generation
- **ClaudeSynthVersion.h**: Version and component identifiers
- **Info.plist**: Audio Unit component metadata

## Technical Details

- **Component Type**: `aumu` (Audio Unit Music Device/Instrument)
- **Component Subtype**: `ClSy`
- **Manufacturer**: `Demo`
- **Polyphony**: 16 voices
- **Voice Allocation**: Simple voice stealing (steals oldest voice when all busy)
- **Synthesis**: Phase accumulator-based sine wave generation
- **MIDI to Frequency**: Standard equal temperament (A4 = 440 Hz)

## Troubleshooting

### Plugin doesn't appear in Logic
- Verify installation path: `~/Library/Audio/Plug-Ins/Components/`
- Check bundle structure is correct
- Run `auval -v aumu ClSy Demo` to validate
- Restart Logic Pro
- Run `killall -9 AudioComponentRegistrar` to clear component cache

### Build errors
- Ensure Xcode is fully installed (not just Command Line Tools)
- Check that all frameworks are linked
- Verify Info.plist is included in bundle

### No sound
- Check MIDI input is being received (MIDI indicator in Logic)
- Verify audio output routing
- Check plugin validation with auval
- Try different MIDI velocities

## License

This is a demonstration project for educational purposes.
