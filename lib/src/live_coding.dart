import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'library.dart';

/// Live-coding façade over the engine's embedded-CPython script API.
///
/// The C surface (`yse_python.h`) is a set of stateless globals — there is
/// no native handle — so this is a thin static façade rather than a fetched
/// singleton. Scripts are submitted with [run] and uncaught Python errors
/// surface through the [errors] stream.
///
/// The interpreter is only present on a `YSE_ENABLE_PYTHON=ON` build; query
/// [enabled] to tell. On an OFF build [run] is still safe to call — the
/// engine reports the missing feature through [errors] with a sentinel
/// "compiled without" message.
class LiveCoding {
  LiveCoding._();

  /// Compile-time feature query. True only when the library was built with
  /// `YSE_ENABLE_PYTHON=ON`. Safe to call regardless of engine state.
  static bool get enabled => bindings.python_enabled() != 0;

  /// Submit a UTF-8 [src] script for evaluation on the engine's script
  /// thread. Returns immediately; the engine takes its own copy, so the
  /// marshalled buffer is freed on return. Uncaught errors arrive later
  /// through [errors] (during [System].`update()`).
  static void run(String src) => using((arena) {
    final cstr = src.toNativeUtf8(allocator: arena);
    bindings.run_script(cstr.cast());
  });

  static StreamController<String>? _controller;
  static NativeCallable<Void Function(Pointer<Char>, Pointer<Void>)>? _callable;

  /// Broadcast stream of formatted tracebacks from uncaught Python
  /// exceptions and syntax errors. The first subscription installs the
  /// engine error callback; the bridge is torn down when the last
  /// subscriber cancels (or the engine closes).
  ///
  /// Unlike [Log.messages], the traceback string is **owned by the engine
  /// and valid only for the duration of the call** — there is no free
  /// function. A `NativeCallable.listener` would copy the pointer and read
  /// it later, by which point it dangles. So this uses
  /// `NativeCallable.isolateLocal`: the closure runs synchronously inside
  /// the C call and copies the string with `toDartString()` before
  /// returning. Safe because the engine fires this callback on the thread
  /// that drives `yse_system_update()` — the main isolate.
  static Stream<String> get errors {
    if (_controller != null) return _controller!.stream;
    final controller = StreamController<String>.broadcast(
      onCancel: () {
        if (_controller?.hasListener ?? false) return;
        // Last listener gone — uninstall the bridge.
        bindings.set_script_error_callback(nullptr, nullptr);
        _callable?.close();
        _callable = null;
        _controller?.close();
        _controller = null;
      },
    );
    final callable =
        NativeCallable<
          Void Function(Pointer<Char>, Pointer<Void>)
        >.isolateLocal((Pointer<Char> traceback, Pointer<Void> _) {
          // Copy out of engine-owned memory before the call returns; the
          // string is invalid the moment this closure does.
          controller.add(traceback.cast<Utf8>().toDartString());
        });
    bindings.set_script_error_callback(callable.nativeFunction, nullptr);
    _callable = callable;
    _controller = controller;
    return controller.stream;
  }

  static final Map<String, _BusBridge> _busBridges = {};

  /// Broadcast stream of `(address, value)` frames for every publish on the
  /// engine's global named bus whose address starts with [prefix] (a plain
  /// byte-wise prefix match; the empty string matches every address).
  ///
  /// This taps the host-side view of the bus: a script's `yse.send(...)`, a
  /// patcher `gSend` outlet, or any other engine-side publish under [prefix]
  /// arrives here as a typed [BusValue]. A prefix tap adds no audio-thread
  /// cost — the match happens on the engine's control thread.
  ///
  /// Each distinct [prefix] gets its own shared broadcast bridge, mirroring
  /// [errors]: the first subscription installs a native `yse_bus_tap`, and it
  /// is torn down (`yse_bus_tap_destroy`) when the last listener cancels. A
  /// later subscription reinstalls a fresh tap.
  ///
  /// Isolate-safety matches [errors] exactly. The callback's `address`,
  /// string, and list buffers are **owned by the engine and valid only for
  /// the duration of the call** — there is no free function. So this uses
  /// `NativeCallable.isolateLocal`, copying every payload out (`toDartString`
  /// / a typed-list copy) synchronously before the C call returns. Safe
  /// because the engine fires the tap on the thread that drives
  /// `yse_system_update()` — the main isolate.
  ///
  /// Create the tap after `System.init` / `System.initOffline`; a
  /// `System.close()` invalidates it, and it does not reattach across a
  /// re-init (re-subscribe after the next init). If the engine rejects the
  /// tap (e.g. called before init), a [StateError] is thrown.
  static Stream<BusFrame> bus(String prefix) {
    final existing = _busBridges[prefix];
    if (existing != null) return existing.controller.stream;

    late final _BusBridge bridge;
    final controller = StreamController<BusFrame>.broadcast(
      onCancel: () {
        if (bridge.controller.hasListener) return;
        // Last listener gone — uninstall this prefix's native tap.
        _busBridges.remove(prefix);
        bindings.bus_tap_destroy(bridge.tap);
        bridge.callable.close();
        bridge.controller.close();
      },
    );

    final callable = NativeCallable<yse_bus_tap_cbFunction>.isolateLocal((
      Pointer<Char> address,
      int kind,
      int i,
      double f,
      Pointer<Char> str,
      Pointer<Float> list,
      int listLen,
      Pointer<Void> _,
    ) {
      // Copy out of engine-owned memory before the call returns; `address`,
      // `str` and `list` all dangle the moment this closure does.
      final addr = address.address == 0
          ? ''
          : address.cast<Utf8>().toDartString();
      controller.add((
        address: addr,
        value: _decodeBusValue(kind, i, f, str, list, listLen),
      ));
    });

    final tap = using((arena) {
      final cPrefix = prefix.toNativeUtf8(allocator: arena);
      return bindings.bus_tap_create(
        cPrefix.cast(),
        callable.nativeFunction,
        nullptr,
      );
    });
    if (tap.address == 0) {
      callable.close();
      controller.close();
      throw StateError(
        'yse_bus_tap_create failed for prefix "$prefix" — create taps after '
        'System.init() / System.initOffline().',
      );
    }

    bridge = _BusBridge(controller, callable, tap);
    _busBridges[prefix] = bridge;
    return controller.stream;
  }

