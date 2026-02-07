# ClaudeSynth - Audio Unit Synthesizer

A feature-rich polyphonic subtractive synthesizer Audio Unit plugin for macOS with custom UI.

## Features

### Sound Generation
- **16-voice polyphony** with automatic voice allocation
- **3 oscillators** per voice with independent controls:
  - 4 waveforms: Sine, Square, Sawtooth, Triangle
  - Octave control (-2 to +2 octaves)
  - Detune control (-100 to +100 cents)
  - Individual volume control (0-100%)
- **State Variable Filter** with cutoff (20 Hz - 20 kHz) and resonance (Q: 0.5 - 10.0)
- **ADSR Envelope** with full Attack, Decay, Sustain, Release controls (1ms - 5s)
- **Master Volume** control (0-100%)
- **Velocity sensitivity** for dynamic response

### User Interface
- **Custom Cocoa UI** with dark theme
- **Rotary knobs** with visual feedback:
  - Bipolar mode for centered controls (octave, detune)
  - Range markers showing min/max positions
  - Real-time value displays
- **Waveform sliders** with visual waveform icons
- **Vertical ADSR sliders** with ms/s formatting
- **Host automation support** with real-time UI updates
- Organized into 6 sections: Osc 1-3, Filter, Envelope, Master

### Compatibility
- Compatible with Logic Pro and other AU hosts
- Supports DAW automation for all parameters
- MIDI note on/off support

## Requirements
- macOS 10.13 or later
- Xcode (full installation, not just Command Line Tools)
- Logic Pro or other Audio Unit host for testing

## Building

### Option 1: Using Makefile (Recommended)

The project includes a Makefile for easy building:

```bash
cd ClaudeSynth
make              # Build the plugin
make install      # Install to ~/Library/Audio/Plug-Ins/Components/
make clean        # Clean build artifacts
```

This will build a universal binary (x86_64 + arm64) compatible with both Intel and Apple Silicon Macs.

### Option 2: Using Xcode

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
   - Link frameworks: AudioUnit, AudioToolbox, CoreAudio, CoreFoundation, Cocoa, QuartzCore
   - Set "Installation Directory" to "$(HOME)/Library/Audio/Plug-Ins/Components"
   - Enable Objective-C ARC: `-fobjc-arc`

## Installation

### Using Makefile
```bash
make install
```

This automatically:
- Builds the plugin
- Installs to `~/Library/Audio/Plug-Ins/Components/`
- Clears the Audio Unit component cache

### Manual Installation

1. Build the plugin (it will create ClaudeSynth.component)
2. Copy to your Audio Unit plugins folder:

```bash
cp -r build/ClaudeSynth.component ~/Library/Audio/Plug-Ins/Components/
```

3. Clear the component cache:

```bash
killall -9 AudioComponentRegistrar
```

## Sound Design Examples

### Classic Synth Bass
- **Osc 1**: Square wave, octave -1, volume 100%
- **Osc 2**: Sawtooth wave, octave -1, detune +5 cents, volume 50%
- **Filter**: Cutoff 300-800 Hz, resonance 2.0
- **Envelope**: Attack 1ms, decay 200ms, sustain 20%, release 100ms

### Warm Pad
- **Osc 1**: Sine wave, octave 0, volume 100%
- **Osc 2**: Sawtooth wave, octave 0, detune -10 cents, volume 70%
- **Osc 3**: Triangle wave, octave +1, detune +15 cents, volume 40%
- **Filter**: Cutoff 2-5 kHz, resonance 0.5
- **Envelope**: Attack 500ms, decay 300ms, sustain 70%, release 800ms

### Pluck/Bell
- **Osc 1**: Triangle wave, octave 0, volume 100%
- **Osc 2**: Sine wave, octave +2, volume 50%
- **Filter**: Cutoff 8 kHz, resonance 3.0
- **Envelope**: Attack 1ms, decay 300ms, sustain 0%, release 500ms

### Fat Lead
- **Osc 1**: Sawtooth wave, octave 0, volume 100%
- **Osc 2**: Square wave, octave 0, detune -7 cents, volume 80%
- **Osc 3**: Sawtooth wave, octave 0, detune +7 cents, volume 80%
- **Filter**: Cutoff 3-6 kHz, resonance 2.5
- **Envelope**: Attack 5ms, decay 100ms, sustain 80%, release 200ms

### Hollow Flute
- **Osc 1**: Sine wave, octave 0, volume 100%
- **Osc 2**: Sine wave, octave +1, volume 30%
- **Filter**: Cutoff 2 kHz, resonance 4.0
- **Envelope**: Attack 100ms, decay 50ms, sustain 90%, release 300ms

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
4. Load the plugin - the custom UI should appear automatically
5. Play MIDI notes and adjust the controls:
   - **Oscillators**: Enable multiple oscillators by raising their volume knobs
   - **Waveform**: Use the vertical sliders to select waveform types
   - **Octave/Detune**: Fine-tune pitch relationships between oscillators
   - **Filter**: Adjust cutoff frequency and resonance for tone shaping
   - **Envelope**: Shape the amplitude contour with ADSR controls
   - **Master**: Set overall output level

### Tips
- Start with Oscillator 1 (default on) and add Oscillators 2 & 3 by raising their volume
- Combine different waveforms and octaves for rich timbres
- Use detune to create chorus/unison effects
- Lower the filter cutoff for darker sounds, increase resonance for emphasis
- Experiment with envelope settings for percussive or pad-like sounds
- All parameters support DAW automation

## Parameter Reference

### Oscillators (x3)
Each oscillator has independent controls:

