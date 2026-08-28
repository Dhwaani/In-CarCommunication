# Tuning

Tune in this order. Each step assumes the ones above it are settled; doing them
out of order means re-tuning.

## Measure MSG — before anything else

Every other parameter depends on this number, and it cannot be guessed: it is a
property of the vehicle, the microphone placement and the loudspeaker response.

Run `dsp/icc_msg_probe.dsp`. Set the probe gain low, press **ping**, and watch
the **ring** meter. Below MSG the ring index falls after the chirp ends; above
MSG it holds or rises. Raise the gain in 1 dB steps until it stops falling.

Do not find MSG by listening for howling. By the time howling is audible you
are several dB past the stability boundary, and you will set the ceiling too
high.

Repeat with the cabin in its worst realistic configuration — windows up, seats
back, few occupants — because that is when `H` is largest.

## Set the ceiling

`marginDb` = 6 dB is the conventional starting point. Increase it if the cabin
configuration varies a lot; decrease it only if you have measured MSG across
every configuration you care about.

In `icc_two_zone.dsp` the MSG slider is the **round-trip** figure and is split
evenly between directions. If your installation is asymmetric — a rear
microphone much closer to a speaker than the front one, say — split it
manually instead by editing `perDirectionMsg`.

## 3. Prominence threshold

| Value | Behaviour |
|---|---|
| Below 10 dB | Fires on speech formants. Voice sounds hollow and phasey. |
| 15 dB (default) | Catches established modes, ignores speech. |
| Above 22 dB | Only fires once howling is well developed — too late to be useful. |

Test by talking through the system with the loop gain a few dB below MSG. If
the notches engage during normal speech, raise it.

## Persistence

The parameter that does the real work.

| Value | Behaviour |
|---|---|
| Below 0.1 s | Speech transients trigger it. |
| 0.2 s (default) | Reliable separation of modes from formants. |
| Above 0.5 s | Howling becomes audible before suppression engages. |

If you can only tune one parameter, tune this one.

## Notch depth and width

Depth 12 dB and width 60 Hz are good defaults.

Deeper notches are not better. Past about 15 dB the spectral hole becomes
audible on speech, and the mode is usually already controlled. If you find
yourself needing more than 15 dB, the real problem is that the gain ceiling is set too high.

Width should scale with the frequencies you expect: 60 Hz is generous at 300 Hz
and narrow at 4 kHz. If modes are concentrated at low frequency, reduce it.

## Frequency shift

Above about 6 Hz, sustained sounds — a passenger humming, music through the system — acquire an audible beating. Below 2 Hz there is not enough
decorrelation to matter.

Set it to 0 to A/B its contribution: raise the loop gain to the howling
threshold with the shifter off, then turn it on and see how much further it
can go.

## Slot count

Three slots handles most cabins. Each slot costs a full 32-band analyser, so
this is the parameter to cut first if CPU is tight.

If all three slots are permanently engaged, the ceiling is too high — notches
are a correction, not a substitute for gain management.

## Reference figure

On the default synthetic cabin (11 ms path, 310 Hz dominant mode, 9 dB
prominence) at 16 kHz, with three notch slots, 12 dB depth and a 4 Hz shift:

| | Maximum stable gain |
|---|---|
| Suppressor bypassed | +4 dB |
| Suppressor engaged | +16 dB |
| **Added stable gain** | **12 dB** |

Because the cabin path is normalised to 0 dB peak, these numbers are loop gains at the worst frequency — MSG of +4 dB means the bare loop tolerates 4 dB of excess gain before the 310 Hz mode sustains.

Use this as a regression check: if your changes drop the added stable gain
below about 8 dB, something has broken.

## Common symptoms

| Symptom | Cause |
|---|---|
| Voice sounds hollow or phasey during normal speech | Prominence threshold too low, or persistence too short |
| Howling audible before suppression engages | Persistence too long |
| Notches chatter in and out | Release too fast; raise persistence, which also lengthens release |
| System howls with all slots engaged | Ceiling too high — lower it, do not add slots |
| Beating or vibrato on sustained sounds | Frequency shift too large |
| Low-frequency content not shifted | Below the `pospass` guard band; expected, see design.md |
