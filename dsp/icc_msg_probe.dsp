//==============================================================================
// icc_msg_probe.dsp — measure the maximum stable gain of an installation.
//
// Every other parameter in this project depends on knowing MSG. It is the one
// number that cannot be guessed, because it is a property of the vehicle, the
// microphone placement and the loudspeaker response, not of the algorithm.
//
// Procedure
// ---------
//   1. Set "probe gain" well below the expected MSG.
//   2. Press "ping". A short chirp excites the loop.
//   3. Watch the "ring" meter. Below MSG the energy decays after the chirp
//      ends; above MSG it sustains or grows.
//   4. Raise the probe gain in 1 dB steps and repeat until the meter stops
//      decaying. That value is MSG.
//
// Use a chirp, not noise: a decaying tail is unambiguous after an impulsive
// excitation and nearly impossible to judge under continuous excitation.
//
// The "ring" meter reports the ratio of energy in a late window to energy in an
// early one, so a value above 0 dB means the loop is sustaining. That is a far
// more reliable indicator than listening for the onset of howling, which is
// already several dB past the stability boundary by the time it is audible.
//==============================================================================

declare name "ICC MSG probe";
declare author "Aashmita Chakraborty";
declare license "MIT";

import("stdfaust.lib");
ic = library("icc.lib");

probeGainDb = hslider("[0]probe gain [unit:dB]", -20, -40, 20, 0.5) : si.smooth(0.999);
delayMs     = hslider("[1]path delay [unit:ms]", 11, 4, 30, 0.5);
resFreq     = hslider("[2]dominant mode [unit:Hz]", 310, 120, 900, 5);
resGainDb   = hslider("[3]mode prominence [unit:dB]", 9, 0, 18, 0.5);
ping        = button("[4]ping");

// Rising chirp through the voice band.
chirp = os.osc(f) * en.ar(0.005, 0.10, ping) * 0.4
with {
    f = 200.0 + 3000.0 * (en.ar(0.005, 0.30, ping));
};

path = ic.cabinPath(delayMs, resFreq, resGainDb, 4200.0);
loop = (+ : _) ~ (path : *(ba.db2linear(probeGainDb)));

// Ring index: late energy over early energy, in dB. Above 0 the loop sustains.
ringIndex(x) = 20.0 * log10((late + eps) / (early + eps))
with {
    eps   = 1e-9;
    early = x : abs : an.amp_follower_ar(0.005, 0.08);
    late  = x : abs : an.amp_follower_ar(0.005, 0.80);
};

process = chirp : loop : fi.dcblocker
        <: attach(_, ringIndex : hbargraph("[5]ring [unit:dB]", -30, 30)) , _;
