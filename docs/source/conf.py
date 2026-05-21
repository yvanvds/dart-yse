"""Sphinx configuration for the dart-yse documentation.

The build flow is:

    1. ``dart run tool/emit_api_rst.dart --out docs/source/api/_generated``
       walks the public surface re-exported from ``lib/yse.dart`` and emits
       one RST page per class. The script is driven from the ``api`` /
       ``html`` targets in :file:`Makefile` / :file:`make.bat`.
    2. The ``builder-inited`` hook below renders
       ``source/api/patcher_objects.rst`` from
       ``source/_data/patcher_objects.json`` via a Jinja template — mirroring
       the upstream libYSE docs.  The JSON snapshot is shipped from upstream
       (``patcher::CreateObject`` is the same C++ entry point both bindings
       call, so the object list and its docs are valid for both worlds).
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
# The snapshot at _data/patcher_objects.json is shipped from upstream libYSE
# (produced by ``python yse.py dump-patcher-meta`` against the C++ engine).
# Both bindings call the same ``patcher::CreateObject``, so the set of
# accepted type strings and their inlet / outlet / parameter docs is the
# same for both worlds.  This hook turns the JSON into the RST page Sphinx
# consumes.  Running the render inside ``builder-inited`` keeps every
# documentation build — local ``make html``, CI's docs.yml workflow — in
# lockstep with the committed JSON without anyone needing to remember to
# invoke a generator step.  The rendered ``patcher_objects.rst`` is
# gitignored.
#
# Category headings are listed in a fixed order; ``UNSET`` is a fallback
# that should never reach the docs in practice — upstream's failsafe
# doctest rejects it.

_PATCHER_CATEGORY_ORDER = [
    ("OSC", "Oscillators"),
    ("FILTER", "Filters"),
    ("MATH", "Math"),
    ("GENERIC", "Generic / routing"),
    ("GUI", "GUI controls"),
    ("TIME", "Time"),
    ("MIDI", "MIDI"),
    ("UNSET", "Uncategorised"),
]


def _render_patcher_objects(app):
    """Render ``api/patcher_objects.rst`` from the JSON snapshot."""
    import jinja2
    from sphinx.util import logging as sphinx_logging

    logger = sphinx_logging.getLogger(__name__)

    src_dir = Path(app.srcdir)
    data_path = src_dir / "_data" / "patcher_objects.json"
    template_dir = src_dir / "_templates"
    out_path = src_dir / "api" / "patcher_objects.rst"

    if not data_path.exists():
        logger.warning(
            "patcher metadata snapshot not found at %s; "
            "copy the upstream libYSE snapshot into _data/ to populate "
            "the patcher object reference page.",
            data_path,
        )
        return

    with data_path.open(encoding="utf-8") as f:
        data = json.load(f)

    grouped = {label: [] for _, label in _PATCHER_CATEGORY_ORDER}
    category_label = dict(_PATCHER_CATEGORY_ORDER)
    for name in sorted(data.keys()):
        obj = data[name]
        label = category_label.get(obj.get("category", "UNSET"), "Uncategorised")
        grouped[label].append(obj)

    by_category = {k: v for k, v in grouped.items() if v}

    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(template_dir)),
        keep_trailing_newline=True,
        trim_blocks=False,
        lstrip_blocks=False,
    )
    template = env.get_template("patcher_objects.rst.j2")
    rendered = template.render(by_category=by_category)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(rendered, encoding="utf-8")


def setup(app):
    app.connect("builder-inited", _render_patcher_objects)
    return {"version": "1.0", "parallel_read_safe": True}
