import 'dart:ffi';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';
import 'library.dart';

/// A single musical event — pitch, volume, length, MIDI channel.
///
/// The fundamental unit for the music subsystem: [Motif]s are sequences
/// of [PNote]s (positioned [Note]s), and the [Player] generates notes
/// within a [Scale] constraint.
class Note implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.note_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseNote> _handle;

  Note._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Construct a note.
  ///
  /// [pitch] is a MIDI pitch (60 = middle C). [volume] is velocity in
  /// `[0, 1]`. [length] is the duration in seconds (0 = engine default).
  /// [channel] is the MIDI channel.
  factory Note({
    double pitch = 60,
    double volume = 1.0,
    double length = 0,
    int channel = 1,
  }) {
    final b = bindings;
    final h = b.note_create(pitch, volume, length, channel);
    if (h.address == 0) throw YseException('yse_note_create returned null');
    return Note._(b, h);
  }

  /// Internal: native handle.
  Pointer<YseNote> get handle => _handle;

  /// Replace all four fields in one call.
  void set({
    required double pitch,
    double volume = 1.0,
    double length = 0,
    int channel = 1,
  }) =>
      _b.note_set(_handle, pitch, volume, length, channel);

  /// MIDI pitch (60 = middle C).
  double get pitch => _b.note_get_pitch(_handle);
  set pitch(double value) => _b.note_set_pitch(_handle, value);

  /// Velocity in `[0, 1]`.
  double get volume => _b.note_get_volume(_handle);
  set volume(double value) => _b.note_set_volume(_handle, value);

  /// Duration in seconds.
  double get length => _b.note_get_length(_handle);
  set length(double value) => _b.note_set_length(_handle, value);

  /// MIDI channel.
  int get channel => _b.note_get_channel(_handle);
  set channel(int value) => _b.note_set_channel(_handle, value);

  /// Destroy the underlying native note and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.note_destroy(_handle);
    _handle = nullptr;
  }
}

/// A [Note] with a time position — the building block of a [Motif].
///
/// Position is measured from the start of the containing motif, in
/// seconds.
class PNote implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.pnote_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YsePNote> _handle;

  PNote._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Construct a positioned note.
  factory PNote({
    required double position,
    required double pitch,
    double volume = 1.0,
    double length = 0,
    int channel = 1,
  }) {
    final b = bindings;
    final h = b.pnote_create(position, pitch, volume, length, channel);
    if (h.address == 0) throw YseException('yse_pnote_create returned null');
    return PNote._(b, h);
  }

  /// Internal: native handle.
  Pointer<YsePNote> get handle => _handle;

  /// Time position from the start of the motif, in seconds.
  double get position => _b.pnote_get_position(_handle);
  set position(double value) => _b.pnote_set_position(_handle, value);

  /// MIDI pitch.
  double get pitch => _b.pnote_get_pitch(_handle);
  set pitch(double value) => _b.pnote_set_pitch(_handle, value);

  /// Velocity in `[0, 1]`.
  double get volume => _b.pnote_get_volume(_handle);
  set volume(double value) => _b.pnote_set_volume(_handle, value);

  /// Duration in seconds.
  double get length => _b.pnote_get_length(_handle);
  set length(double value) => _b.pnote_set_length(_handle, value);

  /// Destroy the underlying native pNote and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.pnote_destroy(_handle);
    _handle = nullptr;
  }
}

