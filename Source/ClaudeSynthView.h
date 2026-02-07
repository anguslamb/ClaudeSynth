#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioUnit/AUCocoaUIView.h>
#import <AudioToolbox/AudioToolbox.h>
#import "RotaryKnob.h"

@interface ClaudeSynthView : NSView
{
    AudioUnit mAU;

    // Master Volume
    RotaryKnob *masterVolumeKnob;
    NSTextField *masterVolumeLabel;
    NSTextField *masterVolumeDisplay;

    // Oscillator 1
    NSTextField *osc1Label;
    NSSlider *osc1WaveformKnob;
    NSTextField *osc1WaveformLabel;
    RotaryKnob *osc1OctaveKnob;
    NSTextField *osc1OctaveLabel;
    NSTextField *osc1OctaveDisplay;
    RotaryKnob *osc1DetuneKnob;
    NSTextField *osc1DetuneLabel;
    NSTextField *osc1DetuneDisplay;
    RotaryKnob *osc1VolumeKnob;
    NSTextField *osc1VolumeLabel;
    NSTextField *osc1VolumeDisplay;

    // Oscillator 2
    NSTextField *osc2Label;
    NSSlider *osc2WaveformKnob;
    NSTextField *osc2WaveformLabel;
    RotaryKnob *osc2OctaveKnob;
    NSTextField *osc2OctaveLabel;
    NSTextField *osc2OctaveDisplay;
    RotaryKnob *osc2DetuneKnob;
    NSTextField *osc2DetuneLabel;
    NSTextField *osc2DetuneDisplay;
    RotaryKnob *osc2VolumeKnob;
    NSTextField *osc2VolumeLabel;
    NSTextField *osc2VolumeDisplay;

    // Oscillator 3
    NSTextField *osc3Label;
    NSSlider *osc3WaveformKnob;
    NSTextField *osc3WaveformLabel;
    RotaryKnob *osc3OctaveKnob;
    NSTextField *osc3OctaveLabel;
    NSTextField *osc3OctaveDisplay;
    RotaryKnob *osc3DetuneKnob;
    NSTextField *osc3DetuneLabel;
    NSTextField *osc3DetuneDisplay;
    RotaryKnob *osc3VolumeKnob;
    NSTextField *osc3VolumeLabel;
    NSTextField *osc3VolumeDisplay;

    // Filter
    NSTextField *filterLabel;
    RotaryKnob *cutoffKnob;
    NSTextField *cutoffLabel;
    NSTextField *cutoffValueDisplay;
    RotaryKnob *resonanceKnob;
    NSTextField *resonanceLabel;
    NSTextField *resonanceValueDisplay;

    // Envelope
    NSTextField *envelopeLabel;
    NSSlider *attackSlider;
    NSTextField *attackLabel;
    NSTextField *attackDisplay;
    NSSlider *decaySlider;
    NSTextField *decayLabel;
    NSTextField *decayDisplay;
    NSSlider *sustainSlider;
    NSTextField *sustainLabel;
    NSTextField *sustainDisplay;
    NSSlider *releaseSlider;
    NSTextField *releaseLabel;
    NSTextField *releaseDisplay;

    NSTextField *titleLabel;
    NSTimer *updateTimer;
}

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au;
- (void)masterVolumeChanged:(id)sender;
- (void)osc1WaveformChanged:(id)sender;
- (void)osc1OctaveChanged:(id)sender;
- (void)osc1DetuneChanged:(id)sender;
- (void)osc1VolumeChanged:(id)sender;
- (void)osc2WaveformChanged:(id)sender;
- (void)osc2OctaveChanged:(id)sender;
- (void)osc2DetuneChanged:(id)sender;
- (void)osc2VolumeChanged:(id)sender;
- (void)osc3WaveformChanged:(id)sender;
- (void)osc3OctaveChanged:(id)sender;
- (void)osc3DetuneChanged:(id)sender;
- (void)osc3VolumeChanged:(id)sender;
- (void)cutoffChanged:(id)sender;
- (void)resonanceChanged:(id)sender;
- (void)attackChanged:(id)sender;
- (void)decayChanged:(id)sender;
- (void)sustainChanged:(id)sender;
- (void)releaseChanged:(id)sender;
- (void)updateFromHost:(NSTimer *)timer;

@end
