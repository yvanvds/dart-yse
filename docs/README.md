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
2. The Sphinx `builder-inited` hook in `source/conf.py` renders
   `source/api/patcher_objects.rst` from
   `source/_data/patcher_objects.json` via the Jinja template at
   `source/_templates/patcher_objects.rst.j2`. The JSON snapshot is
   shipped from the upstream libYSE engine — both bindings call the
   same `patcher::CreateObject` so the object list is identical.
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
    ├── conf.py           # Sphinx config + patcher_objects.rst render hook
    ├── index.rst         # Top-level TOC
    ├── _data/
    │   └── patcher_objects.json   # Upstream snapshot — patcher type metadata
    ├── _templates/
    │   └── patcher_objects.rst.j2 # Jinja template for the rendered reference page
    ├── _static/
    ├── intro/            # What is dart-yse? — install, mental_model, hello_sound
    ├── tutorials/        # Phase-by-phase walk-throughs (patcher fully written up)
    └── api/              # Per-subsystem RST pages
        ├── index.rst
        ├── _generated/   # Class pages emitted by tool/emit_api_rst.dart (gitignored)
        ├── patcher.rst   # Patcher / PHandle / Obj — hand-authored intro + includes
        ├── patcher_objects.rst   # Rendered from JSON snapshot (gitignored)
        └── ...           # core / sounds / channels / dsp / midi / music / ...
```

## Updating the patcher object reference

`source/_data/patcher_objects.json` is a snapshot of the upstream
engine's patcher metadata. To refresh it after upstream adds or
modifies an object:

1. In the `yse-soundengine` repository, run
   `python yse.py dump-patcher-meta` to regenerate
   `documentation/source/_data/patcher_objects.json` there.
2. Copy that file into `docs/source/_data/patcher_objects.json` in
   this repo.
3. Rebuild (`make html`). The Sphinx hook re-renders
   `source/api/patcher_objects.rst` from the new snapshot.

There is no need to keep a separate Dart-side dumper: the engine's
patcher object list is the same regardless of which binding calls
`createObject`.

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
