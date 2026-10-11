"""Sphinx configuration for the dart-yse documentation.

The build flow is:

    1. ``dart run tool/emit_api_rst.dart --out docs/source/api/_generated``
       walks the public surface re-exported from ``lib/yse.dart`` and emits
       one RST page per class. The script is driven from the ``api`` /
       ``html`` targets in :file:`Makefile` / :file:`make.bat`.
    2. The ``builder-inited`` hook below renders the patcher object
       reference (``source/api/patcher_objects/``: an index plus one page
       per category) from ``source/_data/patcher_objects.json`` via Jinja
       templates ported from the upstream libYSE docs.  The JSON snapshot
       is generated from the bound engine's registry by
       ``tool/gen_patcher_snapshot.dart`` and committed, so this step needs
       no engine.
    3. Sphinx + the sphinx-book-theme render the RST tree.

If the generated API directory is missing, the relevant Sphinx ``include``
directives will warn — run ``make api`` first, or just ``make html`` which
chains both steps.
"""

import json
import re
from pathlib import Path

# -- Project information -----------------------------------------------------

project = "dart-yse"
author = "Yvan Vander Sanden"
copyright = "2025-2026, Yvan Vander Sanden"


def _read_package_version():
    """Parse the ``version:`` field out of pubspec.yaml.

    Single source of truth for the docs banner — bumping pubspec.yaml is
    enough to refresh the rendered version.
    """
    pubspec = Path(__file__).resolve().parent.parent.parent / "pubspec.yaml"
    m = re.search(
        r"^version:\s*(\d+)\.(\d+)\.(\d+)",
        pubspec.read_text(encoding="utf-8"),
        flags=re.MULTILINE,
    )
    if not m:
        raise RuntimeError(
            f"version: literal not found in {pubspec}; docs build cannot "
            f"determine the release banner."
        )
    return m.group(1), m.group(2), m.group(3)


_major, _minor, _patch = _read_package_version()
version = f"{_major}.{_minor}"
release = f"{_major}.{_minor}.{_patch}"

# -- General configuration ---------------------------------------------------

extensions = [
    "myst_parser",
]

source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}

exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

# -- HTML output -------------------------------------------------------------

html_theme = "sphinx_book_theme"
html_title = f"dart-yse {version}"
html_static_path = ["_static"]

html_theme_options = {
    "repository_url": "https://github.com/yvanvds/dart-yse",
    "use_repository_button": True,
    "use_issues_button": True,
    "use_edit_page_button": False,
    "path_to_docs": "docs/source",
    "home_page_in_toc": True,
    "show_navbar_depth": 2,
}

# Cross-link to the upstream libYSE docs site so wrapper pages can point at
# the underlying C++ class they wrap. Update the URL when the upstream site
# moves; the role ``:cpp-doc:`YSE::patcher``` then resolves to a stable link.
# Sphinx's ``extlinks`` is part of the standard distribution.
extensions.append("sphinx.ext.extlinks")
extlinks = {
    "yse-cpp": (
        "https://yvanvds.github.io/yse-soundengine/%s",
        "%s",
    ),
}


# -- Auto-generated patcher reference -----------------------------------------
#
# The snapshot at _data/patcher_objects.json is generated from the registry
# of the libyse this package binds (``dart run tool/gen_patcher_snapshot.dart``,
# #69), in the same layout upstream's ``python yse.py dump-patcher-meta``
# writes.  test/gen_patcher_snapshot_test.dart fails when the committed
# snapshot drifts from the bound registry.  This hook turns the JSON into
# the RST pages Sphinx consumes, using templates ported from upstream
# (issue #870 there): an index plus one page per category.  Running the
# render inside ``builder-inited`` keeps every documentation build — local
# ``make html``, CI's docs.yml workflow — in lockstep with the committed
# JSON.  The rendered ``api/patcher_objects/`` directory is gitignored and
# cleared before each render, so a category that empties out leaves no
# orphaned page behind.
#
# Categories are listed in upstream's reading order (key, page slug, title,
# one-line summary).  The keys are the ``YsePCategory`` names the engine
# emits; test/gen_patcher_snapshot_test.dart checks this table covers every
# ``PCategory`` value.  ``UNSET`` is a fallback that should never reach the
# docs; an unknown key is reported as a warning (failing a ``-W`` build) and
# rendered under "Uncategorised".

