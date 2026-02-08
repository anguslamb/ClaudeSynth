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
- **Dual ADSR Envelopes**:
  - Amplitude envelope with full Attack, Decay, Sustain, Release controls (1ms - 5s)
  - Global filter envelope for dynamic filter modulation
- **Modulation Matrix** with 4 slots:
  - Sources: LFO 1, LFO 2, Filter Envelope
  - Destinations: Filter Cutoff, Filter Resonance, Master Volume, Oscillator Detune/Volume
  - Adjustable intensity per slot (0-100%)
- **Dual LFO System**:
  - 4 waveforms each: Sine, Square, Sawtooth, Triangle
  - Rate control: 0.1 Hz - 20 Hz
- **Effects Section** with three modulation effects:
  - **Chorus**: Doubling/thickening effect with 15ms base delay
  - **Phaser**: Sweeping notch filter (200-2000 Hz)
  - **Flanger**: Jet plane whoosh with swept delay (1-4ms)
  - Rate control: 0.1 Hz - 10 Hz
  - Intensity control: 0-100%
- **Master Volume** control (0-100%)
- **Velocity sensitivity** for dynamic response

### User Interface
- **Custom Cocoa UI** with dark theme (1440x520 pixels)
- **Rotary knobs** with visual feedback:
  - Bipolar mode for centered controls (octave, detune)
  - Range markers showing min/max positions
  - Real-time value displays
- **Waveform sliders** with visual waveform icons
- **Interactive ADSR envelope graphs** with draggable handles
- **Modulation matrix** with dropdown selectors and intensity knobs
- **Effects section** with type selector, rate, and intensity controls
- **Host automation support** with real-time UI updates (100ms polling)
- Organized layout:
  - Top section: Oscillators, LFOs, Filter, Envelopes, Master
  - Bottom section: Modulation Matrix, Effects

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

### Lush Chorus Pad
- **Osc 1**: Sawtooth wave, octave 0, volume 100%
- **Osc 2**: Sawtooth wave, octave 0, detune -8 cents, volume 80%
- **Osc 3**: Triangle wave, octave +1, volume 40%
- **Filter**: Cutoff 3 kHz, resonance 1.5
- **Envelope**: Attack 800ms, decay 400ms, sustain 70%, release 1s
- **Effects**: Chorus at 0.5 Hz, intensity 60%

### Swept Phaser Lead
- **Osc 1**: Square wave, octave 0, volume 100%
- **Osc 2**: Sawtooth wave, octave 0, detune +12 cents, volume 70%
- **Filter**: Cutoff 5 kHz, resonance 2.0
- **Envelope**: Attack 10ms, decay 150ms, sustain 60%, release 200ms
- **Effects**: Phaser at 0.3 Hz, intensity 70%
- **Modulation**: LFO 1 (0.8 Hz Sine) → Filter Cutoff at 50%

### Aggressive Flanger Bass
- **Osc 1**: Square wave, octave -1, volume 100%
- **Osc 2**: Sawtooth wave, octave -1, detune +5 cents, volume 80%
- **Filter**: Cutoff 800 Hz, resonance 3.0
- **Envelope**: Attack 1ms, decay 250ms, sustain 30%, release 150ms
- **Effects**: Flanger at 2 Hz, intensity 80%

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
- Use the modulation matrix to create movement:
  - Connect LFO 1 to Filter Cutoff for classic filter sweeps
  - Route Filter Envelope to Oscillator Volume for dynamic timbral changes
  - Assign LFO 2 to Oscillator Detune for vibrato effects
- Add depth with effects:
  - Chorus for subtle thickening and width
  - Phaser for vintage swirling textures
  - Flanger for dramatic jet plane whooshes
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

**Default**: 10ms attack, 300ms decay, 70% sustain, 300ms release

### Master
| Parameter | Range | Description |
|-----------|-------|-------------|
| Volume | 0-100% | Overall output level |

**Default**: 100%

### Filter Envelope
Global filter envelope for modulation routing:

| Parameter | Range | Description |
|-----------|-------|-------------|
| Attack | 1ms - 5s | Time to reach peak after note on |
| Decay | 1ms - 5s | Time to fall to sustain level |
| Sustain | 0-100% | Level held while note is pressed |
| Release | 1ms - 5s | Time to fade after note off |

**Default**: 10ms attack, 300ms decay, 100% sustain, 300ms release

### LFOs (x2)
Two independent low-frequency oscillators for modulation:

| Parameter | Range | Description |
|-----------|-------|-------------|
| Waveform | 0-3 | Sine (0), Square (1), Sawtooth (2), Triangle (3) |
| Rate | 0.1 - 20 Hz | LFO frequency |

**Defaults**: LFO 1 at 5 Hz Sine, LFO 2 at 3 Hz Sine

### Modulation Matrix
Four modulation slots with source, destination, and intensity:

| Parameter | Options | Description |
|-----------|---------|-------------|
| Source | None, LFO 1, LFO 2, Filter Env | Modulation source |
| Destination | None, Filter Cutoff, Filter Resonance, Master Volume, Osc 1-3 Detune/Volume | Target parameter |
| Intensity | 0-100% | Modulation depth |

