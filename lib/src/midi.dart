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

  /// Send All-Notes-Off on a specific [channel].
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
  void raw3(int a, int b, int c) => _b.midi_out_raw3(_handle, a, b, c);

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

  /// MIDI channel (`0`..`15`).
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
  NativeCallable<YseMidiInRawCallbackFunction>? _rawCallable;
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
  /// thread. [channelFilter] is a `1..16` MIDI channel to accept, or `0` (the
  /// default) for every channel. May be called for several synths (up to a
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
  Stream<MidiInRawMessage> get rawMessages {
    final existing = _rawController;
    if (existing != null) return existing.stream;
    final controller = StreamController<MidiInRawMessage>.broadcast(
      onCancel: () {
        if (_rawController?.hasListener ?? false) return;
        _b.midi_in_set_raw_callback(_handle, nullptr, nullptr);
        _rawCallable?.close();
        _rawCallable = null;
        _rawController?.close();
        _rawController = null;
      },
    );
    final freeFn = _b.midi_in_free_message;
    final callable = NativeCallable<YseMidiInRawCallbackFunction>.listener((
      double ts,
      Pointer<UnsignedChar> bytes,
      int len,
      Pointer<Void> _,
    ) {
      try {
        // Engine transferred ownership of `bytes`. Copy the contents into a
        // Dart-owned buffer before releasing the malloc'd allocation.
        final copy = Uint8List.fromList(bytes.cast<Uint8>().asTypedList(len));
        controller.add(MidiInRawMessage(ts, copy));
      } finally {
        freeFn(bytes);
      }
    });
    _b.midi_in_set_raw_callback(_handle, callable.nativeFunction, nullptr);
    _rawCallable = callable;
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
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.midi_in_set_raw_callback(_handle, nullptr, nullptr);
    _b.midi_in_set_parsed_callback(_handle, nullptr, nullptr);
    _rawCallable?.close();
    _rawCallable = null;
    _parsedCallable?.close();
    _parsedCallable = null;
    _rawController?.close();
    _rawController = null;
    _parsedController?.close();
    _parsedController = null;
    _b.midi_in_destroy(_handle);
    _handle = nullptr;
  }
}
