# faust-icc

**In-car communication in FAUST: adaptive howling suppression for closed acoustic loops.**

[![FAUST](https://img.shields.io/badge/FAUST-2.70%2B-orange.svg)](https://faust.grame.fr)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![hardware](https://img.shields.io/badge/hardware-none%20required-green.svg)](#no-hardware-required)

```bash
make check          # compiles every design
```

Or paste `dsp/icc_loop_demo.dsp` and `lib/icc.lib` into
<https://faustide.grame.fr> and press run. Nothing to install.

---

## The problem

In-car communication (ITU-T P.1150) reinforces speech between rows of a
vehicle: a microphone near the driver is amplified into the rear loudspeakers,
and vice versa.

The tempting model is "two speakerphones". It is wrong, and the difference is
the whole engineering problem.

A speakerphone's far end is acoustically isolated, so the echo path is one-way
and an echo canceller models it. In a car the far end is **the same cabin**. A
component leaving the rear speaker reaches the rear mic, is amplified into the
front speaker, reaches the front mic, and returns to the rear speaker. The loop
is closed, and when its round-trip gain reaches unity at any frequency, the
system howls.

That is a feedback control problem governed by the Nyquist criterion. A
perfectly converged echo canceller in a badly gain-managed cabin still howls.

## What this is

A FAUST library for the part ICC needs and a conventional voice front end does
not: **keeping the loop stable while giving away as little gain as possible.**

Three mechanisms, because each fails differently:

| | Reduces loop gain by | Costs | Provided by |
|---|---|---|---|
| **Gain ceiling** | scaling everything down | reinforcement everywhere | `ic.gainCeiling` |
| **Adaptive notches** | removing only the offending frequencies | small spectral holes | `ic.notchBank` |
| **Decorrelation** | breaking the loop's phase coherence | a few Hz of frequency shift | `ic.freqShift` |

The ceiling is the guarantee. The other two buy back gain it would otherwise
cost.

## Two design decisions worth knowing

**The howling detector uses a filterbank, not an FFT.** FAUST is a sample-rate
language and expands `an.fft` into a scalar butterfly graph — heavy, and
awkward to drive at frame rate. A bank of resonant bandpass filters with
envelope followers measures the same thing idiomatically. 32 log-spaced bands
replace the STFT the literature uses.

**Notch slots allocate themselves.** `notchBank` is a *cascade*, not a parallel
bank with a scheduler. Each slot detects on the output of the one before it, so
slot 1 takes the strongest mode, slot 2 then sees a signal with that mode
already gone and lands on the next. No arbitration state, and it degrades
gracefully when there are more modes than slots.

## Telling a howl from a vowel

Both are narrowband peaks. The detector requires two conditions:

- **Prominence** — the peak stands 15 dB above the *mean of the analysis bands*
  (not a broadband RMS, which low-frequency speech energy would dominate).
- **Persistence** — it holds for 200 ms. This is the test that does the real
  work: formants move within tens of milliseconds; a feedback mode is pinned to
  a room resonance and sits still.

Persistence is asymmetric smoothing of the boolean condition rather than a
counter, so it yields a continuous confidence value and the notch fades in
instead of switching, which would click.

## The demonstration

`dsp/icc_loop_demo.dsp` puts one ICC direction inside a synthetic cabin.

1. Suppressor **off**. Raise **loop gain** until the tone appears. That is the
   bare maximum stable gain.
2. Back off, suppressor **on**, raise again.

The difference is the added stable gain — the figure of merit for the whole
design.

On the default cabin at 16 kHz this measures **+4 dB bypassed, +16 dB
suppressed: 12 dB of added stable gain.** Because the cabin path is normalised
to 0 dB peak magnitude, those are loop gains at the worst frequency, so the
Nyquist condition |L| = 1 sits at 0 dB and the numbers mean something physical.

## Files

```
faust-icc/
├── lib/icc.lib              the library — all reusable blocks
├── dsp/
│   ├── icc_loop_demo.dsp    one direction + synthetic cabin  (start here)
│   ├── icc_two_zone.dsp     full bidirectional ICC system
│   └── icc_msg_probe.dsp    measure maximum stable gain      (run this first)
├── docs/
│   ├── design.md            architecture and why it is shaped this way
│   ├── tuning.md            parameter guide, in the order to tune them
│   └── build.md             browser, desktop, embedded
|   └── verify.md            verification
├── tools/
│   ├── inline_lib.py            
│   ├── msg_sweep.cpp       
│   └── msg_sweep.dsp     
└── Makefile
```

## Library reference

| Function | Purpose |
|---|---|
| `ic.gainCeiling(msgDb, marginDb, requestedDb)` | Hard ceiling relative to measured MSG |
| `ic.howlDetect(nBands, fmin, fmax, q, promThresh, holdTime)` | → (confidence, frequency, prominence) |
| `ic.notchSlot(...)` | One latching adaptive notch |
| `ic.notchBank(k, ...)` | Cascade of `k` self-allocating slots |
| `ic.freqShift(order, shiftHz)` | Decorrelation by frequency shift |
| `ic.phaseModDelay(depthMs, rateHz)` | Cheaper decorrelation fallback |
| `ic.speechAgc(targetDb, maxGainDb)` | Deliberately gentle level control |
| `ic.cabinPath(delayMs, resFreq, resGainDb, hfCutHz)` | Synthetic cabin transfer function |
| `ic.closedLoop(chain, path, loopGainDb)` | Wrap a chain in an acoustic loop |
| `ic.loudspeakerSat` | Soft saturation, so an unstable loop rings instead of reaching NaN |
| `ic.loopManager(...)` | Ceiling → notches → shift, in the correct order |

Stage order in `loopManager` is not arbitrary — see `docs/design.md`.

## No hardware required

Everything runs from a laptop. The cabin is synthesised as a delay plus a
coloured resonance, which is enough to produce a loop with identifiable modes
for the suppressor to find. Substituting a measured impulse response means
replacing one function.

## Scope: there is no echo canceller

Deliberate, not an oversight.

FAUST has no NLMS/RLS adaptive filter in its standard libraries and no mature
community implementation. More to the point, echo cancellation is shared with
every speakerphone and already solved in production libraries — it is not what
makes ICC interesting. If you need one, wrap SpeexDSP or WebRTC AEC3 around the
generated C++.

**If you do add one, tap its reference *before* the frequency shifter.** A
shifted reference no longer matches what the loudspeaker emitted and the
canceller will not converge. This is the easiest way to break the system.

## Limitations

- Floating point only. FAUST has no fixed-point backend, so a fixed-point
  automotive DSP is a rewrite, not a port.
- The `pospass` guard band leaves content below roughly `SR/(2·order)`
  unshifted — about 1.3 kHz at 16 kHz with order 6.
- The synthetic cabin is a caricature. It is adequate for developing and
  demonstrating the suppressor; it is not a substitute for measured data.
- More modes than slots means the ceiling absorbs the remainder. That is the intended behaviour, but it means the ceiling still has to be right.

## Related

[StabilityGAN](https://github.com/Dhwaani/StabilityGAN) — learns the notch
placement this library tunes by hand, by training against a differentiable
maximum-stable-gain surrogate.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

The FAUST standard library functions used here are under the MIT-style STK-4.3 licence.
