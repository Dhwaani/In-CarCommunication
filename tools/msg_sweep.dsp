//==============================================================================
// tools/msg_sweep.dsp — headless version of the loop demo for measurement.
//
// Identical processing to dsp/icc_loop_demo.dsp, but with the controls exposed
// as numeric entries instead of sliders and the excitation reduced to a single
// impulse, so tools/msg_sweep.cpp can drive it without a UI and sweep the loop
// gain automatically.
//
// This is what backs the "12 dB of added stable gain" figure in the README.
//==============================================================================

declare name "ICC MSG sweep";
declare license "MIT";

import("stdfaust.lib");
ic = library("icc.lib");

gainDb = nentry("g", -12, -60, 40, 0.1);   // loop gain under test
sup    = nentry("s",   0,   0,  1, 1);     // 0 = bypass, 1 = suppressor on

chain = _ <: (_ * (1.0 - sup)), (managed * sup) :> _
with {
    managed = ic.notchBank(3, 32, 150.0, 6000.0, 14.0, 15.0, 0.20, 60.0, 12.0)
            : ic.freqShift(6, 4.0);
};

path = ic.cabinPath(11.0, 310.0, 9.0, 4200.0);

// A single unit impulse. An impulse is the right excitation for a stability
// test: what matters is whether the loop's own response decays or sustains,
// and continuous excitation masks exactly that.
impulse = 1 - 1' : *(0.5);

process = impulse : ic.closedLoop(chain, path, gainDb) : fi.dcblocker;
