import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';
import 'library.dart';
import 'midi.dart';
import 'synth.dart';
import 'system.dart';

/// One timed note event on a [ClipTransport].
///
/// Positioned in beats on the clip's bound [DomainClock]. The engine fires
/// the note-on at [startBeat] and the matching note-off [durationBeats]
/// later, all from the audio thread — the Dart side never dispatches a note.
class ClipEvent {
  /// Beat within the loop at which the note starts (`>= 0`).
  final double startBeat;

  /// Note length in beats.
  final double durationBeats;

  /// MIDI channel, `1..16`.
  final int channel;

  /// MIDI note number, `0..127`.
  final int pitch;

  /// Velocity, normalized to `[0, 1]`.
  final double velocity;

  /// Optional per-note pitch bend in `[-1, 1]` for microtonal voicing;
  /// `0` (the default) applies no bend.
  final double pitchBend;

  /// Construct a note event. [velocity] defaults to full, [pitchBend] to none.
  const ClipEvent({
    required this.startBeat,
    required this.durationBeats,
    required this.channel,
    required this.pitch,
    this.velocity = 1.0,
    this.pitchBend = 0.0,
  });
}

/// Engine-driven MIDI clip playback (issue #21).
///
/// A clip loops a flat, beat-timed [ClipEvent] list against a bound
/// [DomainClock], dispatched from the audio thread. Because the engine owns
/// *when* every event fires, playback does not jitter under UI-isolate load
/// the way a timer-driven `noteOn`/`noteOff` over FFI does.
///
/// Wire a clip to one or more sinks — external MIDI-out ports via
/// [connectMidiOut] (and the [ClipTransport.new] `midiOut` shortcut). Route
/// the playback with [setEvents] (replaceable while playing; the engine swaps
/// the list at the next audio-block boundary and still delivers note-offs for
/// notes sounding across the swap), then [play] / [stop].
///
/// Threading (CLAUDE.md): construct and drive this from the [System] isolate.
/// The audio thread performs the actual dispatch; MIDI sends run on a
/// dedicated sender thread, so the audio callback never touches the device.
///
/// Route a clip to an internal [Synth] instead of (or alongside) external
/// MIDI-out ports via [connectSynth] — the clip drives the synth's
/// `noteOn` / `noteOff` from the audio thread.
class ClipTransport implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.clip_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseClip> _handle;

  ClipTransport._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Create a clip bound to [clock], optionally connecting [midiOut] as a
  /// sink in one step.
  ///
  /// Throws [YseException] if the native clip cannot be created or if no live
  /// clock owns `clock.name`.
  factory ClipTransport(DomainClock clock, {MidiOut? midiOut}) {
    final b = bindings;
    final h = b.clip_create();
    if (h.address == 0) {
      throw YseException('yse_clip_create returned null');
    }
    final clip = ClipTransport._(b, h);
    try {
      clip.bind(clock);
      if (midiOut != null) clip.connectMidiOut(midiOut);
      return clip;
    } catch (_) {
      clip.dispose();
      rethrow;
    }
  }

  /// Bind (or re-bind) the clip to a live domain [clock] by name. The bound
  /// clock must outlive the clip.
  ///
  /// Throws [YseException] if no live clock owns `clock.name`.
  void bind(DomainClock clock) {
    final ok = using((arena) {
      final cname = clock.name.toNativeUtf8(allocator: arena);
      return _b.clip_bind(_handle, cname.cast());
    });
    if (ok == 0) {
      throw YseException('yse_clip_bind: no live clock named "${clock.name}"');
    }
  }

  /// Route this clip's playback to an external MIDI output port. [out] must
  /// already have opened a port. May be called for several ports.
  void connectMidiOut(MidiOut out) =>
      _b.clip_connect_midi_out(_handle, out.handle);

  /// Stop routing this clip to [out].
  void disconnectMidiOut(MidiOut out) =>
      _b.clip_disconnect_midi_out(_handle, out.handle);

  /// Route this clip's playback to an internal [synth]. The engine drives the
  /// synth's note events from the audio thread. [synth] must outlive the clip
  /// (or be disconnected first). May be called for several synths.
  void connectSynth(Synth synth) =>
      _b.clip_connect_synth(_handle, synth.handle);

  /// Stop routing this clip to [synth].
  void disconnectSynth(Synth synth) =>
      _b.clip_disconnect_synth(_handle, synth.handle);

  /// Replace the note-event list and set the loop length in one call.
  ///
  /// The swap is safe while [isPlaying]: the engine applies the new list at
  /// the next audio-block boundary and still delivers note-offs for notes
  /// sounding across the swap. [loopBeats] is the loop length in beats; a
  /// value `<= 0` disables looping (the events fire once). Passing an empty
  /// [events] list clears the clip.
  void setEvents(List<ClipEvent> events, {required double loopBeats}) {
    using((arena) {
      final n = events.length;
      if (n == 0) {
        _b.clip_set_events(_handle, nullptr, 0);
      } else {
        final buf = arena<YseClipEvent>(n);
        for (var i = 0; i < n; i++) {
          final e = events[i];
          final slot = buf[i];
          slot.start_beat = e.startBeat;
          slot.duration_beats = e.durationBeats;
          slot.channel = e.channel;
          slot.pitch = e.pitch;
          slot.velocity = e.velocity;
          slot.pitch_bend = e.pitchBend;
        }
        _b.clip_set_events(_handle, buf, n);
      }
    });
    _b.clip_set_loop_length(_handle, loopBeats);
  }

  /// Start (or resume) playback.
  void play() => _b.clip_play(_handle);

  /// Stop playback.
  void stop() => _b.clip_stop(_handle);

  /// Whether the clip is currently playing.
  bool get isPlaying => _b.clip_is_playing(_handle) != 0;

  /// Destroy the underlying native clip and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.clip_destroy(_handle);
    _handle = nullptr;
  }
}
