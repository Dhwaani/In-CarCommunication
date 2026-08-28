# Verifying this on your machine

Three levels. Each proves something different, and they take 2 minutes, 10
minutes and 20 minutes respectively.

---

## Level 1 — hear it work (2 minutes, nothing installed)

Proves: the suppressor audibly holds a loop that would otherwise howl.

1. Go to <https://faustide.grame.fr>
2. Open `build/icc_loop_demo_standalone.dsp` in a text editor, select all, copy.
   (If `build/` is empty, run `make standalone` first, or use the Web IDE's own
   file panel to add `lib/icc.lib` alongside `dsp/icc_loop_demo.dsp`.)
3. Paste into the editor, press the run button, allow audio.
4. **Suppressor OFF.** Hold *talk* briefly, then raise *loop gain* a decibel at
   a time. Somewhere around +4 dB a tone near 310 Hz appears and sustains after
   you release the button. That is howling. Note the value.
5. Pull *loop gain* back down. Turn **suppressor ON**.
6. Raise *loop gain* again. It should stay clean roughly 12 dB higher.


`make standalone` inlines the library into a single file.

**What you should hear:** with the suppressor engaged, a brief ring that gets
cut off within a fraction of a second as a notch locks on. That truncation is
the detector's persistence timer expiring.

---

## Level 2 — compile everything (10 minutes)

On Windows, the shortest route is WSL:

```powershell
wsl --install -d Ubuntu     # once; reboot if prompted
wsl
```

Then inside Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y faust build-essential
cd /mnt/c/Users/<you>/path/to/faust-icc

make check        # every design compiles
make cpp          # C++ generation
make c            # C generation
make rust         # Rust generation
make standalone   # one-file versions for the Web IDE
```

`make check` is the gate. If it prints OK three times, the source is sound.

Native Windows alternative: install the FAUST Windows build from
<https://faust.grame.fr/downloads/> and run the compiler directly —
`faust -I lib dsp/icc_two_zone.dsp -o out.cpp`.

---

## Level 3 — reproduce the headline number (20 minutes)

Proves: the 12 dB of added stable gain is real and measured.

```bash
make msg-sweep
```

This compiles `tools/msg_sweep.dsp` to C++, links it against `tools/msg_sweep.cpp`, and sweeps the loop gain from −8 to +24 dB with the suppressor bypassed and engaged. It prints a table and a verdict.

Expected:

```
  MSG bypassed        +4.0 dB
  MSG suppressed     +16.0 dB
  ADDED STABLE GAIN   12.0 dB

  PASS (>= 8 dB regression floor)
```

It exits non-zero if added stable gain falls below 8 dB, so it works as a
regression check after any change to the library.

### How the measurement works ?

We fire a single impulse into the loop, wait six seconds, and sample the RMS energy in a short window starting at 4.5 seconds.

Below Maximum Stable Gain (MSG), the impulse fully decays before the window opens. At or above MSG, the loop keeps ringing, raising the energy reading. We measure this against a fixed threshold (−60 dBFS) rather than a relative ratio—relative ratios fail when signals hit either silence or hard speaker clipping, whereas an absolute cutoff cleanly distinguishes stable decay from feedback.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `library("icc.lib") not found` | Missing `-I lib`. Use the Makefile, or a standalone file in the Web IDE. |
| Web IDE compiles but is silent | Browser audio permission not granted; check the tab is not muted. |
| No howling even at +24 dB bypassed | Output trim too low to hear it — the loop is still ringing. Check the sweep numbers rather than your ears. |
| `make msg-sweep` fails to link | No C++ compiler. `sudo apt-get install build-essential`. |
| Added stable gain below 8 dB | A real regression. Check `promThresh` and `holdTime` against `docs/tuning.md`. |
| Sweep prints `-nan` | Should not happen — `ic.loudspeakerSat` bounds the loop. If it does, the saturator has been removed or bypassed. |

---

## What none of this proves

All tests run against a synthetic cabin model (a simple delay plus two resonances). While the 12 dB gain increase is a real measurement, it is a measurement against a model, not a physical vehicle.

True production readiness requires testing against measured acoustic impulse responses from a real car interior by swapping ic.cabinPath for a full convolution. That step remains to be done.