  /// Reconstructs the typed [BusValue] from a raw callback frame. Runs
  /// synchronously inside the native callback, so it must copy every
  /// engine-owned buffer it reads before returning.
  static BusValue _decodeBusValue(
    int kind,
    int i,
    double f,
    Pointer<Char> str,
    Pointer<Float> list,
    int listLen,
  ) {
    switch (YseBusValueKind.fromValue(kind)) {
      case YseBusValueKind.YSE_BUS_BANG:
        return const BusBang();
      case YseBusValueKind.YSE_BUS_INT:
        return BusInt(i);
      case YseBusValueKind.YSE_BUS_FLOAT:
        return BusFloat(f);
      case YseBusValueKind.YSE_BUS_STRING:
        return BusString(
          str.address == 0 ? '' : str.cast<Utf8>().toDartString(),
        );
      case YseBusValueKind.YSE_BUS_LIST:
        // `list` may be NULL when list_len is 0. asTypedList is a view over
        // engine memory — .toList() copies it into the Dart heap before the
        // buffer dangles.
        return BusList(
          listLen == 0
              ? const <double>[]
              : list.asTypedList(listLen).toList(growable: false),
        );
    }
  }
}

/// One `(address, value)` frame delivered by [LiveCoding.bus]: the full bus
/// [address] the value was published on, paired with its typed [value].
///
/// A named record — read the fields directly (`frame.address`, `frame.value`)
/// or destructure them (`final (:address, :value) = frame;`).
typedef BusFrame = ({String address, BusValue value});

/// A value carried on the engine's global named bus, delivered through
/// [LiveCoding.bus].
///
/// The concrete subtype encodes which of the engine's five bus payload kinds
/// arrived — [BusBang], [BusInt], [BusFloat], [BusString], or [BusList].
/// Because the type is sealed, an exhaustive `switch` over a [BusValue] needs
/// no default case; pattern-match each subtype to read its payload
/// (`value` for the scalar kinds, `values` for [BusList]).
sealed class BusValue {
  const BusValue();
}

/// A valueless trigger (`YSE_BUS_BANG`) — e.g. a patcher `gSend` bang outlet.
final class BusBang extends BusValue {
  /// Const constructor — all bangs are equal and carry no payload.
  const BusBang();

  @override
  bool operator ==(Object other) => other is BusBang;

  @override
  int get hashCode => (BusBang).hashCode;

  @override
  String toString() => 'BusBang()';
}

/// A 32-bit integer bus value (`YSE_BUS_INT`).
final class BusInt extends BusValue {
  /// The published integer.
  final int value;

  /// Wrap an integer bus payload.
  const BusInt(this.value);

  @override
  bool operator ==(Object other) => other is BusInt && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BusInt($value)';
}

/// A 32-bit float bus value (`YSE_BUS_FLOAT`).
final class BusFloat extends BusValue {
  /// The published float, widened to a Dart [double].
  final double value;

  /// Wrap a float bus payload.
  const BusFloat(this.value);

  @override
  bool operator ==(Object other) => other is BusFloat && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BusFloat($value)';
}

/// A string bus value (`YSE_BUS_STRING`, NUL-terminated UTF-8 engine-side).
final class BusString extends BusValue {
  /// The published string, copied out of engine-owned memory.
  final String value;

  /// Wrap a string bus payload.
  const BusString(this.value);

  @override
  bool operator ==(Object other) => other is BusString && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BusString($value)';
}

/// A list of 32-bit floats (`YSE_BUS_LIST`).
final class BusList extends BusValue {
  /// The published floats, copied out of engine-owned memory. May be empty.
  final List<double> values;

  /// Wrap a float-list bus payload.
  const BusList(this.values);

  @override
  bool operator ==(Object other) {
    if (other is! BusList || other.values.length != values.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (other.values[i] != values[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(values);

  @override
  String toString() => 'BusList($values)';
}

/// Per-prefix state for a live [LiveCoding.bus] tap: the shared broadcast
/// controller, the isolate-local native callback, and the owned native tap
/// handle. Torn down together when the prefix's last listener cancels.
class _BusBridge {
  final StreamController<BusFrame> controller;
  final NativeCallable<yse_bus_tap_cbFunction> callable;
  final Pointer<YseBusTap> tap;

  _BusBridge(this.controller, this.callable, this.tap);
}
