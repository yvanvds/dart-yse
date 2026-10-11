import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';
import 'library.dart';

/// Host access to the engine's global named bus: publish a value to an
/// address, subscribe to one exact address, or tap every address under a
/// prefix.
///
/// The bus is the engine's message plane. A value published to an address
/// reaches everything listening there, whoever published it — a host
/// [publish], a live-coding script's `yse.send(...)`, or a patcher `.s`
/// (`gSend`) object. The address namespaces the engine itself listens on:
///
/// | Address                     | Listener                                   |
/// |-----------------------------|--------------------------------------------|
/// | `synth.<name>.<event>`      | a synth named with `Synth.busName`         |
/// | `patcher.<name>.<slot>`     | a `.r` object in a named patcher           |
/// | `sound.<name>.<prop>`       | a named sound                              |
/// | `channel.<name>.<prop>`     | a named channel                            |
///
/// Anything else is free for the host and scripts to use (`phi.ctl.play`,
/// …): only [subscribe]rs and [tap]s hear it. All addresses match
/// exact-string and case-sensitively, except a [tap], which is a byte-wise
/// prefix match.
///
/// ## Threading
///
/// Call every member from the isolate that called `System.init()` /
/// `System.initOffline()` — the control thread, which drives
/// `System.update()`. A [publish] from there dispatches synchronously: every
/// engine-side listener, [subscribe]r and [tap] callback has run by the time
/// it returns, and the matching frames are already queued on their streams
/// (Dart listeners receive them in a microtask, without needing an
/// `update()`). Publishes the engine makes from other threads (the script
/// thread, the audio thread) are delivered during the next `update()`.
///
/// Never publish from an audio callback, or concurrently with
/// `System.close()`.
///
/// ## Lifecycle
///
/// [subscribe] and [tap] streams are bound to the engine session they were
/// created in. `System.close()` releases every native subscription and closes
/// every bus stream (listeners get `onDone`); subscribe again after the next
/// init.
abstract final class Bus {
  /// Publish [value] to the exact [address].
  ///
  /// The publish takes the same path as a script's `yse.send(...)`, so it
  /// reaches everything a script can — see the address table on [Bus]. On the
  /// control isolate it dispatches synchronously. A publish nobody listens to
  /// is not an error.
  ///
  /// Throws [YseException] with status `YSE_ERR_NOT_INITIALIZED` when the
  /// engine is not running, or `YSE_ERR_INVALID_ARGUMENT` for an empty
  /// [address]. Throws [ArgumentError] for a [BusInt] outside the signed
  /// 32-bit range.
  static void publish(String address, BusValue value) => using((arena) {
    if (value case BusInt(
      :final value,
    ) when value < -0x80000000 || value > 0x7FFFFFFF) {
      throw ArgumentError.value(value, 'value', 'BusInt must fit 32 bits');
    }
    final b = bindings;
    final cAddr = address.toNativeUtf8(allocator: arena).cast<Char>();
    final status = switch (value) {
      BusBang() => b.bus_publish_bang(cAddr),
      BusInt(:final value) => b.bus_publish_int(cAddr, value),
      BusFloat(:final value) => b.bus_publish_float(cAddr, value),
      BusString(:final value) => b.bus_publish_string(
        cAddr,
        value.toNativeUtf8(allocator: arena).cast(),
      ),
      BusList(:final values) => _publishList(b, cAddr, values, arena),
    };
    checkStatus(status, b);
  });

  static YseStatus _publishList(
    YseBindings b,
    Pointer<Char> address,
    List<double> values,
    Arena arena,
  ) {
    if (values.isEmpty) return b.bus_publish_list(address, nullptr, 0);
    final buf = arena<Float>(values.length);
    buf.asTypedList(values.length).setAll(0, values);
    return b.bus_publish_list(address, buf, values.length);
  }

  /// Broadcast stream of every value published to exactly [address].
  ///
  /// Unlike [tap], this is an exact match: a subscription to
  /// `patcher.lead.cutoff` does not see `patcher.lead.cutoff2`. Each frame's
  /// `address` is [address] itself.
  ///
  /// All listeners of one [address] share a single native subscription,
  /// created on the first call and released when the last listener cancels
  /// (a later call creates a fresh one). See [Bus] for threading and
  /// lifecycle.
  ///
  /// The engine fires the native callback on the control thread — inline
  /// for a control-thread publish, else during `System.update()` — never on
  /// the audio thread. Its `address`, string and list payloads are
  /// engine-owned and valid only for the duration of the call, so the bridge
  /// is a `NativeCallable.isolateLocal` that copies everything out before
  /// returning.
  ///
  /// Throws [ArgumentError] for an empty [address], and [StateError] if the
  /// engine rejects the subscription (e.g. before `System.init`).
  static Stream<BusFrame> subscribe(String address) {
    if (address.isEmpty) {
      throw ArgumentError.value(address, 'address', 'must not be empty');
    }
    return _bridge(
      _subscriptions,
      address,
      (cb) => using((arena) {
        final sub = bindings.bus_subscribe(
          address.toNativeUtf8(allocator: arena).cast(),
          cb,
          nullptr,
        );
        if (sub.address == 0) {
          _throwRejected('yse_bus_subscribe', 'address "$address"');
        }
        return () => bindings.bus_unsubscribe(sub);
      }),
    );
  }

