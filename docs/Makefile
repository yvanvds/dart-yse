# Convenience targets for building the dart-yse documentation.
#
#   make html        # full build: generate API RST + sphinx HTML
#   make api         # only regenerate API RSTs from lib/yse.dart sources
#   make sphinx      # only rebuild Sphinx HTML (assumes API RSTs are current)
#   make serve       # python http server on http://localhost:8000
#   make clean       # delete build/ and source/api/_generated/

SPHINXBUILD ?= sphinx-build
SOURCEDIR    = source
BUILDDIR     = build
DART         ?= dart

.PHONY: html api sphinx serve clean help

html: api sphinx

api:
	cd .. && $(DART) run tool/emit_api_rst.dart \
	  --out docs/source/api/_generated

sphinx:
	$(SPHINXBUILD) -b html "$(SOURCEDIR)" "$(BUILDDIR)/html"

serve:
	@echo "Serving on http://localhost:8000 (Ctrl-C to stop)"
	@cd $(BUILDDIR)/html && python -m http.server 8000

clean:
	rm -rf "$(BUILDDIR)" "$(SOURCEDIR)/api/_generated" "$(SOURCEDIR)/api/patcher_objects.rst"

help:
	@echo "Targets: html, api, sphinx, serve, clean"
