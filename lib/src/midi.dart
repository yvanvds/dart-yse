import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';
import 'library.dart';
import 'synth.dart';

/// Standard MIDI-file playback.
///
/// Load a `.mid` file with [load], then control playback with
/// [play] / [pause] / [stop].
class MidiFile implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.midi_file_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseMidiFile> _handle;

  MidiFile._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Load [filename] and prepare for playback. Throws [YseException]
  /// on failure.
  factory MidiFile(String filename) {
    final b = bindings;
    final h = b.midi_file_create();
    if (h.address == 0) {
      throw YseException('yse_midi_file_create returned null');
    }
    final f = MidiFile._(b, h);
    try {
      using((arena) {
        final cstr = filename.toNativeUtf8(allocator: arena);
        checkStatus(b.midi_file_load(h, cstr.cast()), b);
      });
      return f;
    } catch (_) {
      f.dispose();
      rethrow;
    }
  }

  /// Start or resume playback.
  void play() => _b.midi_file_play(_handle);

  /// Pause playback. Resume with [play].
  void pause() => _b.midi_file_pause(_handle);

  /// Stop playback and rewind to the start.
  void stop() => _b.midi_file_stop(_handle);

  /// Route this file's playback into an internal [synth] (upstream #372).
  ///
  /// While the file plays, every note / controller / pitch-bend event it
  /// contains is delivered to [synth] block-accurately on the audio thread.
  /// May be called for several synths (up to a small fixed cap) to drive them
  /// together; re-connecting an already-connected synth is a no-op. [synth]
  /// must outlive the connection — [disconnectSynth] it (or dispose this file)
  /// before disposing the synth.
  void connectSynth(Synth synth) =>
      _b.midi_file_connect_synth(_handle, synth.handle);

  /// Stop routing this file's playback into [synth]. Safe to call for a synth
  /// that was never connected.
  void disconnectSynth(Synth synth) =>
      _b.midi_file_disconnect_synth(_handle, synth.handle);

  /// Destroy the underlying native file and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.midi_file_destroy(_handle);
    _handle = nullptr;
  }
}

