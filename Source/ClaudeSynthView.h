#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioUnit/AUCocoaUIView.h>
#import <AudioToolbox/AudioToolbox.h>
#import "RotaryKnob.h"
#import "ADSREnvelopeView.h"
#import "MatrixDropdown.h"
#import "MatrixCheckbox.h"
#import "MatrixSlider.h"
#import "MatrixLED.h"

@interface ClaudeSynthView : NSView
{
    AudioUnit mAU;

    // Master Volume
    RotaryKnob *masterVolumeKnob;
    NSTextField *masterVolumeLabel;
    NSTextField *masterVolumeDisplay;

    // Oscillator 1
    NSTextField *osc1Label;
    MatrixSlider *osc1WaveformKnob;
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
    MatrixSlider *osc2WaveformKnob;
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
    MatrixSlider *osc3WaveformKnob;
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
    ADSREnvelopeView *envelopeView;
    NSTextField *attackDisplay;
    NSTextField *decayDisplay;
    NSTextField *sustainDisplay;
    NSTextField *releaseDisplay;

    // Filter Envelope
    NSTextField *filterEnvelopeLabel;
    ADSREnvelopeView *filterEnvelopeView;
    NSTextField *filterAttackDisplay;
    NSTextField *filterDecayDisplay;
    NSTextField *filterSustainDisplay;
    NSTextField *filterReleaseDisplay;

    // LFO 1
    MatrixSlider *lfoWaveformKnob;
    RotaryKnob *lfoRateKnob;
    NSTextField *lfoRateDisplay;
    MatrixCheckbox *lfo1TempoSyncCheckbox;
    MatrixDropdown *lfo1NoteDivisionDropdown;
    MatrixLED *lfo1LED;

    // LFO 2
    MatrixSlider *lfo2WaveformKnob;
    RotaryKnob *lfo2RateKnob;
    NSTextField *lfo2RateDisplay;
    MatrixCheckbox *lfo2TempoSyncCheckbox;
    MatrixDropdown *lfo2NoteDivisionDropdown;
    MatrixLED *lfo2LED;

    NSTextField *titleLabel;
    NSTimer *updateTimer;

    // Effects
    MatrixDropdown *effectTypePopup;
    RotaryKnob *effectRateKnob;
    NSTextField *effectRateDisplay;
    RotaryKnob *effectIntensityKnob;
    NSTextField *effectIntensityDisplay;

    // Arpeggiator
    MatrixCheckbox *arpEnableButton;
    MatrixDropdown *arpRatePopup;
    MatrixDropdown *arpModePopup;
    MatrixDropdown *arpOctavesPopup;
    RotaryKnob *arpGateKnob;
    NSTextField *arpGateDisplay;
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
- (void)envelopeChanged:(id)sender;
- (void)filterEnvelopeChanged:(id)sender;
- (void)lfo1WaveformChanged:(id)sender;
- (void)lfo1RateChanged:(id)sender;
- (void)lfo1TempoSyncChanged:(id)sender;
- (void)lfo1NoteDivisionChanged:(id)sender;
- (void)lfo2WaveformChanged:(id)sender;
- (void)lfo2RateChanged:(id)sender;
- (void)lfo2TempoSyncChanged:(id)sender;
- (void)lfo2NoteDivisionChanged:(id)sender;
- (void)modSourceChanged:(id)sender;
- (void)modDestChanged:(id)sender;
- (void)modIntensityChanged:(id)sender;
- (void)arpEnableChanged:(id)sender;
- (void)arpRateChanged:(id)sender;
- (void)arpModeChanged:(id)sender;
- (void)arpOctavesChanged:(id)sender;
- (void)arpGateChanged:(id)sender;
- (void)updateFromHost:(NSTimer *)timer;

@end
