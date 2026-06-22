LiveCoding
==========

Static façade over the engine's embedded-CPython script API
(``yse_python.h``). Submit scripts with :py:meth:`LiveCoding.run` and
observe uncaught Python errors through the :py:attr:`LiveCoding.errors`
broadcast :class:`Stream`. The interpreter is only present on a
``YSE_ENABLE_PYTHON=ON`` build — query :py:attr:`LiveCoding.enabled`.

.. include:: _generated/live_coding.rst