/// MIDI output port (Windows / Linux only; backed by RtMidi upstream).
///
/// Enumerate device counts with [System.midiOutDeviceCount] and names
/// with [System.midiOutDeviceName], then open one with [MidiOut.open].
///
/// Channels here are **wire-level, 0-based** (`0..15`) — the low nibble of
/// the status byte. The musical layer ([Synth], [ClipEvent], `Note`) counts
/// `1..16` instead, so MIDI channel 1 is `0` here and `1` there. A channel
/// outside `0..15` is clamped into that range by the engine (libYSE 3.0.1)
/// rather than spilling into the status nibble, so `-1` sends on channel 0
/// and `16` on channel 15.
///
/// To send a message the typed helpers don't cover — a SysEx dump, or any
/// other complete message — use [raw].
class MidiOut implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.midi_out_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseMidiOut> _handle;

  MidiOut._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Open the MIDI device at [port].
  ///
  /// When [port] does not exist or the MIDI backend cannot start, the engine
  /// reports the RtMidi error through [Log] and the port stays unopened:
  /// every send on it is then a silent no-op. Check [port] against
  /// [System.midiOutDeviceCount] first.
  factory MidiOut.open(int port) {
    final b = bindings;
    final h = b.midi_out_create();
    if (h.address == 0) {
      throw YseException(
        'yse_midi_out_create returned null (Windows/Linux only)',
      );
    }
    b.midi_out_open(h, port);
    return MidiOut._(b, h);
  }

  /// Send Note-On. [channel] is 0..15, [pitch] is 0..127.
  void noteOn({
    required int channel,
    required int pitch,
    required int velocity,
  }) => _b.midi_out_note_on(_handle, channel, pitch, velocity);

  /// Send Note-Off.
  void noteOff({required int channel, required int pitch, int velocity = 0}) =>
      _b.midi_out_note_off(_handle, channel, pitch, velocity);

  /// Send polyphonic key-pressure (aftertouch).
  void polyPressure({
    required int channel,
    required int pitch,
    required int value,
  }) => _b.midi_out_poly_pressure(_handle, channel, pitch, value);

  /// Send channel-pressure.
  void channelPressure({required int channel, required int value}) =>
      _b.midi_out_channel_pressure(_handle, channel, value);

  /// Send program-change.
  void programChange({required int channel, required int value}) =>
      _b.midi_out_program_change(_handle, channel, value);

  /// Send control-change.
  void controlChange({
    required int channel,
    required int controller,
    required int value,
  }) => _b.midi_out_control_change(_handle, channel, controller, value);

  /// Send All-Notes-Off on a specific [channel] (`0..15`), or on every
  /// channel when null.
  void allNotesOff({int? channel}) {
    if (channel == null) {
      _b.midi_out_all_notes_off(_handle);
    } else {
      _b.midi_out_all_notes_off_channel(_handle, channel);
    }
  }

  /// Send Reset-All-Controllers on a specific [channel] (or all if null).
  void reset({int? channel}) {
    if (channel == null) {
      _b.midi_out_reset(_handle);
    } else {
      _b.midi_out_reset_channel(_handle, channel);
    }
  }

  /// Toggle local-keyboard control on the receiving instrument.
  set localControl(bool on) => _b.midi_out_local_control(_handle, on ? 1 : 0);

  /// Toggle Omni mode on the receiving instrument.
  set omni(bool on) => _b.midi_out_omni(_handle, on ? 1 : 0);

  /// Toggle Poly (`true`) or Mono (`false`) mode on the receiving instrument.
  set poly(bool on) => _b.midi_out_poly(_handle, on ? 1 : 0);

  /// Send three raw MIDI bytes.
  ///
  /// Always sends exactly three bytes, so it only suits three-byte messages
  /// (note on/off, poly pressure, control change, pitch bend). For anything
  /// else — a two-byte program change or channel pressure, a one-byte
  /// realtime message, SysEx — use [raw], which sends the message as given.
  void raw3(int a, int b, int c) => _b.midi_out_raw3(_handle, a, b, c);

  /// Send one complete MIDI message, byte for byte — no padding and no
  /// truncation (libYSE #748 / #903).
  ///
  /// This is the way to send two-byte messages (program change, channel
  /// pressure), single-byte system realtime messages, and System Exclusive
  /// dumps of any length:
  ///
  /// ```dart
  /// out.raw([0xC0, 5]);                               // program change
  /// out.raw([0xF0, 0x7E, 0x7F, 0x09, 0x01, 0xF7]);    // GM System On
  /// ```
  ///
  /// [bytes] is copied into native memory for the call, so it may be
  /// reused or modified straight afterwards. An empty list is a no-op.
  ///
  /// The message is checked before anything reaches the engine, and an
  /// [ArgumentError] is thrown when:
  ///
  /// * a value is outside `0..255`;
  /// * the first byte is not a status byte (`>= 0x80`) — running status
  ///   is not supported, every message carries its own status;
  /// * a data byte has its high bit set (`>= 0x80`);
  /// * the length doesn't match the status: 3 bytes for note off/on, poly
  ///   pressure, control change, pitch bend and song position; 2 for
  ///   program change, channel pressure, MTC quarter frame and song
  ///   select; 1 for tune request and system realtime (`0xF8..0xFF`);
  /// * a SysEx message (`0xF0`) doesn't end with `0xF7`;
  /// * the status is `0xF4` / `0xF5` (undefined) or a stray `0xF7`.
  ///
  /// Unlike the typed helpers, the channel nibble of a raw status byte is
  /// sent as given — there is nothing to clamp.
  ///
  /// On a port that isn't open (see [MidiOut.open]) or after [dispose] this
  /// is a silent no-op, like every other send. A send RtMidi refuses is
  /// reported through [Log] and dropped; it never throws across the FFI
  /// boundary.
  void raw(List<int> bytes) {
    if (bytes.isEmpty) return;
    validateMidiRaw(bytes);
    using((arena) {
      final native = arena.allocate<UnsignedChar>(bytes.length);
      native.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
      _b.midi_out_raw(_handle, native, bytes.length);
    });
  }

  /// Internal: the raw native handle, for wiring this port as a
  /// [ClipTransport] sink. Not part of the public surface.
  Pointer<YseMidiOut> get handle => _handle;

  /// Destroy the underlying native port and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.midi_out_destroy(_handle);
    _handle = nullptr;
  }
}

