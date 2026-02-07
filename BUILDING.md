# Building ClaudeSynth

## Prerequisites

You **must** have the full Xcode application installed to build Audio Unit plugins. Command Line Tools alone are not sufficient.

### Installing Xcode

1. Open the Mac App Store
2. Search for "Xcode"
3. Click "Get" or "Install"
4. Wait for installation to complete (this may take 30+ minutes)
5. Open Xcode and accept the license agreement
6. Verify installation:

```bash
xcode-select -p
# Should show: /Applications/Xcode.app/Contents/Developer
```

If it shows `/Library/Developer/CommandLineTools`, switch to Xcode:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## Build Instructions

### Creating the Xcode Project

Since you need a proper Xcode project for Audio Unit development, here's how to create one:

#### Method 1: Using Xcode GUI (Easiest)

1. Open Xcode
2. File → New → Project
3. Select "macOS" tab
4. Choose "Bundle" under "Framework & Library"
5. Click "Next"
6. Fill in:
   - Product Name: `ClaudeSynth`
   - Organization Identifier: `com.demo`
   - Language: `C++`
7. Click "Next" and save in the `ClaudeSynth` folder

#### Method 2: Manual Xcode Project Setup

After creating the basic bundle project:

1. **Add Source Files**:
   - Right-click on project in navigator → "Add Files to ClaudeSynth"
   - Add all files from `Source/` folder
   - Add `Resources/Info.plist`

2. **Configure Build Settings**:
   - Select project in navigator
   - Select "ClaudeSynth" target
   - Go to "Build Settings" tab
   - Set the following:

   | Setting | Value |
   |---------|-------|
   | Wrapper Extension | `component` |
   | Product Name | `ClaudeSynth` |
   | Installation Directory | `$(HOME)/Library/Audio/Plug-Ins/Components` |
   | Skip Install | `NO` |
   | Info.plist File | `Resources/Info.plist` |
   | C++ Language Dialect | `C++11` |

3. **Link Frameworks**:
   - Select target → "Build Phases" tab
   - Expand "Link Binary With Libraries"
   - Click "+" button and add:
     - AudioUnit.framework
     - AudioToolbox.framework
     - CoreAudio.framework
     - CoreFoundation.framework

4. **Add Header Search Paths**:
   - In Build Settings, find "Header Search Paths"
   - Add:
     - `/System/Library/Frameworks/AudioUnit.framework/Headers`
     - `/System/Library/Frameworks/AudioToolbox.framework/Headers`

5. **Configure Info.plist**:
   - Select `Resources/Info.plist`
   - Verify the AudioComponents entry is present (already in the file)

### Building

#### From Xcode:
1. Open the project: `ClaudeSynth.xcodeproj`
2. Select "ClaudeSynth" scheme
3. Choose "My Mac" as destination
4. Product → Build (⌘B)

#### From Command Line:
```bash
cd ClaudeSynth
xcodebuild -project ClaudeSynth.xcodeproj -configuration Release clean build
```

The built plugin will be at:
```
build/Release/ClaudeSynth.component
```

## Installation

### Automatic (if configured)
If you set the Installation Directory correctly, the plugin installs automatically when you build.

### Manual
```bash
cp -r build/Release/ClaudeSynth.component ~/Library/Audio/Plug-Ins/Components/
```

### Verify Installation
```bash
ls -la ~/Library/Audio/Plug-Ins/Components/ | grep ClaudeSynth
```

## Post-Installation

### Clear Audio Component Cache
```bash
killall -9 AudioComponentRegistrar
```

### Validate the Plugin
```bash
auval -v aumu ClSy Demo
```

Expected output:
```
--------------------------------------------------
VALIDATING AUDIO UNIT: 'aumu' - 'ClSy' - 'Demo'
--------------------------------------------------
...
* * PASS
--------------------------------------------------
```

## Testing in Logic Pro

1. Launch Logic Pro
2. Create new project (Software Instrument)
3. In the instrument slot, click to open plugin selector
4. Navigate to: AU Instruments → Demo → ClaudeSynth
5. Select "ClaudeSynth"
6. Play your MIDI keyboard or virtual keyboard
7. You should hear sine wave tones

## Debugging

### Attach Debugger to Logic
1. In Xcode, select Product → Scheme → Edit Scheme
2. Go to "Run" tab → "Info" subtab
3. Set "Executable" to "Other..."
4. Navigate to `/Applications/Logic Pro.app`
5. Click "Run" (▶) in Xcode
6. Logic will launch with debugger attached
7. Load your plugin and any breakpoints will trigger

### Common Issues

**Error: "xcodebuild: error: tool 'xcodebuild' requires Xcode"**
- Solution: Install full Xcode (not just Command Line Tools)

**Plugin doesn't appear in Logic**
- Run `auval -v aumu ClSy Demo` to check validation
- Clear component cache: `killall -9 AudioComponentRegistrar`
- Check installation path: `~/Library/Audio/Plug-Ins/Components/`
- Restart Logic

**Build errors about missing headers**
- Verify Xcode installation
- Check Header Search Paths in Build Settings
- Ensure all frameworks are linked

**"Code signing" errors**
- For development, you can use ad-hoc signing
- In Build Settings, set "Code Signing Identity" to "Sign to Run Locally"

## Alternative: CMake Build (Advanced)

If you prefer CMake (though less tested for Audio Units):

```bash
cd ClaudeSynth
mkdir build && cd build
cmake -G Xcode ..
xcodebuild -project ClaudeSynth.xcodeproj -configuration Release
```

Note: The CMake build may need additional configuration for proper Audio Unit bundle structure.
