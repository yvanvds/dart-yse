DSP
===

Float-buffer storage (:class:`DspBuffer`) and chainable effect
modules (:class:`DspObject`). Both surfaces flatten an inheritance
hierarchy on the C++ side into named factory constructors and
subclass-specific accessors that throw if used on the wrong kind.

Upstream: :yse-cpp:`api/dsp.html <YSE::DSP>`.

.. include:: _generated/dsp_buffer.rst

.. include:: _generated/dsp_object.rst
