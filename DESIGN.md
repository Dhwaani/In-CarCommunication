# Design

## What ICC is, and why it is not a speakerphone

In-car communication reinforces speech between rows of a vehicle: a microphone
near the driver is amplified into the rear loudspeakers, and vice versa. It is
standardised in ITU-T P.1150.

The temptation is to treat this as two speakerphones. It is not, and the
difference is the entire engineering problem.

In a speakerphone the far end is acoustically isolated — usually a headset in
another building. The echo path is one-way: loudspeaker to microphone, once.
An acoustic echo canceller models that path and subtracts it.

In ICC the "far end" is the same cabin. A component leaving the rear
loudspeaker reaches the rear microphone, is amplified into the front
loudspeaker, reaches the front microphone, and returns to the rear
loudspeaker. **The loop is closed.** If round-trip gain reaches unity at any
frequency with the right phase, the system oscillates — it howls.

This is a feedback control problem, and it is governed by the Nyquist
criterion, not by how good the echo canceller is. An AEC reduces the
*correlated* portion of the returning signal; it does not guarantee that the
residual loop gain is below unity. A perfectly converged AEC in a poorly
gain-managed cabin still howls.

So this library concentrates on the part ICC needs and a conventional voice
front end does not: keeping the loop stable while giving away as little gain as
possible.

## Stability budget

Write the round-trip gain as

```
L(f) = G_front(f) · H_rear→front(f) · G_rear(f) · H_front→rear(f)
```

`G` is ours; `H` is the cabin's. Stability requires `|L(f)| < 1` everywhere,
and in practice with margin, because `H` changes as occupants move, windows
open and seats recline.

Three mechanisms reduce `|L(f)|`, and the library provides all three because
each fails differently:

| Mechanism | What it does | Cost | Fails when |
|---|---|---|---|
| Gain ceiling | Scales all of `G` down | Loses reinforcement everywhere | Nothing — it always works, which is why it is first |
| Adaptive notches | Removes `G` only at the offending frequencies | Small spectral holes | More modes appear than there are slots |
| Decorrelation | Breaks the phase coherence the loop needs | Tiny frequency shift | Very reverberant cabins where the shift is smeared |

The gain ceiling is the guarantee; the other two buy back gain the ceiling
would otherwise cost.

## Why a filterbank instead of an FFT

The howling detector must find a narrowband peak. The obvious implementation
is an STFT and an argmax over bins, and that is what the ICC literature does.

In FAUST it is the wrong choice. FAUST is a sample-rate language; its compiler
expands `an.fft` into a scalar butterfly graph, which is heavy in code size and
compile time and awkward to drive at frame rate. A bank of resonant bandpass
filters, each with an envelope follower, measures the same thing, is idiomatic,
and costs a handful of biquads per band.

The library uses 32 log-spaced bands from 150 Hz to 6 kHz with Q = 14. Log
spacing is used because feedback modes are no more likely at high frequency
than low, but the notch bandwidth needed to remove one without audible damage
scales with frequency.

## Distinguishing a howl from a formant

Both are narrowband spectral peaks. The detector uses two tests and requires
both:

1. **Prominence.** The peak must stand a threshold (default 15 dB) above the
   *mean of the analysis bands*. The mean, not a broadband RMS: a broadband
   measure is dominated by low-frequency speech energy, so a genuine howl at
   3 kHz would barely move it.

2. **Persistence.** The condition must hold for a minimum time (default
   200 ms). This is the test that actually separates the two. Speech formants
   move within tens of milliseconds; a feedback mode is pinned to a room
   resonance and sits still.

Persistence is implemented as asymmetric smoothing of the boolean condition —
`an.amp_follower_ar(holdTime, 4·holdTime)` — rather than as a counter. The
rising time constant *is* the persistence requirement, and the slower fall
prevents a mode that is only intermittently excited from chattering the notch
in and out. It also produces a continuous confidence value rather than a
boolean, so the notch can be faded in instead of switched, which would click.

