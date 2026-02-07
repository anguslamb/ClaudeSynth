#!/bin/bash

# Simple test script for ClaudeSynth
echo "=== ClaudeSynth Test ==="
echo ""

# Check if plugin exists
if [ ! -d ~/Library/Audio/Plug-Ins/Components/ClaudeSynth.component ]; then
    echo "ERROR: ClaudeSynth.component not found!"
    echo "Run 'make install' first"
    exit 1
fi

echo "✓ Plugin found at ~/Library/Audio/Plug-Ins/Components/ClaudeSynth.component"
echo ""

# Check if it loads
echo "Testing plugin with auval..."
auval -v aumu ClSy Demo 2>&1 | head -30

echo ""
echo "=== Test Complete ==="
echo ""
echo "To test in Logic Pro:"
echo "1. Open Logic Pro"
echo "2. Create Software Instrument track"
echo "3. Load: AU Instruments → Demo → ClaudeSynth"
echo "4. Play MIDI notes"
echo ""
echo "If no sound:"
echo "- Check Logic's MIDI activity indicator (should flash on notes)"
echo "- Check track is armed/enabled"
echo "- Check volume levels"
echo "- Try Window → Show MIDI Activity to see if MIDI is being received"
