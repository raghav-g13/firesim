# Minimal makefile for Sphinx documentation
#

# You can set these variables from the command line.
SPHINXOPTS    = -w warnings.txt -n
SPHINXBUILD   = python3 -msphinx
SPHINXPROJ    = FireSim
SOURCEDIR     = .
BUILDDIR      = _build

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

clean:
	rm -r _build/html/*
	rm -r _build/doctrees/*

format:
	find $(SOURCEDIR) -name '*.rst' | xargs docstrfmt $(FORMAT_EXTRA_ARGS) -i -v

formatcheck: FORMAT_EXTRA_ARGS := --check
formatcheck: format

.PHONY: help Makefile clean format formatcheck

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