/// A set of allowed pitches.
///
/// Drives the [Player] so its generated notes stay in key, and
/// constrains the transpositions a [Motif] can take.
class Scale implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.scale_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseScale> _handle;

  Scale._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Construct an empty scale.
  factory Scale() {
    final b = bindings;
    final h = b.scale_create();
    if (h.address == 0) throw YseException('yse_scale_create returned null');
    return Scale._(b, h);
  }

  /// Internal: native handle.
  Pointer<YseScale> get handle => _handle;

  /// Add a pitch to the scale.
  ///
  /// [octaveStep] controls automatic octave replication: 12 (default)
  /// replicates the pitch at every octave; values <= 0 add only the
  /// exact pitch.
  void add(double pitch, {double octaveStep = 12}) =>
      _b.scale_add(_handle, pitch, octaveStep);

  /// Remove a pitch (with optional octave replication).
  void remove(double pitch, {double octaveStep = 12}) =>
      _b.scale_remove(_handle, pitch, octaveStep);

  /// Whether [pitch] is a member of the scale.
  bool has(double pitch) => _b.scale_has(_handle, pitch) != 0;

  /// Nearest in-scale pitch to [pitch].
  double nearest(double pitch) => _b.scale_nearest(_handle, pitch);

  /// Number of pitches in the scale.
  int get size => _b.scale_size(_handle);

  /// Remove every pitch.
  void clear() => _b.scale_clear(_handle);

  /// Destroy the underlying native scale and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.scale_destroy(_handle);
    _handle = nullptr;
  }
}

/// A re-usable phrase or pattern — a sequence of [PNote]s.
///
/// Hand it to a [Player] which will trigger it at appropriate moments.
class Motif implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.motif_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseMotif> _handle;

  Motif._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Construct an empty motif.
  factory Motif() {
    final b = bindings;
    final h = b.motif_create();
    if (h.address == 0) throw YseException('yse_motif_create returned null');
    return Motif._(b, h);
  }

  /// Internal: native handle.
  Pointer<YseMotif> get handle => _handle;

  /// Append a positioned note.
  void add(PNote note) => _b.motif_add(_handle, note._handle);

  /// Remove every note.
  void clear() => _b.motif_clear(_handle);

  /// Set the motif length explicitly, in seconds.
  set length(double value) => _b.motif_set_length(_handle, value);

  /// Set the motif length automatically to the end of the last note.
  void autoSetLength() => _b.motif_set_length_auto(_handle);

  /// Current motif length in seconds.
  double get length => _b.motif_get_length(_handle);

  /// Transpose every note by [pitch] semitones.
  void transpose(double pitch) => _b.motif_transpose(_handle, pitch);

  /// Restrict legal starting pitches.
  ///
  /// When the [Player] picks a transposition for this motif it picks one
  /// whose starting note belongs to [validPitches].
  void setFirstPitch(Scale validPitches) =>
      _b.motif_set_first_pitch(_handle, validPitches.handle);

  /// Whether the motif contains any notes.
  bool get isEmpty => _b.motif_empty(_handle) != 0;

  /// Number of notes.
  int get size => _b.motif_size(_handle);

  /// Destroy the underlying native motif and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.motif_destroy(_handle);
    _handle = nullptr;
  }
}

