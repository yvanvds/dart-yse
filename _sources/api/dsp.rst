DSP
===

Float-buffer storage (:class:`DspBuffer`) and chainable effect
modules (:class:`DspObject`). Both surfaces flatten an inheritance
hierarchy on the C++ side into named factory constructors and
subclass-specific accessors that throw if used on the wrong kind.

Upstream: :yse-cpp:`api/dsp.html <YSE::DSP>`.

.. include:: _generated/dsp_buffer.rst

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
