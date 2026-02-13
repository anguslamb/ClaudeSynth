# ClaudeSynth - Project Context

## Overview

ClaudeSynth is a polyphonic subtractive synthesizer implemented as a macOS Audio Unit (AU) plugin. It features three oscillators, filter section, dual envelopes, dual LFOs, a modulation matrix, built-in effects, and an arpeggiator.

**Target Platform:** macOS 10.13+
**Plugin Format:** Audio Unit v2
**Language:** C++ (DSP) and Objective-C++ (UI)
**Build System:** Make with clang++

## Project Structure

```
ClaudeSynth/
├── Source/
│   ├── ClaudeSynth.cpp/h          # Main AU plugin implementation (DSP)
│   ├── ClaudeSynthView.mm/h       # Main UI view and layout
│   ├── RotaryKnob.mm/h            # Continuous rotary knob control
│   ├── DiscreteKnob.mm/h          # Discrete position knob (waveform selector)
│   ├── ADSREnvelopeView.mm/h      # Interactive ADSR envelope editor
│   ├── MatrixDropdown.mm/h        # Custom dropdown menu control
│   ├── MatrixCheckbox.mm/h        # Custom checkbox control
│   └── MatrixSlider.mm/h          # Custom vertical slider control
├── Resources/
│   └── Info.plist                 # AU plugin metadata
├── Makefile                       # Build configuration
└── CLAUDE.md                      # This file
```

## Semantic Versioning System

**Current Version:** Defined in `Source/ClaudeSynth.h` as `CLAUDESYNTH_VERSION`