_PATCHER_CATEGORIES = [
    ("OSC", "signal_generators", "Signal generators",
     "Audio-rate sources: oscillators, noise and ramps."),
    ("FILTER", "filters", "Filters",
     "Audio-rate filters."),
    ("MATH", "math", "Math",
     "Arithmetic, comparison, conversion, scaling and analysis of numbers."),
    ("RANDOM", "random", "Random",
     "Random numbers, random walks and probabilistic choices."),
    ("ROUTING", "routing", "Routing",
     "Steering messages between inlets and outlets."),
    ("CONTROL", "control_flow", "Control flow",
     "Ordering, looping, conditions and load-time messages."),
    ("LIST", "lists", "Lists",
     "Building lists, taking them apart and processing them."),
    ("STRING", "strings", "Strings and symbols",
     "Text, symbols and character codes."),
    ("COLLECTION", "collections", "Collections",
     "Stores that hold numbers or messages for later recall."),
    ("DICT", "dictionaries", "Dictionaries",
     "The ``.dict`` family: keyed, nested data."),
    ("ARRAY", "arrays", "Arrays",
     "The ``.array`` family: ordered data and the operations on it."),
    ("TIME", "time", "Time",
     "Clocks, delays, ramps, rate limiting and tempo."),
    ("SEQUENCE", "sequencing", "Sequencing",
     "Recording messages and playing them back in time."),
    ("MIDI", "midi", "MIDI",
     "Formatting, parsing and note handling for MIDI, and MIDI device I/O."),
    ("GUI", "gui", "GUI controls",
     "User-facing controls and message boxes, driven by the GUI value protocol."),
    ("IO", "input_output", "Input and output",
     "Audio in and out of the graph, named send/receive, and host-facing I/O."),
    ("ENCAPSULATION", "subpatchers", "Subpatchers",
     "Subpatchers and the inlets and outlets that form their boundary."),
    ("GENERIC", "other", "Other",
     "Objects that fit no other category."),
    ("UNSET", "uncategorised", "Uncategorised",
     "Objects without a category. This page should be empty."),
]

# Shown on every object flagged ``requires_midi_device`` in the snapshot.
_MIDI_DEVICE_NOTE = (
    "Only available when libYSE is built with ``YSE_ENABLE_MIDI_DEVICE`` "
    "(on by default on Windows and Linux desktop builds). On macOS and "
    "Android the option is off and this object is not registered, so a "
    "patch that uses it is not portable to those platforms. Check "
    "``PatcherObjectType.requiresMidiDevice`` or ``Obj.isValid`` at runtime."
)

# ``static const String dSine = '~sine';`` in the generated Obj class.
_OBJ_CONSTANT = re.compile(r"static const String (\w+) = '([^']*)';")


def _obj_constants(src_dir):
    """Return ``{type name: Obj constant}`` from lib/src/patcher_objects.dart."""
    path = src_dir.parent.parent / "lib" / "src" / "patcher_objects.dart"
    if not path.exists():
        return {}
    return {
        type_name: const
        for const, type_name in _OBJ_CONSTANT.findall(
            path.read_text(encoding="utf-8")
        )
    }


def _render_patcher_objects(app):
    """Render ``api/patcher_objects/*.rst`` from the JSON snapshot."""
    import jinja2  # Sphinx already depends on Jinja2; no extra requirement.
    from sphinx.util import logging as sphinx_logging

    logger = sphinx_logging.getLogger(__name__)

    src_dir = Path(app.srcdir)
    data_path = src_dir / "_data" / "patcher_objects.json"
    template_dir = src_dir / "_templates"
    out_dir = src_dir / "api" / "patcher_objects"

    if not data_path.exists():
        logger.warning(
            "patcher metadata snapshot not found at %s; run "
            "`dart run tool/gen_patcher_snapshot.dart` to generate it.",
            data_path,
        )
        return

    with data_path.open(encoding="utf-8") as f:
        data = json.load(f)

    constants = _obj_constants(src_dir)
    for name, obj in data.items():
        obj["dart_constant"] = constants.get(name)
        if obj["dart_constant"] is None:
            logger.warning(
                "patcher object %s has no Obj constant in "
                "lib/src/patcher_objects.dart; run "
                "`dart run tool/gen_obj_constants.dart`.",
                name,
            )

    known = {key for key, *_ in _PATCHER_CATEGORIES}
    grouped = {key: [] for key in known}
    for name in sorted(data.keys()):
        obj = data[name]
        key = obj.get("category", "UNSET")
        if key not in known:
            logger.warning(
                "patcher object %s has category %s, which conf.py does not "
                "know; add it to _PATCHER_CATEGORIES.",
                name,
                key,
            )
            key = "UNSET"
        grouped[key].append(obj)

    # Only categories that hold objects get a page, in reading order.
    categories = [
        {
            "key": key,
            "slug": slug,
            "title": title,
            "summary": summary,
            "objects": grouped[key],
            "has_midi_device": any(
                o.get("requires_midi_device") for o in grouped[key]
            ),
        }
        for key, slug, title, summary in _PATCHER_CATEGORIES
        if grouped[key]
    ]

    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(template_dir)),
        keep_trailing_newline=True,
        trim_blocks=False,
        lstrip_blocks=False,
    )

    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in out_dir.glob("*.rst"):
        stale.unlink()

    index = env.get_template("patcher_objects_index.rst.j2")
    (out_dir / "index.rst").write_text(
        index.render(categories=categories, total=len(data)), encoding="utf-8"
    )
    page = env.get_template("patcher_objects_category.rst.j2")
    for category in categories:
        (out_dir / f"{category['slug']}.rst").write_text(
            page.render(category=category, midi_device_note=_MIDI_DEVICE_NOTE),
            encoding="utf-8",
        )


def setup(app):
    app.connect("builder-inited", _render_patcher_objects)
    return {"version": "1.0", "parallel_read_safe": True}