/// Check that [bytes] is one complete, well-formed MIDI message for
/// [MidiOut.raw]; throws [ArgumentError] otherwise. [bytes] must not be
/// empty.
///
/// Internal (not exported): the engine sends whatever it is handed, so this
/// is the only line of defence against a malformed message, and the tests
/// exercise it without a MIDI device.
void validateMidiRaw(List<int> bytes) {
  for (var i = 0; i < bytes.length; i++) {
    final v = bytes[i];
    if (v < 0 || v > 0xFF) {
      throw ArgumentError.value(v, 'bytes[$i]', 'not a byte (0..255)');
    }
  }
  final status = bytes[0];
  String hex(int v) => '0x${v.toRadixString(16).toUpperCase().padLeft(2, '0')}';
  if (status < 0x80) {
    throw ArgumentError.value(
      bytes,
      'bytes',
      'first byte ${hex(status)} is not a status byte (running status is not '
          'supported)',
    );
  }

  if (status == 0xF0) {
    if (bytes.length < 2 || bytes.last != 0xF7) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'SysEx message must end with 0xF7',
      );
    }
    for (var i = 1; i < bytes.length - 1; i++) {
      if (bytes[i] >= 0x80) {
        throw ArgumentError.value(
          bytes,
          'bytes',
          'SysEx data byte ${hex(bytes[i])} at index $i has its high bit set',
        );
      }
    }
    return;
  }

  final int expected;
  if (status < 0xF0) {
    // Channel voice: program change (0xC_) and channel pressure (0xD_) carry
    // one data byte, everything else two.
    final kind = status & 0xF0;
    expected = (kind == 0xC0 || kind == 0xD0) ? 2 : 3;
  } else {
    expected = switch (status) {
      0xF1 || 0xF3 => 2, // MTC quarter frame, song select
      0xF2 => 3, // song position pointer
      0xF6 || >= 0xF8 => 1, // tune request, system realtime
      _ => throw ArgumentError.value(
        bytes,
        'bytes',
        status == 0xF7
            ? 'stray end-of-SysEx 0xF7 without a 0xF0'
            : 'undefined status byte ${hex(status)}',
      ),
    };
  }
  if (bytes.length != expected) {
    throw ArgumentError.value(
      bytes,
      'bytes',
      'status ${hex(status)} takes a $expected-byte message, got '
          '${bytes.length} bytes',
    );
  }
  for (var i = 1; i < bytes.length; i++) {
    if (bytes[i] >= 0x80) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'data byte ${hex(bytes[i])} at index $i has its high bit set',
      );
    }
  }
}

/// A raw MIDI message delivered through [MidiIn.rawMessages].
///
/// Bytes are copied out of the engine-owned buffer before the underlying
/// allocation is released, so [bytes] is safe to retain.
class MidiInRawMessage {
  /// Timestamp from RtMidi, in seconds (monotonically increasing within
  /// a single port session).
  final double timestamp;

  /// Full MIDI message bytes, exactly as RtMidi delivered them.
  final Uint8List bytes;

  /// Constructor — invoked internally by [MidiIn.rawMessages].
  MidiInRawMessage(this.timestamp, this.bytes);
}

/// A pre-decoded channel-voice MIDI message delivered through
/// [MidiIn.parsedMessages].
///
/// [status] is the high nibble of the first byte (`0x80`..`0xF0`),
/// [channel] is the low nibble (`0`..`15`). [data1] and [data2] are
/// `0` for messages shorter than 3 bytes.
class MidiInParsedMessage {
  /// Timestamp from RtMidi, in seconds.
  final double timestamp;

  /// Status nibble (`0x80`..`0xF0`) — Note-On, CC, etc.
  final int status;

  /// Wire-level MIDI channel, 0-based (`0`..`15`). Add one to address the
  /// same channel on a [Synth] or [ClipEvent], which count `1..16`.
  final int channel;

  /// First data byte (e.g. pitch for Note-On, controller for CC).
  final int data1;

  /// Second data byte (e.g. velocity for Note-On, value for CC).
  /// `0` for 1- or 2-byte messages.
  final int data2;

  /// Constructor — invoked internally by [MidiIn.parsedMessages].
  MidiInParsedMessage(
    this.timestamp,
    this.status,
    this.channel,
    this.data1,
    this.data2,
  );
}

