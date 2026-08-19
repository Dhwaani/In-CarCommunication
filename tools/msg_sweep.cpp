/* tools/msg_sweep.cpp — measure maximum stable gain, with and without the
 suppressor, and report the difference.

 Build and run:
     make msg-sweep

 Method: excite the loop with one impulse, run six seconds, and measure the
 RMS of a window four and a half seconds later. Below MSG the loop's response
 has decayed into nothing by then; at or above MSG it is still ringing.

 The threshold is deliberately an ABSOLUTE level, not a late/early ratio. A
 ratio is useless at both ends of the sweep: when everything decays to the
 denormal floor the ratio is ~0 dB, and when the loop clips against the
 loudspeaker saturation the ratio is ~0 dB again. Absolute level separates
 those two cases cleanly.
*/

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <string>
#include <vector>

#define FAUSTFLOAT float

struct Meta { void declare(const char*, const char*) {} };

// Minimal UI collector: grabs pointers to the two numeric entries by name.
struct UI {
    float* g = nullptr;
    float* s = nullptr;
    void openVerticalBox(const char*) {}
    void openHorizontalBox(const char*) {}
    void openTabBox(const char*) {}
    void closeBox() {}
    void declare(FAUSTFLOAT*, const char*, const char*) {}
    void addButton(const char*, FAUSTFLOAT*) {}
    void addCheckButton(const char*, FAUSTFLOAT*) {}
    void addVerticalSlider(const char*, FAUSTFLOAT*, FAUSTFLOAT, FAUSTFLOAT, FAUSTFLOAT, FAUSTFLOAT) {}
    void addHorizontalSlider(const char*, FAUSTFLOAT*, FAUSTFLOAT, FAUSTFLOAT, FAUSTFLOAT, FAUSTFLOAT) {}
    void addNumEntry(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT, FAUSTFLOAT, FAUSTFLOAT, FAUSTFLOAT) {
        if (std::string(label) == "g") g = zone;
        if (std::string(label) == "s") s = zone;
    }
    void addHorizontalBargraph(const char*, FAUSTFLOAT*, FAUSTFLOAT, FAUSTFLOAT) {}
    void addVerticalBargraph(const char*, FAUSTFLOAT*, FAUSTFLOAT, FAUSTFLOAT) {}
    void addSoundfile(const char*, const char*, void**) {}
};

struct dsp { virtual ~dsp() {} };

#include "msg_sweep_generated.cpp"

static const int    SR        = 16000;
static const double HOWL_DBFS = -60.0;   // above this, the loop is sustaining

static double lateRms(float gainDb, float suppressor) {
    ICCSWEEP d;
    UI ui;
    d.init(SR);
    d.buildUserInterface(&ui);
    if (!ui.g || !ui.s) { std::fprintf(stderr, "control lookup failed\n"); return 0.0; }
    *ui.g = gainDb;
    *ui.s = suppressor;

    const int N = SR * 6;
    std::vector<float> buf(N);
    float* out[1];
    const int BLOCK = 64;
    for (int i = 0; i < N; i += BLOCK) {
        out[0] = &buf[i];
        d.compute(std::min(BLOCK, N - i), nullptr, out);
    }

    const int a = int(SR * 4.5), b = int(SR * 5.5);
    double e = 0.0;
    for (int i = a; i < b; ++i) e += double(buf[i]) * buf[i];
    return 10.0 * std::log10(e / (b - a) + 1e-30);
}

int main() {
    std::printf("  loop gain     bypassed     suppressed   (late RMS, dBFS)\n");
    std::printf("  ---------------------------------------------------------\n");
    float msgBypass = 1e9f, msgSuppressed = 1e9f;
    for (float g = -8.0f; g <= 24.001f; g += 1.0f) {
        double b = lateRms(g, 0.0f);
        double s = lateRms(g, 1.0f);
        if (b > HOWL_DBFS && msgBypass    > 1e8f) msgBypass    = g;
        if (s > HOWL_DBFS && msgSuppressed > 1e8f) msgSuppressed = g;
        std::printf("  %8.1f   %10.1f   %12.1f%s\n", g, b, s,
                    (b > HOWL_DBFS && s <= HOWL_DBFS) ? "   <- suppressor holding" : "");
    }
    std::printf("\n  MSG bypassed      %+6.1f dB\n", msgBypass);
    std::printf("  MSG suppressed    %+6.1f dB\n", msgSuppressed);
    std::printf("  ADDED STABLE GAIN %6.1f dB\n\n", msgSuppressed - msgBypass);
    if (msgSuppressed - msgBypass < 8.0f) {
        std::printf("  WARNING: below the 8 dB regression floor in docs/tuning.md\n");
        return 1;
    }
    std::printf("  PASS (>= 8 dB regression floor)\n");
    return 0;
}
