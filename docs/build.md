# Building and running

No hardware is required for anything on this page.

## Quickest route: the browser

Go to the FAUST Web IDE at <https://faustide.grame.fr>, paste the contents of a
`.dsp` file, paste `lib/icc.lib` into a second tab named `icc.lib`, and press
run. You get an auto-generated UI and audio through the browser.

This is the fastest way to reproduce the howling demonstration and needs
nothing installed.

## Local compiler

```bash
# Debian/Ubuntu
sudo apt-get install faust

# macOS
brew install faust
```

Verify:

```bash
make check
```

That compiles every design and is the only command that must pass before you
push.

## Generate source for embedding

```bash
make cpp     # build/*.cpp
make c       # build/*.c
make rust    # build/*.rs
```

The generated class has the standard FAUST interface — `init(sampleRate)`,
`compute(count, inputs, outputs)`, plus `buildUserInterface` for the controls.
Drop it into any host.

## Runnable applications

```bash
make jack    # JACK + GTK
make qt      # JACK + Qt
```

Or individually, for other hosts:

```bash
faust2juce  -I lib dsp/icc_two_zone.dsp    # JUCE plugin/standalone
faust2api   -I lib dsp/icc_two_zone.dsp    # embeddable DSP class
faust2caqt  -I lib dsp/icc_loop_demo.dsp   # macOS CoreAudio + Qt
```

## Offline rendering

To render a WAV through a design without any audio hardware:

```bash
faust2sndfile -I lib dsp/icc_loop_demo.dsp
./icc_loop_demo input.wav output.wav
```

This is the reliable path for producing figures and for capturing the moment a
loop starts to ring.

## Embedded targets

There is no `faust2stm32`. Two practical routes to Cortex-M:

- **Daisy** (`faust2daisy`) targets the STM32H750 through libDaisy, and is the
  closest thing to a supported STM32 path.
- **Generic C** (`make c`) plus hand integration with STM32 HAL and CMSIS-DSP.
  The generated code is plain C with no dynamic allocation, so this is
  mechanical, but you supply the I2S plumbing and the buffer management.

Both need an FPU. FAUST emits floating point only; there is no fixed-point
backend, so a fixed-point automotive DSP would require a rewrite rather than a
port.

## Sample rate

The designs are sample-rate agnostic and read `ma.SR` at init. 16 kHz is the
natural choice for voice ICC; the defaults were chosen with 16 kHz in mind but
work at 48 kHz.

One caveat: the `pospass` guard band scales with sample rate. At order 6 the
band below `SR/12` is not cleanly shifted — 1.3 kHz at 16 kHz, 4 kHz at 48 kHz.
If you run at 48 kHz and want low-frequency decorrelation, raise the filter
order.
