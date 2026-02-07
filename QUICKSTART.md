# ClaudeSynth Quick Start Guide

## Current Situation

You have only Xcode Command Line Tools installed. To build Audio Unit plugins, you need the **full Xcode application**.

## Two Paths Forward

### Path A: Install Xcode (Recommended for AU Development)

This is the proper way to develop Audio Units on macOS.

1. **Install Xcode** (30-60 minutes):
   ```bash
   # Open Mac App Store and search for "Xcode"
   # Or use command line:
   open "macappstore://apps.apple.com/app/xcode/id497799835"
   ```

2. **Configure Xcode**:
   ```bash
   # After installation, switch to Xcode
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

   # Accept license
   sudo xcodebuild -license accept
   ```

3. **Create Xcode Project**:
   - Open Xcode
   - File → New → Project
   - macOS → Bundle
   - Product Name: "ClaudeSynth"
   - Save to this folder

4. **Configure Project** (follow BUILDING.md for details):
   - Add source files from `Source/`
   - Add `Resources/Info.plist`
   - Link frameworks: AudioUnit, AudioToolbox, CoreAudio, CoreFoundation
   - Set wrapper extension to "component"
   - Set build settings as described in BUILDING.md

5. **Build**:
   ```bash
   cd ClaudeSynth
   xcodebuild -project ClaudeSynth.xcodeproj -configuration Release
   ```

6. **Install & Test**:
   ```bash
   cp -r build/Release/ClaudeSynth.component ~/Library/Audio/Plug-Ins/Components/
   killall -9 AudioComponentRegistrar
   auval -v aumu ClSy Demo
   ```

### Path B: Try Makefile Build (Experimental)

This might work with just Command Line Tools, but is not officially supported for AU development.

```bash
cd ClaudeSynth
make
make install
make validate
```

**Known Issues with Makefile approach**:
- May fail with missing AudioUnit SDK headers
- Bundle structure might not be correct
- Code signing may not work properly
- Apple recommends Xcode for AU development

## Testing the Plugin

Once built and installed:

1. Open Logic Pro
2. Create new Software Instrument track
3. Click instrument slot → AU Instruments → Demo → ClaudeSynth
4. Play MIDI notes on your keyboard
5. You should hear sine wave tones

## File Overview

### Source Code
- `Source/ClaudeSynth.cpp` - Main plugin implementation
- `Source/ClaudeSynth.h` - Plugin class declaration
- `Source/SynthVoice.h` - Voice synthesis engine
- `Source/ClaudeSynthVersion.h` - Version info

### Resources
- `Resources/Info.plist` - Audio Unit metadata

### Documentation
- `README.md` - General overview
- `BUILDING.md` - Detailed build instructions
- `QUICKSTART.md` - This file

### Build Files
- `Makefile` - Experimental command-line build
- `CMakeLists.txt` - CMake configuration (also experimental)
- `create_xcode_project.sh` - Helper script

## What The Plugin Does

ClaudeSynth is a simple polyphonic synthesizer that:
- Responds to MIDI note on/off messages
- Generates sine waves at the correct pitch for each note
- Supports 16 simultaneous voices (polyphony)
- Responds to velocity (louder notes = higher velocity)
- Works as a standard Audio Unit instrument

## Troubleshooting

### "xcodebuild requires Xcode"
→ You need full Xcode, not just Command Line Tools

### Plugin doesn't show up in Logic
```bash
# Check installation
ls ~/Library/Audio/Plug-Ins/Components/

# Clear cache
killall -9 AudioComponentRegistrar

# Validate
auval -v aumu ClSy Demo
```

### No sound when playing notes
- Check MIDI input is connected
- Check Logic's MIDI activity indicator
- Verify plugin passed validation
- Check audio output routing

### Makefile build fails
- Try installing full Xcode instead
- Check that AudioUnit headers are accessible
- Some paths may need adjustment for your system

## Next Steps

After you have a working plugin:
- Modify `SynthVoice.h` to try different waveforms
- Add parameters (filter, ADSR envelope, etc.)
- Add multiple oscillators
- Implement different synthesis methods
- Add a user interface (requires AUv3 or VST3)

## Support

For Audio Unit development questions:
- Apple's Audio Unit Programming Guide
- Core Audio mailing list
- Audio Developer Conference (ADC)

This is a learning project - feel free to experiment!
