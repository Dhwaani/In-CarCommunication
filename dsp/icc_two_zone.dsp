//==============================================================================
// icc_two_zone.dsp — the full bidirectional ICC system.
//
//   in 0 : front microphone        out 0 : front loudspeakers (carries rear voice)
//   in 1 : rear microphone         out 1 : rear loudspeakers  (carries front voice)
//
// Front mic is reinforced into the REAR speakers; rear mic into the FRONT
// speakers. Both directions run independently through a loop-gain manager.
//
// What makes this different from two speakerphones
// ------------------------------------------------
// The two directions are not independent, because the cabin couples them. A
// component leaving the rear speaker reaches the rear microphone, is amplified
// into the front speaker, reaches the front microphone, and returns to the rear
// speaker. That is a closed ring, and its round-trip gain — not the gain of
// either direction alone — is what determines stability.
//
// Consequently the per-direction gain ceiling must be set from the ROUND-TRIP
// measurement, not from a one-way one. Halving the round-trip budget between
// the two directions is the usual convention and is what the defaults assume.
//
// Echo cancellation
// -----------------
// This design does not include an adaptive echo canceller; see docs/design.md
// for why that is a deliberate scope decision rather than an omission. If one
// is added, its reference must be taken at the marked tap points BELOW the
// frequency shifter — a shifted reference no longer matches what the
// loudspeaker emitted and the canceller will not converge.
//==============================================================================

declare name "ICC two zone";
declare author "Asmita Chakraborty";
declare license "MIT";

import("stdfaust.lib");
ic = library("icc.lib");

//---------------------------------------------------------------- controls ---
// One MSG figure for the whole ring. Measure it with dsp/icc_msg_probe.dsp.
msgDb       = hslider("h:[0]Stability/[0]round-trip MSG [unit:dB]",
                      18, 0, 40, 0.5);
marginDb    = hslider("h:[0]Stability/[1]safety margin [unit:dB]",
                      6, 0, 15, 0.5);
shiftHz     = hslider("h:[0]Stability/[2]freq shift [unit:Hz]", 4, 0, 8, 0.5);
maxDepthDb  = hslider("h:[0]Stability/[3]notch depth [unit:dB]", 12, 0, 20, 0.5);
promThresh  = hslider("h:[0]Stability/[4]prominence threshold [unit:dB]",
                      15, 6, 30, 0.5);
holdTime    = hslider("h:[0]Stability/[5]persistence [unit:s]",
                      0.20, 0.05, 1.0, 0.01);

gainFrontDb = hslider("h:[1]Levels/[0]front to rear gain [unit:dB]",
                      10, -20, 30, 0.5);
gainRearDb  = hslider("h:[1]Levels/[1]rear to front gain [unit:dB]",
                      10, -20, 30, 0.5);
agcTargetDb = hslider("h:[1]Levels/[2]speech target [unit:dB]",
                      -26, -50, -10, 0.5);

hpfHz       = hslider("h:[2]Voice/[0]mic highpass [unit:Hz]", 120, 60, 400, 5);
lpfHz       = hslider("h:[2]Voice/[1]mic lowpass [unit:Hz]", 6500, 3000, 8000, 100);
bypass      = checkbox("h:[2]Voice/[2]bypass icc");

nSlots      = 3;

//---------------------------------------------------------------- stages -----
// Microphone conditioning. The highpass matters more here than in a handset:
// road rumble and structural vibration sit below 100 Hz, carry no speech, and
// would otherwise be amplified straight into the loop where they consume gain
// margin for nothing.
micFront = fi.highpass(2, hpfHz) : fi.lowpass(2, lpfHz);
micRear  = fi.highpass(2, hpfHz) : fi.lowpass(2, lpfHz);

// Half the round-trip budget is assigned to each direction.
perDirectionMsg = msgDb / 2.0;

// One direction, from microphone to loudspeaker feed.
//
// The reference tap for a future echo canceller belongs between `preShift` and
// `freqShift` — see the note in the header.
direction(requestedDb) =
    ic.gainCeiling(perDirectionMsg, marginDb, requestedDb)
    : ic.speechAgc(agcTargetDb, 12.0)
    : ic.notchBank(nSlots, 32, 150.0, 6000.0, 14.0,
                   promThresh, holdTime, 60.0, maxDepthDb)
    : ic.freqShift(6, shiftHz)
    : fi.dcblocker;

// Bypass keeps the microphone conditioning but removes all loop management, so
// A/B comparison isolates the suppressor rather than the whole chain.
withBypass(d) = _ <: (_ * b), (d * (1.0 - b)) :> _
with {
    b = bypass : si.smooth(0.999);
};

//---------------------------------------------------------------- process ----
// Note the deliberate crossing: the front microphone drives output 1 (rear
// speakers) and the rear microphone drives output 0 (front speakers).
process(frontMic, rearMic) = toFrontSpeakers, toRearSpeakers
with {
    toRearSpeakers  = frontMic : micFront : withBypass(direction(gainFrontDb));
    toFrontSpeakers = rearMic  : micRear  : withBypass(direction(gainRearDb));
};