### Version Display
- Shown in top-right corner of plugin UI
- Format: "v1.0.0"
- Color: Dim green (#006600) to match Matrix theme
- Font: Monaco 9pt

### Version Update Process
1. Update `CLAUDESYNTH_VERSION` constant in `Source/ClaudeSynth.h`
2. Update `CFBundleVersion` and `CFBundleShortVersionString` in `Resources/Info.plist`
3. Rebuild and reinstall: `make clean && make install`
4. Version appears automatically in UI and plugin metadata

### Versioning Guidelines
- **Major (X.0.0):** Breaking changes, major feature additions
- **Minor (1.X.0):** New features, significant enhancements (e.g., UI redesign)
- **Patch (1.0.X):** Bug fixes, minor improvements

## Matrix/Hacker Theme UI

The entire UI uses a custom Matrix/hacker-inspired terminal aesthetic with full control over appearance.

### Color Palette

Defined as class methods in `ClaudeSynthView`:

```objc
+ (NSColor *)matrixBackground;      // #000000 - Pure black
+ (NSColor *)matrixBrightGreen;     // #00FF00 - Headers, indicators, active elements
+ (NSColor *)matrixMediumGreen;     // #00AA00 - Labels, borders
+ (NSColor *)matrixDimGreen;        // #006600 - Secondary text, grids
+ (NSColor *)matrixDarkGreen;       // #001A00 - Knob bodies, backgrounds
+ (NSColor *)matrixCyan;            // #00FFFF - Value displays
```

### Typography

```objc
+ (NSFont *)matrixFontOfSize:(CGFloat)size;      // Monaco (regular)
+ (NSFont *)matrixBoldFontOfSize:(CGFloat)size;  // Monaco Bold
```

Fallback chain: Monaco → Menlo → System monospace/regular

### Custom UI Controls

All macOS system controls have been replaced with custom implementations for complete visual control:

#### 1. MatrixDropdown
**Purpose:** Dropdown menus
**Used for:** Effect type, arp rate/mode/octaves, modulation matrix sources/destinations
**Features:**
- Dark green background (#001400)
- Green border (medium → bright when active)
- Monaco monospace font
- Custom arrow indicator
- Dark popup menu with green text
- Checkmark on selected item

**API:**
```objc
MatrixDropdown *dropdown = [[MatrixDropdown alloc] initWithFrame:rect];
[dropdown addItemWithTitle:@"Option"];
[dropdown selectItemAtIndex:0];
[dropdown setTarget:self];
[dropdown setAction:@selector(changed:)];
NSInteger selected = [dropdown indexOfSelectedItem];
```

#### 2. MatrixCheckbox
**Purpose:** On/off toggle
**Used for:** Arpeggiator enable
**Features:**
- Dark green background square
- Green border
- Bright green checkmark when enabled
- Green text label
- Terminal-style appearance

**API:**
```objc
MatrixCheckbox *checkbox = [[MatrixCheckbox alloc] initWithFrame:rect];
[checkbox setTitle:@"Enable"];
[checkbox setState:NSControlStateValueOn];
[checkbox setTarget:self];
[checkbox setAction:@selector(changed:)];
NSControlStateValue state = [checkbox state];
```

#### 3. MatrixSlider
**Purpose:** Vertical slider with discrete positions
**Used for:** Waveform selection (oscillators and LFOs)
**Features:**
- Thin vertical track with dark green background
- Dim green border and tick marks
- Medium green filled portion (bottom to thumb)
- Bright green rectangular thumb
- Auto-snaps to tick marks when set
- Supports both vertical and horizontal orientations

**API:**
```objc
MatrixSlider *slider = [[MatrixSlider alloc] initWithFrame:rect];
[slider setMinValue:0];
[slider setMaxValue:3];
[slider setNumberOfTickMarks:4];  // Enables snapping
[slider setDoubleValue:1.0];
[slider setTarget:self];
[slider setAction:@selector(changed:)];
double value = [slider doubleValue];
```

#### 4. RotaryKnob (Modified)
**Purpose:** Continuous rotary control
**Used for:** Volume, detune, cutoff, resonance, etc.
**Features:**
- Dark green gradient body (#001F00 → #001A00)
- Medium green border
- Bright green indicator line
- Black center dot
- Dim green range markers
- Supports normal and bipolar modes

#### 5. DiscreteKnob (Modified)
**Purpose:** Rotary selector with discrete positions
**Used for:** Oscillator waveform selection
**Features:**
- Dark green gradient body
- Green position markers (bright when selected, dim otherwise)
- Bright green indicator line
- Green text label below

#### 6. ADSREnvelopeView (Modified)
**Purpose:** Interactive ADSR envelope graph
**Features:**
- Pure black background
- Dim green grid lines
- Bright green curve
- Bright green square vertices (draggable)
- Monaco font labels (A/D/S/R)

### Dark Appearance

The entire view uses `NSAppearanceNameDarkAqua` (macOS 10.14+) to ensure system-level consistency:

```objc
if (@available(macOS 10.14, *)) {
    [self setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
}
```

## Build System

### Commands
```bash
make              # Build plugin
make install      # Build and install to ~/Library/Audio/Plug-Ins/Components/
make clean        # Remove build artifacts
make validate     # Validate plugin with auval
make uninstall    # Remove installed plugin
```

### Build Configuration
- **Architectures:** x86_64 + arm64 (Universal Binary)
- **Min macOS:** 10.13
- **Optimization:** -O2
- **ARC:** Enabled with -fobjc-arc
- **Frameworks:** AudioUnit, AudioToolbox, CoreAudio, CoreFoundation, Cocoa, QuartzCore

### Installation Path
`~/Library/Audio/Plug-Ins/Components/ClaudeSynth.component`

The build process automatically:
1. Compiles all sources
2. Links frameworks
3. Creates bundle structure
4. Copies Info.plist
5. Sets bundle bit
6. Clears component cache (kills AudioComponentRegistrar)

## Development Guidelines

### Adding New Parameters
1. Add parameter ID to enum in `ClaudeSynth.h`
2. Add case in `GetParameterInfo()` for parameter metadata
3. Add UI control in `ClaudeSynthView.mm`
4. Connect control to parameter with `AudioUnitSetParameter()`
5. Handle parameter in DSP code in `Render()`

### Adding New UI Controls
1. Create custom control class inheriting from `NSControl`
2. Implement `drawRect:` with Matrix theme colors
3. Handle mouse events (`mouseDown:`, `mouseDragged:`)
4. Send action when value changes
5. Add to Makefile SOURCES
6. Import in `ClaudeSynthView.h`
7. Use `[ClaudeSynthView matrixXXXGreen]` for colors
8. Use `[ClaudeSynthView matrixFontOfSize:]` for fonts

### Color Usage Guidelines
- **Background:** Pure black
- **Headers/Titles:** Bright green + bold font
- **Labels:** Medium green
- **Values/Numbers:** Cyan (for high contrast)
- **Borders:** Medium green (normal), bright green (active/hover)
- **Indicators:** Bright green
- **Grids/Dividers:** Dim green
- **Knob bodies:** Dark green gradients

### Font Usage Guidelines
- **Headers:** matrixBoldFontOfSize (14pt)
- **Labels:** matrixFontOfSize (11pt)
- **Values:** matrixFontOfSize (9-10pt)
- Always use monospace fonts (Monaco preferred)

## Plugin Features

### Oscillators (3x)
- 4 waveforms: Sine, Square, Sawtooth, Triangle
- Octave range: -2 to +2
- Detune: ±1 semitone
- Individual volume control

### Filter
- 24dB/oct Moog-style ladder filter
- Cutoff: 20Hz - 20kHz
- Resonance: 0-100%
- Dedicated ADSR envelope

### Envelopes (2x)
- Main envelope (amplitude)
- Filter envelope
- ADSR parameters: Attack, Decay, Sustain, Release
- Interactive graphical editor

### LFOs (2x)
- 4 waveforms: Sine, Square, Sawtooth, Triangle
- Rate: 0.1 - 20 Hz
- Assignable via modulation matrix

### Modulation Matrix
- 4 modulation slots
- Sources: LFO 1, LFO 2, Filter Env
- Destinations: Filter Cutoff/Resonance, Master Volume, Osc Detune/Volume
- Intensity: 0-100%

### Effects
- Types: None, Chorus, Phaser, Flanger
- Rate: 0.1 - 10 Hz
- Intensity: 0-100%

### Arpeggiator
- Enable/disable toggle
- Rates: 1/4, 1/8, 1/16, 1/32 notes
- Modes: Up, Down, Up/Down, Random
- Octave range: 1-4
- Gate length: 10-100%
- Tempo-synced to host DAW

## Testing

### Manual Testing
1. Build and install: `make install`
2. Open Logic Pro or other AU host
3. Create software instrument track
4. Load ClaudeSynth
5. Test all parameters and UI interactions

### Validation
```bash
make validate
# Or manually:
auval -v aumu ClSy Demo
```

Expected output: "PASSED" with no errors

### Quick Testing Checklist
- [ ] All knobs respond to mouse drag
- [ ] All dropdowns open and change values
- [ ] Checkbox toggles state
- [ ] Sliders snap to positions
- [ ] ADSR envelope vertices are draggable
- [ ] Parameter automation from DAW works
- [ ] Sound output is correct
- [ ] No visual glitches or crashes
- [ ] Version number displays correctly

## Known Issues / Limitations

- Monaco font may not be available on all systems (fallback to Menlo/system monospace)
- Dark appearance requires macOS 10.14+ (gracefully degrades on older versions)
- Audio Unit v2 only (not AU v3)
- No preset management UI (uses DAW preset system)

## Future Enhancement Ideas

- Add preset browser
- Add oscilloscope/spectrum analyzer
- Add more filter types
- Add distortion/saturation effect
- Add delay/reverb effects
- Expand modulation matrix (more sources/destinations)
- Add macro controls
- Add MIDI learn
- Add keyboard tracking for filter
- Port to AU v3 / VST3

## Resources

- **Audio Unit Programming Guide:** https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitProgrammingGuide/
- **Core Audio Documentation:** https://developer.apple.com/documentation/coreaudio
- **Cocoa Drawing Guide:** https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaDrawingGuide/

## Git Workflow

- Main branch: `main`
- Commit style: Imperative mood, descriptive ("Add feature" not "Added feature")
- Always include Co-Authored-By: Claude Sonnet 4.5 in commits
- Push after significant features or logical groups of changes

---

**Last Updated:** 2026-02-13
**Current Version:** 1.0.0
**Plugin Type:** Audio Unit v2 Instrument
**Bundle ID:** com.demo.audiounit.ClaudeSynth