/// MIDI input port (Windows / Linux only; backed by RtMidi upstream).
///
/// Enumerate device counts with [System.midiInDeviceCount] and names
/// with [System.midiInDeviceName], then open one with [MidiIn.open].
///
/// Two modes of consumption — subscribe to either or both:
///   * [rawMessages] — full message bytes as a [Uint8List].
///   * [parsedMessages] — pre-decoded channel-voice scalars.
///
/// Channel numbering has two bases. The parsed stream reports the
/// **wire-level, 0-based** channel (`0..15`, see
/// [MidiInParsedMessage.channel]), while [connectSynth]'s `channelFilter`
/// uses the musical layer's **1-based** numbering (`1..16`, `0` = every
/// channel) shared with [Synth] and [ClipEvent].
///
/// Native callbacks fire on RtMidi's internal input thread.
/// `NativeCallable.listener` posts each event back to the isolate that
/// created this `MidiIn`, so Dart code only ever sees messages
/// serialised in the isolate's event queue.
class MidiIn implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.midi_in_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseMidiIn> _handle;

  StreamController<MidiInRawMessage>? _rawController;
  MidiInRawBridge? _rawBridge;
  StreamController<MidiInParsedMessage>? _parsedController;
  NativeCallable<YseMidiInParsedCallbackFunction>? _parsedCallable;

  MidiIn._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Open the MIDI input device at [port].
  factory MidiIn.open(int port) {
    final b = bindings;
    final h = b.midi_in_create();
    if (h.address == 0) {
      throw YseException(
        'yse_midi_in_create returned null (Windows/Linux only)',
      );
    }
    b.midi_in_open(h, port);
    return MidiIn._(b, h);
  }

  /// Whether the underlying RtMidi port is currently open.
  bool get isOpen => _b.midi_in_is_open(_handle) != 0;

  /// Close the port. The instance remains valid but emits no further
  /// messages until re-created.
  void close() => _b.midi_in_close(_handle);

  /// Route incoming device MIDI into an internal [synth] (upstream #371).
  ///
  /// Every channel-voice message received on the open port is mapped to the
  /// synth's normalized note API and pushed onto its inbox on RtMidi's input
  /// thread. [channelFilter] is a 1-based `1..16` MIDI channel to accept, or
  /// `0` (the default) for every channel — note the parsed stream reports the
  /// same channel 0-based, so channel 1 there is filter `1` here. May be called for several synths (up to a
  /// small fixed cap); re-connecting an already-connected synth just updates
  /// its channel filter. [synth] must outlive the connection —
  /// [disconnectSynth] it (or close/dispose this port) before disposing the
  /// synth.
  void connectSynth(Synth synth, {int channelFilter = 0}) =>
      _b.midi_in_connect_synth(_handle, synth.handle, channelFilter);

  /// Stop routing incoming device MIDI into [synth]. Safe to call for a synth
  /// that was never connected.
  void disconnectSynth(Synth synth) =>
      _b.midi_in_disconnect_synth(_handle, synth.handle);

  /// Broadcast stream of raw MIDI messages. Lazily installs the native
  /// callback on first subscription and uninstalls when the last
  /// subscriber cancels.
  ///
  /// Messages still queued when the last subscriber cancels (or the port
  /// is [dispose]d) are not delivered, but their native buffers are still
  /// released.
  Stream<MidiInRawMessage> get rawMessages {
    final existing = _rawController;
    if (existing != null) return existing.stream;
    final controller = StreamController<MidiInRawMessage>.broadcast(
      onCancel: () {
        if (_rawController?.hasListener ?? false) return;
        // Every call made before the clear is queued ahead of the drain
        // marker. Upstream yvanvds/yse-soundengine#1176: the clear does
        // not yet wait for a dispatch that already copied the old
        // callback, so one in-flight message can still race the marker.
        _b.midi_in_set_raw_callback(_handle, nullptr, nullptr);
        _rawBridge?.retire();
        _rawBridge = null;
        _rawController?.close();
        _rawController = null;
      },
    );
    final bridge = MidiInRawBridge(controller.add);
    _b.midi_in_set_raw_callback(_handle, bridge.nativeFunction, nullptr);
    _rawBridge = bridge;
    _rawController = controller;
    return controller.stream;
  }

  /// Broadcast stream of pre-decoded MIDI messages. Lazily installs the
  /// native callback on first subscription and uninstalls when the last
  /// subscriber cancels.
  Stream<MidiInParsedMessage> get parsedMessages {
    final existing = _parsedController;
    if (existing != null) return existing.stream;
    final controller = StreamController<MidiInParsedMessage>.broadcast(
      onCancel: () {
        if (_parsedController?.hasListener ?? false) return;
        _b.midi_in_set_parsed_callback(_handle, nullptr, nullptr);
        _parsedCallable?.close();
        _parsedCallable = null;
        _parsedController?.close();
        _parsedController = null;
      },
    );
    final callable = NativeCallable<YseMidiInParsedCallbackFunction>.listener((
      double ts,
      int status,
      int channel,
      int data1,
      int data2,
      Pointer<Void> _,
    ) {
      controller.add(MidiInParsedMessage(ts, status, channel, data1, data2));
    });
    _b.midi_in_set_parsed_callback(_handle, callable.nativeFunction, nullptr);
    _parsedCallable = callable;
    _parsedController = controller;
    return controller.stream;
  }

  /// Destroy the underlying native port and detach the finalizer.
  ///
  /// Also clears both callbacks and closes [rawMessages] and
  /// [parsedMessages] (listeners get `onDone`).
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.midi_in_set_raw_callback(_handle, nullptr, nullptr);
    _b.midi_in_set_parsed_callback(_handle, nullptr, nullptr);
    // Destroying the port stops RtMidi's input thread, so after this no
    // call can still be on its way into either callable.
    _b.midi_in_destroy(_handle);
    _handle = nullptr;
    _rawBridge?.retire();
    _rawBridge = null;
    _parsedCallable?.close();
    _parsedCallable = null;
    _rawController?.close();
    _rawController = null;
    _parsedController?.close();
    _parsedController = null;
  }
}

