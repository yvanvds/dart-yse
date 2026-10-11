"""Sphinx configuration for the dart-yse documentation.

The build flow is:

    1. ``dart run tool/emit_api_rst.dart --out docs/source/api/_generated``
       walks the public surface re-exported from ``lib/yse.dart`` and emits
       one RST page per class. The script is driven from the ``api`` /
       ``html`` targets in :file:`Makefile` / :file:`make.bat`.
    2. The ``builder-inited`` hook below renders the patcher object
       reference (``source/api/patcher_objects/``: an index plus one page
       per category) from ``source/_data/patcher_objects.json`` and the
       long-form notes in ``source/_data/patcher_notes/`` via Jinja
       templates ported from the upstream libYSE docs.  The JSON snapshot
       is generated from the bound engine's registry by
       ``tool/gen_patcher_snapshot.dart``, the notes are ported from the
       engine submodule by ``tool/port_patcher_notes.dart``, and both are
       committed, so this step needs neither engine nor submodule.
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

# ``_data`` holds inputs to the patcher reference renderer (the JSON snapshot
# and the per-category notes files under ``_data/patcher_notes/``), not pages.
exclude_patterns = ["_build", "_data", "Thumbs.db", ".DS_Store"]

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

# #78: an object's registry description is a short summary. The long-form
# notes live upstream in libYSE's ``documentation/source/_data/patcher_notes/
# <slug>.rst`` (upstream #997), one file per category slug above.
# ``tool/port_patcher_notes.dart`` copies them to ``_data/patcher_notes/``,
# rewriting the cross-references that only resolve in the upstream docs tree
# into ``:yse-cpp:`` links and C++ API names into their Dart equivalents;
# test/port_patcher_notes_test.dart fails when the copy drifts.  Each
# object's notes start with a marker line naming the object and run to the
# next marker or the end of the file:
#
#     .. patcher-object:: .zl
#
#     Ordinary reStructuredText: paragraphs, lists, code blocks.
#
# The body is rendered under the object's summary, before its pin and
# parameter tables. Notes are keyed by the marker text, never by a filename,
# because object names hold characters such as ``~*``, ``.|`` and ``.!-``.
# The loader and its checks are ported from upstream's conf.py.

_NOTES_MARKER = ".. patcher-object::"
# Case-sensitive on purpose: "max" (a maximum) and "Maximum" are fine.
_NOTES_FORBIDDEN_WORD = re.compile(r"\bMax\b")


def _is_rst_comment_line(line):
    """True for a blank line or a line that can belong to an RST comment."""
    return not line.strip() or line.startswith("..") or line[:1].isspace()


def _split_notes_file(path, rel, logger):
    """Split one notes file into ``[(name, marker line, body text)]``.

    Anything before the first marker is the file header, which may only hold
    comments so that no text is silently dropped. A marker must name exactly
    one object; a malformed marker is reported and its section dropped.
    """
    sections = []
    for lineno, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        loc = f"{rel}:{lineno}"
        if line.startswith(_NOTES_MARKER):
            words = line[len(_NOTES_MARKER):].split()
            if len(words) != 1:
                logger.warning(
                    "a patcher-object marker names exactly one object.",
                    location=loc,
                )
            sections.append([words[0] if len(words) == 1 else "", lineno, []])
        elif sections:
            if _NOTES_FORBIDDEN_WORD.search(line):
                logger.warning(
                    "patcher notes for %s name Max; describe YSE's behaviour "
                    "on its own terms.",
                    sections[-1][0],
                    location=loc,
                )
            sections[-1][2].append(line)
        elif not _is_rst_comment_line(line):
            logger.warning(
                "text before the first patcher-object marker is not "
                "rendered; make it a comment or move it under a marker.",
                location=loc,
            )
    return [
        (name, lineno, "\n".join(body).strip("\n"))
        for name, lineno, body in sections
        if name
    ]


def _notes_problem(name, text, data, where):
    """Why a notes section cannot be used, or ``None`` if it can."""
    if not text.strip():
        return f"patcher notes for {name} are empty."
    if name not in data:
        return (
            f"patcher notes for {name}, which is not in the metadata "
            f"snapshot (_data/patcher_objects.json)."
        )
    if name in where:
        return f"duplicate patcher notes for {name}; the first is at {where[name]}."
    return None


def _load_patcher_notes(notes_dir, data, logger):
    """Return ``{object name: notes body}`` from ``notes_dir/*.rst``.

    Warns (which fails a ``-W`` build) on a note for an object that is not
    in the snapshot, on a second note for the same object, on a note filed
    under another category's file, on a file whose name is not a category
    slug, on a malformed marker, on text before the first marker that is not
    a comment, and on the word "Max" in a body.
    """
    slug_of = {key: slug for key, slug, *_ in _PATCHER_CATEGORIES}
    notes = {}
    where = {}
    if not notes_dir.is_dir():
        return notes

    for path in sorted(notes_dir.glob("*.rst")):
        rel = path.relative_to(notes_dir.parent.parent).as_posix()
        if path.stem not in slug_of.values():
            logger.warning(
                "patcher notes file %s is not named after a category slug in "
                "_PATCHER_CATEGORIES.",
                rel,
                location=f"{rel}:1",
            )

        for name, lineno, text in _split_notes_file(path, rel, logger):
            loc = f"{rel}:{lineno}"
            problem = _notes_problem(name, text, data, where)
            if problem:
                logger.warning(problem, location=loc)
                continue
            expected = slug_of.get(data[name].get("category", "UNSET"))
            if expected is not None and expected != path.stem:
                logger.warning(
                    "patcher notes for %s belong in %s.rst, the file for its "
                    "category.",
                    name,
                    expected,
                    location=loc,
                )
            notes[name] = text
            where[name] = loc

    return notes


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
    notes_dir = src_dir / "_data" / "patcher_notes"
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

    notes = _load_patcher_notes(notes_dir, data, logger)
    constants = _obj_constants(src_dir)
    for name, obj in data.items():
        obj["notes"] = notes.get(name, "")
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
