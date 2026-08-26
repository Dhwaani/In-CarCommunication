/*==============================================================================
 icc_loop_demo.dsp

 A single ICC direction enclosed in a synthetic cabin feedback loop, with the
 loop gain exposed as a slider and the suppressor switchable in and out.

 How to run the experiment
 -------------------------
   1. Leave "suppressor" OFF. Raise "loop gain" slowly until the tone appears
      and grows. Note that value: it is the maximum stable gain (MSG) of the
      bare system.
   2. Pull the loop gain back until it is quiet again. Turn "suppressor" ON.
   3. Raise the loop gain again. Note the new howling threshold.

 The difference between the two thresholds is the added stable gain, which is
 the figure of merit for the whole design. Expect roughly 10-12 dB.

 The excitation is a short speech-like burst rather than continuous noise,
 because a continuous source masks the onset of ringing and makes the
 threshold hard to locate by ear.
==============================================================================*/

declare name "ICC loop demo";
declare author "Aasmita Chakraborty";
declare license "MIT";

import("stdfaust.lib");
ic = library("icc.lib");

//---------------------------------------------------------------- controls ---
loopGainDb  = hslider("h:[0]Cabin/[0]loop gain [unit:dB] [style:knob]",
                      -12, -40, 12, 0.25) : si.smooth(0.999);
delayMs     = hslider("h:[0]Cabin/[1]path delay [unit:ms]", 11, 4, 30, 0.5);
resFreq     = hslider("h:[0]Cabin/[2]dominant mode [unit:Hz]", 310, 120, 900, 5);
resGainDb   = hslider("h:[0]Cabin/[3]mode prominence [unit:dB]", 9, 0, 18, 0.5);

suppress    = checkbox("h:[1]Suppressor/[0]suppressor on");
nSlots      = 3;                 // compile-time: notch slots in the cascade
shiftHz     = hslider("h:[1]Suppressor/[1]freq shift [unit:Hz]", 4, 0, 8, 0.5);
maxDepthDb  = hslider("h:[1]Suppressor/[2]notch depth [unit:dB]", 12, 0, 20, 0.5);
promThresh  = hslider("h:[1]Suppressor/[3]prominence threshold [unit:dB]",
                      15, 6, 30, 0.5);
holdTime    = hslider("h:[1]Suppressor/[4]persistence [unit:s]",
                      0.20, 0.05, 1.0, 0.01);

excite      = button("h:[2]Source/[0]talk");
outLevelDb  = hslider("h:[2]Source/[1]output trim [unit:dB]", -6, -40, 6, 0.5)
              : si.smooth(0.999);

//---------------------------------------------------------------- source -----
// A band-limited burst, gated by the button and shaped with a short envelope.
// Filtered noise stands in for speech: it excites every cabin mode at once,
// which is what you want when hunting for the one that rings.
talkBurst = no.noise
          : fi.bandpass(2, 200, 3400)
          : *(en.ar(0.02, 0.35, excite))
          : *(0.35);

//---------------------------------------------------------------- chain ------
// The processing enclosed by the loop. With the suppressor bypassed this is a
// bare gain, which is the honest comparison: the question is how much gain the
// loop tolerates, not how good the speech sounds.
chain = _ <: (bypassed * (1.0 - s)), (managed * s) :> _
with {
    s = suppress : si.smooth(0.999);
    bypassed = _;
    managed  = ic.notchBank(nSlots, 32, 150.0, 6000.0, 14.0,
                            promThresh, holdTime, 60.0, maxDepthDb)
             : ic.freqShift(6, shiftHz);
};

path = ic.cabinPath(delayMs, resFreq, resGainDb, 4200.0);

//---------------------------------------------------------------- process ----
// The talk burst is injected into the loop; what comes out is what a passenger
// in the receiving zone would hear, including any howling.
process = talkBurst : loop : *(ba.db2linear(outLevelDb)) : fi.dcblocker <: _,_
with {
    loop = (+ : chain) ~ (path : *(ba.db2linear(loopGainDb)));
};