| Parameter | Range | Description |
|-----------|-------|-------------|
| Waveform | 0-3 | Sine (0), Square (1), Sawtooth (2), Triangle (3) |
| Octave | -2 to +2 | Transpose in octave increments |
| Detune | -100 to +100 cents | Fine pitch adjustment (100 cents = 1 semitone) |
| Volume | 0-100% | Oscillator mix level |

**Default**: Osc 1 at 100%, Osc 2 & 3 at 0%

### Filter
State Variable Filter with resonance:

| Parameter | Range | Description |
|-----------|-------|-------------|
| Cutoff | 20 Hz - 20 kHz | Low-pass filter cutoff frequency (logarithmic) |
| Resonance | 0.5 - 10.0 | Q factor - emphasis at cutoff frequency |

**Default**: 20 kHz cutoff (fully open), 0.7 resonance

### Envelope (ADSR)
Amplitude envelope applied to each voice:

| Parameter | Range | Description |
|-----------|-------|-------------|
| Attack | 1ms - 5s | Time to reach full volume after note on |
| Decay | 1ms - 5s | Time to fall from peak to sustain level |
| Sustain | 0-100% | Level held while note is pressed |
| Release | 1ms - 5s | Time to fade to silence after note off |

**Default**: 10ms attack, 100ms decay, 70% sustain, 300ms release

### Master
| Parameter | Range | Description |
|-----------|-------|-------------|
| Volume | 0-100% | Overall output level |

**Default**: 100%

## Architecture

### Core Engine
- **ClaudeSynth.h/cpp**: Main Audio Unit plugin class (inherits from AUInstrumentBase)
  - Parameter management (19 parameters)
  - Voice allocation and MIDI handling
  - Audio render callback
- **SynthVoice.h**: Voice class with complete synthesis chain
  - 3 oscillators with 4 waveforms each
  - State Variable Filter (SVF) implementation
  - ADSR envelope generator with linear decay
  - Phase accumulator-based waveform generation

### User Interface
- **ClaudeSynthView.h/mm**: Custom Cocoa UI view
  - 1080x320 dark-themed interface
  - Host automation synchronization via timer
  - Factory function for AU host integration
- **RotaryKnob.h/mm**: Custom rotary control
  - Bipolar and unipolar modes
  - Visual range markers
  - Mouse drag interaction
- **WaveformIconView**: Visual waveform representations

### Configuration
- **ClaudeSynthVersion.h**: Version and component identifiers
- **Info.plist**: Audio Unit component metadata
- **Makefile**: Universal binary build system

## Technical Details

### Audio Unit Configuration
- **Component Type**: `aumu` (Audio Unit Music Device/Instrument)
- **Component Subtype**: `ClSy`
- **Manufacturer**: `Demo`
- **Version**: 1.0.0

### Synthesis Engine
- **Polyphony**: 16 voices with voice stealing
- **Voice Allocation**: Steals oldest voice when all busy
- **Oscillators**: 3 per voice, phase accumulator-based
  - Waveforms: Sine, Square, Sawtooth, Triangle
  - Octave shifting: multiply frequency by 2^octave
  - Detune: multiply frequency by 2^(cents/1200)
- **Filter**: State Variable Filter (SVF)
  - Type: Low-pass
  - Cutoff: 20 Hz - 20 kHz (logarithmic)
  - Resonance: Q factor 0.5 - 10.0
- **Envelope**: ADSR with linear release
  - Attack/Decay/Release: 1ms - 5s
  - Sustain: 0-100% level
- **MIDI to Frequency**: Standard equal temperament (A4 = 440 Hz)
- **Sample Rate**: Determined by host

### Parameters (19 total)
- Master Volume (0-1)
- 3x Oscillators (waveform 0-3, octave -2 to +2, detune -100 to +100 cents, volume 0-1)
- Filter (cutoff 20-20000 Hz, resonance 0.5-10)
- Envelope (attack/decay/release 0.001-5s, sustain 0-1)

## Troubleshooting

### Plugin doesn't appear in Logic
- Verify installation path: `~/Library/Audio/Plug-Ins/Components/`
- Check bundle structure is correct (should contain `Contents/MacOS/ClaudeSynth`)
- Run `auval -v aumu ClSy Demo` to validate
- Restart Logic Pro
- Run `killall -9 AudioComponentRegistrar` to clear component cache
- Check Console.app for any Audio Unit loading errors

### Custom UI doesn't appear
- Verify ClaudeSynthView.mm is compiled in the build
- Check that Cocoa and QuartzCore frameworks are linked
- Look for `ClaudeSynthViewFactory_Factory` symbol in the binary
- Ensure `-fobjc-arc` flag is enabled in build settings
- Try restarting the DAW after reinstalling

### Build errors
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- Check that all required frameworks are available
- Verify Info.plist is included in bundle
- For Makefile builds, ensure clang++ is in PATH
- Check that macOS SDK is available (Xcode.app must be installed)

### No sound
- Check MIDI input is being received (MIDI indicator in Logic)
- Verify oscillator volumes are not at 0% (Osc 1 defaults to 100%, others to 0%)
- Check master volume is not at 0%
- Ensure filter cutoff is not too low (try 20 kHz to bypass)
- Check envelope settings (very long attack or zero sustain will be silent)
- Verify audio output routing in DAW
- Run `auval -v aumu ClSy Demo` to check for validation errors
- Try different MIDI velocities

### UI controls not responding
- Check that host automation isn't overriding manual changes
- Verify parameter changes in host automation window
- Try closing and reopening the plugin window
- Some hosts cache UI state - try creating a new instance

### Crackling or audio artifacts
- Lower the filter resonance (high Q values can cause instability)
- Reduce the number of active oscillators
- Check CPU usage in Activity Monitor
- Increase DAW buffer size if experiencing dropouts

## License

This is a demonstration project for educational purposes.