/// Generative note sequencer.
///
/// Plays random notes within configurable pitch / velocity / gap / length
/// ranges, optionally constrained to a [Scale], optionally drawing from
/// one or more weighted [Motif]s instead of pure randomness. Numeric
/// setters accept an optional [fade] parameter that interpolates from
/// the current value to the target over that many seconds.
///
/// **Note**: the upstream `YSE::player::create(synth&)` factory is
/// commented out, and there is no other path to initialise the player's
/// implementation pointer. Calling any method on a freshly-constructed
/// [Player] therefore crashes the process (null pimpl dereference) —
/// this surface is dead until the synth subsystem returns to the public
/// API. The class is exposed here so the wrapping is in place when that
/// happens; do not call its methods until then.
class Player implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.player_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YsePlayer> _handle;

  Player._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Construct a player.
  ///
  /// As of engine v2.3.0 `yse_player_create` takes a `YseSynth*`. The synth
  /// subsystem does not yet have an idiomatic Dart wrapper (tracked as a
  /// separate issue in this batch), so a null synth is passed here — matching
  /// the dead-surface contract documented on this class. Do not call this
  /// class's methods until the synth wiring lands.
  factory Player() {
    final b = bindings;
    final h = b.player_create(nullptr);
    if (h.address == 0) throw YseException('yse_player_create returned null');
    return Player._(b, h);
  }

  /// Start producing notes.
  void play() => _b.player_play(_handle);

  /// Stop producing notes.
  void stop() => _b.player_stop(_handle);

  /// Whether the player is currently producing notes.
  bool get isPlaying => _b.player_is_playing(_handle) != 0;

  /// Set the lowest pitch the player may produce (0..126). [fade] interpolates.
  void setMinimumPitch(double target, {Duration fade = Duration.zero}) =>
      _b.player_set_minimum_pitch(_handle, target, fade.inMilliseconds / 1000.0);

  /// Set the highest pitch the player may produce (1..127). [fade] interpolates.
  void setMaximumPitch(double target, {Duration fade = Duration.zero}) =>
      _b.player_set_maximum_pitch(_handle, target, fade.inMilliseconds / 1000.0);

  /// Set the lowest velocity (0..0.999999). [fade] interpolates.
  void setMinimumVelocity(double target, {Duration fade = Duration.zero}) =>
      _b.player_set_minimum_velocity(_handle, target, fade.inMilliseconds / 1000.0);

  /// Set the highest velocity (0.000001..1). [fade] interpolates.
  void setMaximumVelocity(double target, {Duration fade = Duration.zero}) =>
      _b.player_set_maximum_velocity(_handle, target, fade.inMilliseconds / 1000.0);

  /// Set the minimum gap between successive notes / motifs, in seconds.
  void setMinimumGap(double target, {Duration fade = Duration.zero}) =>
      _b.player_set_minimum_gap(_handle, target, fade.inMilliseconds / 1000.0);

  /// Set the maximum gap between successive notes / motifs, in seconds.
  void setMaximumGap(double target, {Duration fade = Duration.zero}) =>
      _b.player_set_maximum_gap(_handle, target, fade.inMilliseconds / 1000.0);

  /// Set the minimum note length, in seconds (used when no motif is active).
  void setMinimumLength(double target, {Duration fade = Duration.zero}) =>
      _b.player_set_minimum_length(_handle, target, fade.inMilliseconds / 1000.0);

  /// Set the maximum note length, in seconds (used when no motif is active).
  void setMaximumLength(double target, {Duration fade = Duration.zero}) =>
      _b.player_set_maximum_length(_handle, target, fade.inMilliseconds / 1000.0);

  /// Number of simultaneous voices.
  void setVoices(int target, {Duration fade = Duration.zero}) =>
      _b.player_set_voices(_handle, target, fade.inMilliseconds / 1000.0);

  /// Constrain generated pitches to [scale].
  ///
  /// The player keeps its own copy — modifying [scale] after this
  /// call has no effect on the player.
  void setScale(Scale scale, {Duration fade = Duration.zero}) =>
      _b.player_set_scale(_handle, scale.handle, fade.inMilliseconds / 1000.0);

  /// Add a [motif] to the player's pool. Picked weighted by [weight].
  void addMotif(Motif motif, {int weight = 1}) =>
      _b.player_add_motif(_handle, motif.handle, weight);

  /// Remove a previously added motif.
  void removeMotif(Motif motif) => _b.player_remove_motif(_handle, motif.handle);

  /// Adjust the selection weight of an already-added motif.
  void adjustMotifWeight(Motif motif, int weight) =>
      _b.player_adjust_motif_weight(_handle, motif.handle, weight);

  /// Probability that the player plays only part of a motif (0..1).
  void playPartialMotifs(double target, {Duration fade = Duration.zero}) =>
      _b.player_play_partial_motifs(_handle, target, fade.inMilliseconds / 1000.0);

  /// Probability that the player draws notes from a motif vs. random (0..1).
  void playMotifs(double target, {Duration fade = Duration.zero}) =>
      _b.player_play_motifs(_handle, target, fade.inMilliseconds / 1000.0);

  /// Probability that motif notes are quantised to the active scale (0..1).
  void fitMotifsToScale(double target, {Duration fade = Duration.zero}) =>
      _b.player_fit_motifs_to_scale(_handle, target, fade.inMilliseconds / 1000.0);

  /// Destroy the underlying native player and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.player_destroy(_handle);
    _handle = nullptr;
  }
}
