DSP
===

Float-buffer storage (:class:`DspBuffer` and its subclasses
:class:`DrawableBuffer`, :class:`FileBuffer` and :class:`Wavetable`, which
mirror the C++ inheritance chain so the type system decides which
operations a buffer supports) and chainable effect modules
(:class:`DspObject`, which flattens its hierarchy into named factory
constructors and subclass-specific accessors).

Upstream: :yse-cpp:`api/dsp.html <YSE::DSP>`.

Every buffer supports sample-wise math against another buffer
(:py:meth:`DspBuffer.addBuffer`, ``subBuffer``, ``mulBuffer``,
``divBuffer``, over the shorter of the two lengths), span copies
(:py:meth:`DspBuffer.copyFrom`, which throws on an out-of-range span) and
:py:meth:`DspBuffer.swap` between buffers of equal length. A
:class:`FileBuffer` also reports the native rate of the file it loaded
(:py:attr:`FileBuffer.fileSampleRate`), which stays valid across a re-init
at another session rate.

:class:`DspMultiBuffer` bundles a copy of several buffers as the channels
of one stereo or surround source for :py:meth:`Sound.fromMultiBuffer`.

.. include:: _generated/dsp_buffer.rst

.. include:: _generated/drawable_buffer.rst

.. include:: _generated/file_buffer.rst

.. include:: _generated/wavetable.rst

.. include:: _generated/dsp_multi_buffer.rst

Effects chain with :py:meth:`DspObject.link`, which inserts the new object
*between* the head and its old successor. :py:attr:`DspObject.next` walks a
chain: it reads the successor from the engine and hands back the very Dart
object that was linked in (subclass intact), never a new wrapper.

.. include:: _generated/dsp_object.rst

Mix-grade modules
-----------------

Channel-strip effects. Each is a :class:`DspObject` subclass — construct it,
then attach it to a channel insert (``Channel.dsp``) or a sound
(:meth:`Sound.setDsp`) exactly like the base modules. The inherited
:attr:`DspObject.impact` sets the wet/dry balance, except on
:class:`MorphingReverb` and :class:`Underwater`, whose balance is inherent in
their own control (the morphed presets' dry/wet, and the depth).

:class:`Underwater` is the engine's underwater treatment as an ordinary
insert you can place anywhere in a chain; it is independent of the engine's
own instance driven by ``System.underwaterFx`` / ``System.underwaterDepth``.

.. include:: _generated/compressor.rst

.. include:: _generated/parametric_eq.rst

.. include:: _generated/chorus.rst

.. include:: _generated/plate_reverb.rst

.. include:: _generated/feedback_delay.rst

.. include:: _generated/morphing_reverb.rst

.. include:: _generated/underwater.rst
