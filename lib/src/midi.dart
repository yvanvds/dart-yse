import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';
import 'library.dart';

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
          'yse_midi_out_create returned null (Windows/Linux only)');
    }
    b.midi_out_open(h, port);
    return MidiOut._(b, h);
  }

  /// Send Note-On. [channel] is 0..15, [pitch] is 0..127.
  void noteOn({required int channel, required int pitch, required int velocity}) =>
      _b.midi_out_note_on(_handle, channel, pitch, velocity);

  /// Send Note-Off.
  void noteOff({required int channel, required int pitch, int velocity = 0}) =>
      _b.midi_out_note_off(_handle, channel, pitch, velocity);

  /// Send polyphonic key-pressure (aftertouch).
  void polyPressure({required int channel, required int pitch, required int value}) =>
      _b.midi_out_poly_pressure(_handle, channel, pitch, value);

  /// Send channel-pressure.
  void channelPressure({required int channel, required int value}) =>
      _b.midi_out_channel_pressure(_handle, channel, value);

  /// Send program-change.
  void programChange({required int channel, required int value}) =>
      _b.midi_out_program_change(_handle, channel, value);

  /// Send control-change.
  void controlChange({required int channel, required int controller, required int value}) =>
      _b.midi_out_control_change(_handle, channel, controller, value);

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

  /// Destroy the underlying native port and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.midi_out_destroy(_handle);
    _handle = nullptr;
  }
}
