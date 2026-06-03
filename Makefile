# typst c --help | grep -A 6 -- --timings
# typst c main.typ --timings --jobs 1

# nix --extra-experimental-features "nix-command flakes" run github:typst/typst -- compile \
#  --pdf-standard a-1b \  # or use a-3b
#  --input date="`date`" \


# Select typst backend: nix, docker, or local
# Override from command line: `make TYPST_BACKEND=docker`
TYPST_BACKEND ?= nix

# Typst version for nix backend
# Override from command line: `make TYPST_VERSION=ec2389e`
TYPST_VERSION ?= ec2389e  # typst 0.14.2

# Configure TYPST command based on selected backend
ifeq ($(TYPST_BACKEND),nix)
    TYPST_FLAKE := github:typst/typst-flake/$(TYPST_VERSION)
    TYPST := nix run $(TYPST_FLAKE) --
else ifeq ($(TYPST_BACKEND),docker)
    TYPST := docker run --rm -v "$(PWD)":/work -w /work ghcr.io/typst/typst:latest
else ifeq ($(TYPST_BACKEND),local)
    TYPST := typst
else
    $(error Invalid TYPST_BACKEND: $(TYPST_BACKEND). Valid options: nix, docker, local)
endif


default: c t

c:
	$(TYPST) compile main.typ

report:
	$(TYPST) c main.typ --timings --jobs 1

w:
	$(TYPST) watch main.typ

o: open

open:
	xdg-open ./main.pdf

t: thumbnail

thumbnail:
	$(TYPST) compile --root=. -f png --pages 1,2,3,4,5 --ppi 250 ./main.typ ./thumbnail-page-{0p}.png

clean:
	rm -fr ./*.pdf ./*.png