**Default**: All slots set to None

**Destinations Scale Ranges:**
- Filter Cutoff: ±10,000 Hz
- Filter Resonance: ±5.0 Q
- Master Volume: ±0.5 (50%)
- Oscillator Detune: ±100 cents
- Oscillator Volume: ±0.5 (50%)

### Effects
Three time-based modulation effects with shared controls:

| Parameter | Range/Options | Description |
|-----------|---------------|-------------|
| Effect Type | None, Chorus, Phaser, Flanger | Select effect or bypass |
| Rate | 0.1 - 10 Hz | Effect LFO modulation speed |
| Intensity | 0-100% | Effect depth/wet amount |

**Default**: None (bypassed), 1 Hz rate, 50% intensity

**Effect Characteristics:**
- **Chorus**: 15ms base delay with ±2ms LFO modulation for doubling/thickening
- **Phaser**: 4-stage all-pass filters swept from 200-2000 Hz with feedback
- **Flanger**: 1-4ms swept delay with high feedback for resonant comb filtering

## Architecture

### Core Engine
- **ClaudeSynth.h/cpp**: Main Audio Unit plugin class
  - Parameter management (42 parameters)
  - Voice allocation and MIDI handling
  - Audio render callback with effects processing
  - Global filter envelope system
  - Modulation matrix routing (4 slots)
  - Effects processing (Chorus, Phaser, Flanger)
- **SynthVoice.h/cpp**: Voice class with complete synthesis chain
  - 3 oscillators with 4 waveforms each
  - State Variable Filter (SVF) implementation
  - ADSR envelope generator with linear decay
  - Phase accumulator-based waveform generation
  - Modulation value application per voice

### User Interface
- **ClaudeSynthView.h/mm**: Custom Cocoa UI view
  - 1440x520 dark-themed interface
  - Host automation synchronization via timer (100ms)
  - Factory function for AU host integration
  - Modulation matrix section creation
  - Effects section with popup and knobs
- **RotaryKnob.h/mm**: Custom rotary control
  - Bipolar and unipolar modes
  - Visual range markers
  - Mouse drag interaction
- **DiscreteKnob.h/mm**: Stepped control for waveform selection
- **ADSREnvelopeView.h/mm**: Interactive envelope editor
  - Draggable handles for A/D/S/R
  - Visual curve representation
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
- **Voice Allocation**: Steals oldest voice when all busy, with retrigger support
- **Oscillators**: 3 per voice, phase accumulator-based
  - Waveforms: Sine, Square, Sawtooth, Triangle
  - Octave shifting: multiply frequency by 2^octave
  - Detune: multiply frequency by 2^(cents/1200)
  - Per-voice modulation via modulation matrix
- **Filter**: State Variable Filter (SVF)
  - Type: Low-pass
  - Cutoff: 20 Hz - 20 kHz (logarithmic)
  - Resonance: Q factor 0.5 - 10.0
  - Modulation via matrix or filter envelope
- **Envelopes**:
  - Per-voice amplitude ADSR with linear segments
  - Global filter envelope for modulation
  - Attack/Decay/Release: 1ms - 5s, Sustain: 0-100%
- **LFOs**: 2 global LFOs
  - Waveforms: Sine, Square, Sawtooth, Triangle
  - Rate: 0.1-20 Hz, phase accumulator-based
- **Modulation Matrix**: 4 slots
  - Sources: LFO 1, LFO 2, Filter Envelope
  - 10 possible destinations with scaled routing
- **Effects**: Post-voice processing chain
  - **Chorus**: 2048-sample delay buffer, 15ms ±2ms swept delay
  - **Phaser**: 4-stage all-pass filters with feedback
  - **Flanger**: 1024-sample delay buffer, 1-4ms swept delay with feedback
  - Dedicated effect LFO (0.1-10 Hz sine wave)
  - Smart processing (only active when voices are playing)
- **MIDI to Frequency**: Standard equal temperament (A4 = 440 Hz)
- **Sample Rate**: Determined by host (44.1/48 kHz typical)

### Parameters (42 total)
- Master Volume (0-1)
- 3x Oscillators (waveform 0-3, octave -2 to +2, detune -100 to +100 cents, volume 0-1)
- Filter (cutoff 20-20000 Hz, resonance 0.5-10)
- Amplitude Envelope (attack/decay/release 0.001-5s, sustain 0-1)
- Filter Envelope (attack/decay/release 0.001-5s, sustain 0-1)
- 2x LFOs (waveform 0-3, rate 0.1-20 Hz)
- 4x Modulation Slots (source 0-3, destination 0-9, intensity 0-1)
- Effects (type 0-3, rate 0.1-10 Hz, intensity 0-1)

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
- Try reducing effects intensity or disabling effects
- Lower LFO modulation intensity in modulation matrix

### Effects not audible or distorted
- Verify effect type is not set to "None"
- Check effect intensity is above 0%
- For Chorus: works best with sustained sounds, may be subtle on short notes
- For Phaser: increase intensity above 50% for more obvious effect
- For Flanger: try faster rates (2-5 Hz) for classic jet plane sound
- If distorted: reduce effect intensity or master volume

## License

This is a demonstration project for educational purposes.
