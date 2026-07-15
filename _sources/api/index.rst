API Reference
=============

The public ``dart-yse`` API lives in the ``yse`` package and is
imported through a single library:

.. code-block:: dart

   import 'package:yse/yse.dart';

The pages below are generated from each class's dartdoc comments by
``tool/emit_api_rst.dart`` (run by ``make api`` and ``make html``).
The same comments drive ``dart doc`` and pub.dev — keep them as the
canonical source of truth.

Every wrapper class points back at the upstream C++ class it wraps so
you can read both views of the API side by side. Look for the
``Upstream:`` line at the top of each subsystem page.

.. toctree::
   :maxdepth: 1
   :caption: Core

   core
   sounds
   channels
   devices
   listener
   reverb

.. toctree::
   :maxdepth: 1
   :caption: DSP

   dsp

.. toctree::
   :maxdepth: 1
   :caption: MIDI

   midi

.. toctree::
   :maxdepth: 1
   :caption: Clip transport

   clip

.. toctree::
   :maxdepth: 1
   :caption: Synth

   synth

.. toctree::
   :maxdepth: 1
   :caption: Music

   music

.. toctree::
   :maxdepth: 1
   :caption: Patcher

   patcher
   patcher_objects

.. toctree::
   :maxdepth: 1
   :caption: Utilities

   utils
   buffer_io
   log
   live_coding

.. toctree::
   :maxdepth: 1
   :caption: Enums

   enums
