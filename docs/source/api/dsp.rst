DSP
===

Float-buffer storage (:class:`DspBuffer` and its subclasses
:class:`DrawableBuffer`, :class:`FileBuffer` and :class:`Wavetable`, which
mirror the C++ inheritance chain so the type system decides which
operations a buffer supports) and chainable effect modules
(:class:`DspObject`, which flattens its hierarchy into named factory
constructors and subclass-specific accessors).

Upstream: :yse-cpp:`api/dsp.html <YSE::DSP>`.

.. include:: _generated/dsp_buffer.rst

.. include:: _generated/drawable_buffer.rst

.. include:: _generated/file_buffer.rst

.. include:: _generated/wavetable.rst

.. include:: _generated/dsp_object.rst

Mix-grade modules
-----------------

Channel-strip effects added in engine v2.3.0. Each is a :class:`DspObject`
subclass — construct it, then attach it to a channel insert (``Channel.dsp``)
or a sound (:meth:`Sound.setDsp`) exactly like the base modules. The inherited
:attr:`DspObject.impact` sets the wet/dry balance.

.. include:: _generated/compressor.rst

.. include:: _generated/parametric_eq.rst

.. include:: _generated/chorus.rst

.. include:: _generated/plate_reverb.rst

.. include:: _generated/feedback_delay.rst

.. include:: _generated/morphing_reverb.rst
