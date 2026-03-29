FC = mpifort
INCDIR = $(shell pkg-config --variable=includedir futile)
FCFLAGS = -O2 -g -fopenmp -fallow-argument-mismatch -I$(INCDIR) $(shell pkg-config --cflags futile)
LDFLAGS = $(shell pkg-config --libs futile)

PROGRAMS = test_dict test_memory test_errors test_yaml_io

all: $(PROGRAMS)

%: %.f90
	$(FC) $(FCFLAGS) -o $@ $< $(LDFLAGS)

run: $(PROGRAMS)
	@for p in $(PROGRAMS); do \
		echo ""; \
		echo "========== Running $$p =========="; \
		./$$p; \
	done

clean:
	rm -f $(PROGRAMS)

.PHONY: all run clean