  /// Broadcast stream of every value published to any address that starts
  /// with [prefix] (a plain byte-wise prefix match; the empty string matches
  /// every address). Each frame carries the full address it was published on.
  ///
  /// A tap adds no audio-thread cost: the match happens in the engine's
  /// control-thread dispatch. Sharing, threading, payload copying and
  /// lifecycle are exactly as for [subscribe].
  ///
  /// Throws [StateError] if the engine rejects the tap (e.g. before
  /// `System.init`).
  static Stream<BusFrame> tap(String prefix) => _bridge(
    _taps,
    prefix,
    (cb) => using((arena) {
      final tap = bindings.bus_tap_create(
        prefix.toNativeUtf8(allocator: arena).cast(),
        cb,
        nullptr,
      );
      if (tap.address == 0) {
        _throwRejected('yse_bus_tap_create', 'prefix "$prefix"');
      }
      return () => bindings.bus_tap_destroy(tap);
    }),
  );

  static final Map<String, _BusBridge> _subscriptions = {};
  static final Map<String, _BusBridge> _taps = {};

  static Never _throwRejected(String fn, String what) {
    final b = bindings;
    final cstr = b.last_error();
    final detail = cstr.address == 0
        ? '<no detail>'
        : cstr.cast<Utf8>().toDartString();
    b.clear_last_error();
    throw StateError(
      '$fn failed for $what: $detail — subscribe after '
      'System.init() / System.initOffline().',
    );
  }

  /// Returns the shared stream for [key] in [registry], creating the bridge
  /// (and, through [attach], its native subscription) on first use.
  static Stream<BusFrame> _bridge(
    Map<String, _BusBridge> registry,
    String key,
    void Function() Function(Pointer<NativeFunction<YseBusSubCallbackFunction>>)
    attach,
  ) {
    final existing = registry[key];
    if (existing != null) return existing.controller.stream;

    late final _BusBridge bridge;
    final controller = StreamController<BusFrame>.broadcast(
      onCancel: () {
        if (bridge.controller.hasListener) return;
        // Last listener gone — release this key's native subscription.
        bridge.dispose();
      },
    );
    final callable = NativeCallable<YseBusSubCallbackFunction>.isolateLocal((
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
      controller.add((
        address: address.address == 0
            ? ''
            : address.cast<Utf8>().toDartString(),
        value: _decode(kind, i, f, str, list, listLen),
      ));
    });

    final void Function() release;
    try {
      release = attach(callable.nativeFunction);
    } catch (_) {
      callable.close();
      controller.close();
      rethrow;
    }
    bridge = _BusBridge(controller, callable, release, () {
      if (identical(registry[key], bridge)) registry.remove(key);
    });
    registry[key] = bridge;
    return controller.stream;
  }

  /// Reconstructs the typed [BusValue] from a raw callback frame. Runs
  /// synchronously inside the native callback, so it copies every
  /// engine-owned buffer it reads.
  static BusValue _decode(
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
        // engine memory — .toList() copies it into the Dart heap.
        return BusList(
          listLen == 0
              ? const <double>[]
              : list.asTypedList(listLen).toList(growable: false),
        );
    }
  }
}

/// Releases every live [Bus.subscribe] / [Bus.tap] bridge and closes its
/// stream. Called by `System.close()` while the engine is still up, so the
/// native handles unsubscribe cleanly. Internal to `lib/src/`.
void closeBusBridges() {
  for (final bridge in [...Bus._subscriptions.values, ...Bus._taps.values]) {
    bridge.dispose();
  }
}

/// One `(address, value)` frame delivered by [Bus.subscribe] or [Bus.tap]:
/// the full bus [address] the value was published on, paired with its typed
/// [value].
///
/// A named record — read the fields directly (`frame.address`, `frame.value`)
/// or destructure them (`final (:address, :value) = frame;`).
typedef BusFrame = ({String address, BusValue value});

/// A value carried on the engine's global named bus — what [Bus.publish]
/// sends and what [Bus.subscribe] / [Bus.tap] deliver.
///
/// The concrete subtype encodes which of the engine's five bus payload kinds
/// it is — [BusBang], [BusInt], [BusFloat], [BusString], or [BusList].
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
  /// The integer payload. Published values must fit a signed 32-bit int.
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
  /// The float payload, widened to a Dart [double] (narrowed to 32 bits on
  /// publish).
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
  /// The string payload.
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

/// A list of 32-bit floats (`YSE_BUS_LIST`) — e.g. the
/// `[channel, note, velocity]` payload of `synth.<name>.note`.
final class BusList extends BusValue {
  /// The float payload. May be empty.
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

/// Per-key state for a live [Bus.subscribe] / [Bus.tap] bridge: the shared
/// broadcast controller, the isolate-local native callback, and the release
/// function for the owned native handle. Torn down together, once.
class _BusBridge {
  final StreamController<BusFrame> controller;
  final NativeCallable<YseBusSubCallbackFunction> callable;
  final void Function() _release;
  final void Function() _unregister;
  bool _disposed = false;

  _BusBridge(this.controller, this.callable, this._release, this._unregister);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unregister();
    // Unsubscribe on the control thread first: the engine guarantees no
    // callback fires after this returns, so closing the callable is safe.
    _release();
    callable.close();
    controller.close();
  }
}