## Slot allocation without a scheduler

A bank of notches needs to decide which notch handles which mode. Doing this
explicitly requires arbitration: tracking which slots are busy, which mode each
is on, when to reassign.

The library sidesteps it. `notchBank` is a **cascade**, not a parallel bank.
Each slot runs its own detector on the output of the slot before it. Slot 1
removes the strongest mode; slot 2 then sees a signal in which that mode is
already gone, so its argmax naturally lands on the next strongest. Allocation
is emergent and needs no state.

This also degrades gracefully: with more modes than slots, the slots hold the
worst offenders and the gain ceiling absorbs the rest.

## Why the frequency shifter must be last

`fi.hilbert` is only a comment in the FAUST standard library, not a callable
function. The supported route to an analytic signal is `fi.pospass`, which
filters out negative frequencies; multiplying by a complex sinusoid then shifts
every component by a fixed number of Hz.

A 3–5 Hz shift is inaudible on speech but destroys the coherence a feedback
loop needs to accumulate, because a component returns to the microphone at a
slightly different frequency each time round. It is worth several dB of stable
gain for essentially no perceptual cost.

It must be the **final** stage before the loudspeaker. If an echo canceller is
added later, its reference has to match what the loudspeaker actually emitted.
Tapping the reference after the shifter gives the canceller a signal that no
longer corresponds to the acoustic output, and it will not converge. Tap before
the shifter; put the shifter last.

`pospass` also needs a guard band — its transition is not infinitely sharp, so
content below roughly `SR/(2·order)` is not cleanly separated. At order 6 and
16 kHz that is about 1.3 kHz, comfortably below the region where howling
usually occurs but worth knowing.

## What is deliberately not here

**There is no adaptive echo canceller.** This is a scope decision, not an
oversight.

FAUST has no NLMS/RLS/frequency-domain adaptive filter in its standard
libraries and no mature community implementation. A time-domain LMS is
expressible — it has been done for active noise control on FPGA — but a
robust, double-talk-aware canceller with a long tail is a project in itself and
would not be finished well.

More importantly, it is not what makes ICC interesting. The loop-gain problem
is specific to ICC; echo cancellation is shared with every speakerphone and is
already solved in production libraries. If you need one, use SpeexDSP or WebRTC AEC3 in C++ around the generated code, and tap the reference where this document says.

**There is no fixed-point path.** FAUST's code generator emits floating point
only. On a Cortex-M with an FPU this is fine; on a fixed-point automotive DSP
it is not, and that port would be a rewrite.

## Two details that only surface when you run it

**The cabin path is normalised to 0 dB peak magnitude.** Without this, the
resonance boost is silently added to every gain reading: a 9 dB cabin mode
makes the loop-gain slider read 9 dB low, and measured MSG lands at a
meaningless negative number. With the normalisation, `loopGainDb` means the
loop gain *at the worst frequency*, so the Nyquist condition |L| = 1 sits at
0 dB and MSG is directly interpretable.

**The loop includes a soft saturator.** An unstable linear feedback loop grows
without bound; in floating point that reaches infinity and then NaN within a
few seconds, at which point the simulation tells you nothing. Real systems
saturate. Modelling that is physically correct and is what makes howling
audible as a sustained tone rather than as a silent numerical failure.

## Cost

Computation is dominated by the 32-band analysis filterbanks, which scale linearly with the number of notch slots: $N_{\text{analysers}} = 2 \times N_{\text{slots}}$ (running once per direction).

To reduce CPU usage on resource-constrained targets:
- Reduce Slot Count: Reducing slots directly removes full 32-band filterbanks (e.g., dropping from 3 to 2 slots reduces analysis load by 33%).
- Reduce Band Count: Lowering resolution from 32 to 24 log-spaced bands cuts biquad evaluation cost across all active analysers.
