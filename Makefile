# ICC in FAUST — build targets.
#
# Nothing here requires hardware. `make check` compiles every design and is the
# only command that must pass before you push.

FAUST      ?= faust
DSPDIR     := dsp
LIBDIR     := lib
BUILDDIR   := build
FAUSTFLAGS := -I $(LIBDIR)

DSPS := $(wildcard $(DSPDIR)/*.dsp)
NAMES := $(notdir $(basename $(DSPS)))

.PHONY: help check standalone msg-sweep cpp c rust jack qt clean

help:
	@echo "make check   compile every design (syntax + arity). Run before pushing."
	@echo "make cpp     generate C++ into $(BUILDDIR)/"
	@echo "make c       generate C into $(BUILDDIR)/"
	@echo "make rust    generate Rust into $(BUILDDIR)/"
	@echo "make jack    build runnable JACK/GTK apps (needs faust2jack)"
	@echo "make qt      build runnable JACK/Qt apps (needs faust2jaqt)"
	@echo "make standalone  self-contained .dsp files for the FAUST Web IDE"
	@echo "make msg-sweep   measure added stable gain (needs a C++ compiler)"
	@echo "make clean   remove $(BUILDDIR)/"
	@echo ""
	@echo "No hardware required for any of the above."

check:
	@fail=0; \
	for f in $(DSPS); do \
	  printf '%-32s ' "$$f"; \
	  if $(FAUST) $(FAUSTFLAGS) $$f -o /dev/null 2>/tmp/faust_err.txt; then \
	    echo OK; \
	  else \
	    echo FAIL; sed -n '1,6p' /tmp/faust_err.txt; fail=1; \
	  fi; \
	done; \
	exit $$fail

$(BUILDDIR):
	@mkdir -p $(BUILDDIR)

# One-file versions with the library inlined, for pasting into the Web IDE.
standalone: | $(BUILDDIR)
	@for f in $(DSPS); do \
	  n=$$(basename $$f .dsp); \
	  python3 tools/inline_lib.py $$f > $(BUILDDIR)/$${n}_standalone.dsp && \
	  echo "wrote $(BUILDDIR)/$${n}_standalone.dsp"; \
	done

cpp: | $(BUILDDIR)
	@for f in $(DSPS); do \
	  n=$$(basename $$f .dsp); \
	  $(FAUST) $(FAUSTFLAGS) -lang cpp $$f -o $(BUILDDIR)/$$n.cpp && echo "wrote $(BUILDDIR)/$$n.cpp"; \
	done

c: | $(BUILDDIR)
	@for f in $(DSPS); do \
	  n=$$(basename $$f .dsp); \
	  $(FAUST) $(FAUSTFLAGS) -lang c $$f -o $(BUILDDIR)/$$n.c && echo "wrote $(BUILDDIR)/$$n.c"; \
	done

rust: | $(BUILDDIR)
	@for f in $(DSPS); do \
	  n=$$(basename $$f .dsp); \
	  $(FAUST) $(FAUSTFLAGS) -lang rust $$f -o $(BUILDDIR)/$$n.rs && echo "wrote $(BUILDDIR)/$$n.rs"; \
	done

jack:
	@for f in $(DSPS); do faust2jack $(FAUSTFLAGS) $$f; done

qt:
	@for f in $(DSPS); do faust2jaqt $(FAUSTFLAGS) $$f; done

# Measures maximum stable gain with and without the suppressor and reports the
# difference. This is what backs the figure quoted in README and docs/tuning.md;
# it exits non-zero if added stable gain falls below the 8 dB regression floor.
msg-sweep: | $(BUILDDIR)
	@$(FAUST) $(FAUSTFLAGS) -lang cpp -cn ICCSWEEP tools/msg_sweep.dsp \
	    -o $(BUILDDIR)/msg_sweep_generated.cpp
	@$(CXX) -O2 -std=c++17 -I$(BUILDDIR) tools/msg_sweep.cpp -o $(BUILDDIR)/msg_sweep
	@$(BUILDDIR)/msg_sweep

clean:
	@rm -rf $(BUILDDIR)
	@rm -f $(DSPDIR)/*.cpp $(DSPDIR)/*.o
