# dart-yse documentation

Sphinx site for the `dart-yse` package — mirrors the upstream libYSE
docs (Doxygen + Sphinx + Breathe) in look and structure, but uses a
small Dart analyzer-based generator instead of Doxygen because the
wrapper is written in Dart.

Build pipeline:

1. `dart run tool/emit_api_rst.dart --out docs/source/api/_generated`
   walks every class re-exported from `lib/yse.dart` and emits one
   RST file per class into `docs/source/api/_generated/`. Dartdoc
   comments stay the canonical source of truth.
2. The Sphinx `builder-inited` hook in `source/conf.py` renders the
   patcher object reference — `source/api/patcher_objects/index.rst`
   plus one page per category — from `source/_data/patcher_objects.json`
   via the Jinja templates `patcher_objects_index.rst.j2` and
   `patcher_objects_category.rst.j2` in `source/_templates/` (ported
   from upstream libYSE). The JSON snapshot is generated from the bound
   engine's registry by `tool/gen_patcher_snapshot.dart` and committed,
   so the docs build needs no engine.
3. Sphinx + the `sphinx-book-theme` render the static site into
   `build/html/`.

## Building locally

You need Python ≥ 3.10 and the Dart SDK.

```sh
# One-off: install the Python build dependencies.
python -m pip install -r docs/requirements.txt

# Generate + render.
cd docs
make html          # Windows: make.bat html
make serve         # http://localhost:8000
```

Individual stages:

```sh
make api           # Only re-run tool/emit_api_rst.dart
make sphinx        # Only re-run sphinx-build (skip the Dart step)
make clean         # Wipe build/ and generated RST
```

Both `Makefile` and `make.bat` honour `SPHINXBUILD` and `DART`
environment variables for custom toolchain locations.

## What's where

```
docs/
├── Makefile              # POSIX entry point
├── make.bat              # Windows entry point
├── requirements.txt      # Python build deps (sphinx, sphinx-book-theme, myst-parser)
└── source/
    ├── conf.py           # Sphinx config + patcher object reference render hook
    ├── index.rst         # Top-level TOC
    ├── _data/
    │   └── patcher_objects.json   # Registry snapshot — patcher type metadata
    ├── _templates/
    │   ├── patcher_objects_index.rst.j2     # Object reference index page
    │   └── patcher_objects_category.rst.j2  # One page per category
    ├── _static/
    ├── intro/            # What is dart-yse? — install, mental_model, hello_sound
    ├── tutorials/        # Phase-by-phase walk-throughs (patcher fully written up)
    └── api/              # Per-subsystem RST pages
        ├── index.rst
        ├── _generated/   # Class pages emitted by tool/emit_api_rst.dart (gitignored)
        ├── patcher.rst   # Patcher / PHandle / Obj — hand-authored intro + includes
        ├── patcher_objects/      # Rendered from JSON snapshot (gitignored)
        └── ...           # core / sounds / channels / dsp / midi / music / ...
```

## Updating the patcher object reference

`source/_data/patcher_objects.json` is a snapshot of the patcher
registry of the `libyse` this package binds (the same JSON
`PatcherRegistry.metadataJson()` returns, with sorted keys). It is the
layout upstream's `python yse.py dump-patcher-meta` writes, so the two
diff cleanly. After an engine update:

1. Build the engine and point `YSE_DLL_PATH` at it (see the top-level
   README).
2. From the package root, run
   `dart run tool/gen_patcher_snapshot.dart` to rewrite the snapshot
   (and `dart run tool/gen_obj_constants.dart` for the `Obj`
   constants the reference pages show).
3. Rebuild (`make html`). The Sphinx hook re-renders
   `source/api/patcher_objects/` from the new snapshot.

`test/gen_patcher_snapshot_test.dart` fails when the committed snapshot
no longer matches the bound registry (object count, type names, or any
byte of the content), and when `_PATCHER_CATEGORIES` in `conf.py` misses
a `PCategory`. The docs build itself warns (failing `-W`) on an object
whose category `conf.py` does not know, or that has no `Obj` constant.

## Hosting

`.github/workflows/docs.yml` builds the site on every push to `main`
and publishes the contents of `docs/build/html/` to the `gh-pages`
branch via `peaceiris/actions-gh-pages`. The published site is at
`https://yvanvds.github.io/dart-yse/`.

## Cross-linking to upstream libYSE

The `:yse-cpp:` Sphinx role (defined via `sphinx.ext.extlinks` in
`source/conf.py`) resolves to the upstream libYSE docs site. When
the upstream URL moves, edit the `extlinks` dictionary in `conf.py`
in one place and every wrapper page picks up the new target.