/// How many raw MIDI-in buffers [MidiInRawBridge]s have released in this
/// isolate, delivered or dropped. Internal (not exported): lets the tests
/// prove no native block leaks.
int get midiInMessagesFreed => MidiInRawBridge._freed;

/// The `NativeCallable.listener` behind one installation of a [MidiIn]'s
/// raw callback. Internal to `lib/src/` (not exported); public only so the
/// tests can drive it without a MIDI device.
///
/// The engine hands over a malloc'd copy of each message; the listener
/// copies the bytes and frees the buffer with `yse_midi_in_free_message`,
/// exactly once.
///
/// Closing a listener drops the calls still queued on its port, which
/// would leak their buffers. So [retire] does not close it: it detaches
/// the sink and posts a drain marker (a NULL buffer, which the engine never
/// sends) through the same port. Port messages arrive in order, so when the
/// marker arrives every earlier call has been freed, and only then is the
/// callable closed. Same scheme as the patcher send bridge (#62).
class MidiInRawBridge {
  static int _freed = 0;

  void Function(MidiInRawMessage)? _sink;
  final void Function(Pointer<UnsignedChar>) _free;
  late final NativeCallable<YseMidiInRawCallbackFunction> _callable;

  /// Deliver every message to [sink] until [retire]. [free] releases each
  /// buffer and defaults to `yse_midi_in_free_message`; tests that post
  /// their own buffers pass the matching deallocator.
  MidiInRawBridge(
    void Function(MidiInRawMessage) sink, {
    void Function(Pointer<UnsignedChar>)? free,
  }) : _sink = sink,
       _free = free ?? bindings.midi_in_free_message {
    _callable = NativeCallable<YseMidiInRawCallbackFunction>.listener(_onCall);
  }

  /// The function pointer to install as the native raw callback.
  Pointer<NativeFunction<YseMidiInRawCallbackFunction>> get nativeFunction =>
      _callable.nativeFunction;

  void _onCall(
    double ts,
    Pointer<UnsignedChar> bytes,
    int len,
    Pointer<Void> _,
  ) {
    if (bytes.address == 0) {
      _callable.close(); // drain marker: nothing is queued behind it
      return;
    }
    final Uint8List copy;
    try {
      copy = Uint8List.fromList(bytes.cast<Uint8>().asTypedList(len));
    } finally {
      _free(bytes);
      _freed++;
    }
    _sink?.call(MidiInRawMessage(ts, copy));
  }

  /// Stop delivering and close the callable once its queue has drained.
  /// Call only after the engine can no longer invoke it.
  void retire() {
    _sink = null;
    _callable.nativeFunction.asFunction<DartYseMidiInRawCallbackFunction>()(
      0,
      nullptr,
      0,
      nullptr,
    );
  }
}
