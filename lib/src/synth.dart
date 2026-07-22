import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'enums.dart';
import 'exception.dart';
import 'ffi_helpers.dart';
import 'library.dart';
import 'pos.dart';

/// A loadable SFZ sampler instrument (issue #23 / engine issue #174).
///
/// A shareable, engine-lifetime-independent asset: a parsed SFZ region table
/// plus the resident PCM it references. Load one from disk with
/// [SfzInstrument.load], or synthesise a single-region instrument around one
/// sample file with [SfzInstrument.fromSample]. Hand it to a synth's sampler
/// voice pool via [Synth.addSamplerVoices].
///
/// The handle is reference-counted: a voice group that renders the instrument
/// retains its own share, so it is safe to [dispose] this handle right after
/// [Synth.addSamplerVoices] returns, and safe to hold or dispose it across
/// [System] close. Loading decodes samples on the calling isolate (never the
/// audio thread), so construct these off any latency-sensitive path.
class SfzInstrument implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.sfz_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseSfzInstrument> _handle;

  SfzInstrument._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Load and preload an `.sfz` file, decoding every unique sample into RAM.
  ///
  /// Throws [YseException] if the file is unreadable, empty, or has no
  /// playable region.
  factory SfzInstrument.load(String path) {
    final b = bindings;
    final h = using((arena) {
      final p = path.toNativeUtf8(allocator: arena);
      return b.sfz_load(p.cast());
    });
    if (h.address == 0) {
      throw YseException('yse_sfz_load failed for "$path"');
    }
    return SfzInstrument._(b, h);
  }

  /// Build a one-region instrument around a single sample [file] without an
  /// `.sfz` text file.
  ///
  /// [root] is the key that plays the sample untransposed; [low] and [high]
  /// bound the playable key range. [attack] and [release] are the amplitude
  /// envelope times in seconds; [maxLength] caps a non-looping one-shot in
  /// seconds. [name] is an optional label used only for identification.
  ///
  /// Throws [YseException] if the sample is missing or unreadable.
  factory SfzInstrument.fromSample(
    String file, {
    String? name,
    int root = 60,
    int low = 0,
    int high = 127,
    double attack = 0.0,
    double release = 0.1,
    double maxLength = 0.0,
  }) {
    final b = bindings;
    final h = using((arena) {
      final cfg = arena<YseSamplerConfig>();
      cfg.ref
        ..name = name == null
            ? nullptr
            : name.toNativeUtf8(allocator: arena).cast()
        ..file = file.toNativeUtf8(allocator: arena).cast()
        ..root = root
        ..low = low
        ..high = high
        ..attack = attack
        ..release = release
        ..max_length = maxLength;
      return b.sfz_load_config(cfg);
    });
    if (h.address == 0) {
      throw YseException('yse_sfz_load_config failed for "$file"');
    }
    return SfzInstrument._(b, h);
  }

  /// Whether the instrument is playable (a valid region table with at least
  /// one resident sample).
  bool get isValid => _b.sfz_is_valid(_handle) != 0;

  /// Raw native handle, for sibling wrappers within `lib/src/`
  /// (e.g. [Synth.addSamplerVoices]). Not part of the public API surface.
  Pointer<YseSfzInstrument> get handle => _handle;

  /// Release the instrument. Idempotent; a double free is a logged no-op.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.sfz_destroy(_handle);
    _handle = nullptr;
  }
}

/// A parsed DX7 SysEx bank (issue #23 / engine issue #177).
///
/// A list of FM patches (1 for a single-voice dump, 32 for a packed bulk
/// dump) imported from a `.syx` file. Select a patch into a synth's FM voice
/// pool with [Synth.setFmPatch] — the patch is copied into the synth, so this
/// bank may be [dispose]d afterwards.
class Dx7Bank implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.dx7_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseDx7Bank> _handle;

  Dx7Bank._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Load and parse a DX7 `.syx` file into a bank.
  ///
  /// Throws [YseException] if the file is missing, unreadable, has a bad
  /// header, the wrong length, or a checksum mismatch.
  factory Dx7Bank.load(String path) {
    final b = bindings;
    final h = using((arena) {
      final p = path.toNativeUtf8(allocator: arena);
      return b.dx7_import_sysex(p.cast());
    });
    if (h.address == 0) {
      throw YseException('yse_dx7_import_sysex failed for "$path"');
    }
    return Dx7Bank._(b, h);
  }

  /// Number of patches in the bank (1 or 32).
  int get patchCount => _b.dx7_get_patch_count(_handle);

  /// The space-trimmed name of patch [index], or an empty string for an
  /// out-of-range index.
  String patchName(int index) => fetchString(
    (buf, cap) => _b.dx7_get_patch_name(_handle, index, buf, cap),
  );

  /// Raw native handle, for sibling wrappers within `lib/src/`
  /// (e.g. [Synth.setFmPatch]). Not part of the public API surface.
  Pointer<YseDx7Bank> get handle => _handle;

  /// Release the bank. Idempotent; a double free is a logged no-op.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.dx7_destroy(_handle);
    _handle = nullptr;
  }
}

/// Which built-in per-note position handler a [Synth] attaches, and its
/// configuration (issue #23 / engine issue #171 — "the swarm").
///
/// A handler gives every voice its own 3D position and movement. Build one
/// with a factory constructor and pass it to [Synth.setPositionHandler]
/// *before* the synth is attached/played. All positions are in the same
/// coordinate frame as a [Sound] position; the shared centre of the spread /
/// orbit handlers can be steered at runtime with [Synth.setHandlerCenter].
class PositionHandler {
  final YseSynthPositionHandler _kind;
  final double _staticX;
  final double _staticY;
  final double _staticZ;
  final double _spreadRadius;
  final int _spreadSeed;
  final double _orbitRadius;
  final double _orbitVelocityRadius;
  final double _orbitAftertouchWiden;
  final double _orbitRate;
  final double _orbitHeight;
  final double _orbitReleaseSlow;

  const PositionHandler._(
    this._kind, {
    double staticX = 0,
    double staticY = 0,
    double staticZ = 0,
    double spreadRadius = 0,
    int spreadSeed = 0,
    double orbitRadius = 0,
    double orbitVelocityRadius = 0,
    double orbitAftertouchWiden = 0,
    double orbitRate = 0,
    double orbitHeight = 0,
    double orbitReleaseSlow = 0,
  }) : _staticX = staticX,
       _staticY = staticY,
       _staticZ = staticZ,
       _spreadRadius = spreadRadius,
       _spreadSeed = spreadSeed,
       _orbitRadius = orbitRadius,
       _orbitVelocityRadius = orbitVelocityRadius,
       _orbitAftertouchWiden = orbitAftertouchWiden,
       _orbitRate = orbitRate,
       _orbitHeight = orbitHeight,
       _orbitReleaseSlow = orbitReleaseSlow;

  /// Every voice sounds from one fixed position `(x, y, z)`.
  const PositionHandler.fixed(double x, double y, double z)
    : this._(
        YseSynthPositionHandler.YSE_POSITION_HANDLER_STATIC,
        staticX: x,
        staticY: y,
        staticZ: z,
      );

  /// Each voice is scattered to a random point within [radius] of the centre.
  ///
  /// A given [seed] reproduces the same scatter.
  const PositionHandler.randomSpread({double radius = 1.0, int seed = 0})
    : this._(
        YseSynthPositionHandler.YSE_POSITION_HANDLER_RANDOM_SPREAD,
        spreadRadius: radius,
        spreadSeed: seed,
      );

  /// Each voice orbits the centre — the "swarm".
  ///
  /// [radius] is the base orbit radius; [velocityRadius] adds extra radius at
  /// full velocity; [aftertouchWiden] is the fraction of that extra radius
  /// reached at full aftertouch. [rate] is the angular speed in radians per
  /// second, [height] the vertical offset of the orbit plane, and
  /// [releaseSlow] a rate multiplier applied once a note is released.
  const PositionHandler.orbit({
    double radius = 1.0,
    double velocityRadius = 0.0,
    double aftertouchWiden = 0.0,
    double rate = 1.0,
    double height = 0.0,
    double releaseSlow = 1.0,
  }) : this._(
         YseSynthPositionHandler.YSE_POSITION_HANDLER_ORBIT,
         orbitRadius: radius,
         orbitVelocityRadius: velocityRadius,
         orbitAftertouchWiden: aftertouchWiden,
         orbitRate: rate,
         orbitHeight: height,
         orbitReleaseSlow: releaseSlow,
       );

  /// Populate a native params struct allocated in [arena].
  Pointer<YseSynthPositionParams> _toNative(Allocator arena) {
    final p = arena<YseSynthPositionParams>();
    p.ref
      ..static_x = _staticX
      ..static_y = _staticY
      ..static_z = _staticZ
      ..spread_radius = _spreadRadius
      ..spread_seed = _spreadSeed
      ..orbit_radius = _orbitRadius
      ..orbit_velocity_radius = _orbitVelocityRadius
      ..orbit_aftertouch_widen = _orbitAftertouchWiden
      ..orbit_rate = _orbitRate
      ..orbit_height = _orbitHeight
      ..orbit_release_slow = _orbitReleaseSlow;
    return p;
  }
}

/// A polyphonic synthesiser voice pool rendered behind one [Sound]
/// (issue #23 / engine issues #145–#149).
///
/// A synth owns polyphony, voice allocation, voice stealing and full
/// keyboard/pedal state; you drive it with note, controller and pedal events.
/// The usual flow is:
///
/// 1. Build a voice pool from a built-in voice type — [addSineVoices],
///    [addVaVoices], [addFmVoices] or [addSamplerVoices].
/// 2. Wrap it in a positioned sound with `Sound.fromSynth` (the synth must
///    outlive that sound).
/// 3. Play notes with [noteOn] / [noteOff].
///
/// Voice cloning happens off the audio thread on the engine's setup pool, so
/// a synth becomes playable a short moment *after* an `addVoices` call
/// returns — poll [voiceCount] for the cloned count, exactly as a file-backed
/// [Sound] is not playable until its buffer finishes loading. Voices must be
/// added before the synth is attached/played; adding a group afterwards is
/// rejected.
///
/// Channels follow the engine convention: `0` = omni (all channels), `1..16`
/// address a specific MIDI channel. Velocity, controller and aftertouch
/// values are normalised to `[0, 1]`; the pitch wheel to `[-1, 1]`.
///
/// Threading (CLAUDE.md): construct and drive this from the [System] isolate.
/// The engine's audio-thread note-rewrite hook (`yse_synth_set_note_callback`)
/// is intentionally not surfaced — it fires on the audio thread, which cannot
/// safely re-enter Dart, the same reason custom voices and position handlers
/// stay unwrapped.
class Synth implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.synth_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseSynth> _handle;

  Synth._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Create and register a synth, ready to receive voices and note events.
  ///
  /// Throws [YseException] if the native synth cannot be allocated.
  factory Synth() {
    final b = bindings;
    final h = b.synth_create();
    if (h.address == 0) {
      throw YseException('yse_synth_create returned null');
    }
    return Synth._(b, h);
  }

  /// Whether the synth has a live native implementation.
  bool get isValid => _b.synth_is_valid(_handle) != 0;

  /// Total number of allocated (cloned) voices across every group. Zero until
  /// the setup pool finishes cloning — poll this to know the synth is
  /// playable.
  int get voiceCount => _b.synth_get_num_voices(_handle);

  /// Raw native handle, for sibling wrappers within `lib/src/` (e.g.
  /// `ClipTransport.connectSynth`). Not part of the public API surface.
  Pointer<YseSynth> get handle => _handle;

  // ─── voice groups ─────────────────────────────────────────────────────────

  /// Add a group of [count] built-in sine voices (a sine oscillator shaped by
  /// an ADSR envelope) responding to note numbers in `[lowestNote,
  /// highestNote]` on [channel] (`0` = omni). May be called several times to
  /// build layered or split keyboards. [attack], [decay] and [release] are in
  /// seconds; [sustain] is a level in `[0, 1]`.
  ///
  /// Must be called before the synth is played. Throws [YseException] if the
  /// group is rejected.
  void addSineVoices(
    int count, {
    int channel = 0,
    int lowestNote = 0,
    int highestNote = 127,
    double attack = 0.01,
    double decay = 0.1,
    double sustain = 0.8,
    double release = 0.2,
  }) {
    checkStatus(
      _b.synth_add_voices_sine(
        _handle,
        count,
        channel,
        lowestNote,
        highestNote,
        attack,
        decay,
        sustain,
        release,
      ),
      _b,
    );
  }

  /// Add a group of [count] SFZ sampler voices rendering [instrument],
  /// responding to note numbers in `[lowestNote, highestNote]` on [channel]
  /// (`0` = omni). Filtering by [channel] lets a sampler pool respond only to
  /// events broadcast on its MIDI channel — e.g. per-voice routing from a
  /// [ClipTransport].
  ///
  /// The instrument's region table and PCM are shared with the voice group,
  /// which retains its own reference — so [instrument] may be disposed right
  /// after this returns. Throws [YseException] if the group is rejected.
  void addSamplerVoices(
    SfzInstrument instrument,
    int count, {
    int channel = 0,
    int lowestNote = 0,
    int highestNote = 127,
  }) {
    checkStatus(
      _b.synth_add_voices_sampler(
        _handle,
        instrument.handle,
        count,
        channel,
        lowestNote,
        highestNote,
      ),
      _b,
    );
  }

  /// Add a group of [count] virtual-analog + wavetable voices with a fresh
  /// default patch, responding to note numbers in `[lowestNote, highestNote]`
  /// on [channel] (`0` = omni). Filtering by [channel] lets a VA pool respond
  /// only to events broadcast on its MIDI channel — e.g. per-voice routing
  /// from a [ClipTransport].
  ///
  /// Establishes the synth's VA patch, which the `setVa*` setters steer. Call
  /// once per synth. Throws [YseException] on failure.
  void addVaVoices(
    int count, {
    int channel = 0,
    int lowestNote = 0,
    int highestNote = 127,
  }) {
    checkStatus(
      _b.synth_add_voices_va(_handle, count, channel, lowestNote, highestNote),
      _b,
    );
  }

  /// Add a group of [count] DX7-class 6-operator FM voices with the built-in
  /// sine test patch, responding to note numbers in `[lowestNote, highestNote]`
  /// on [channel] (`0` = omni). Filtering by [channel] lets an FM pool respond
  /// only to events broadcast on its MIDI channel — e.g. per-voice routing
  /// from a [ClipTransport].
  ///
  /// Establishes the synth's FM patch — select a DX7 voice into it with
  /// [setFmPatch], or dial the headline params with the `setFm*` setters. Call
  /// once per synth. Throws [YseException] on failure.
  void addFmVoices(
    int count, {
    int channel = 0,
    int lowestNote = 0,
    int highestNote = 127,
  }) {
    checkStatus(
      _b.synth_add_voices_fm(_handle, count, channel, lowestNote, highestNote),
      _b,
    );
  }

  // ─── notes and control ────────────────────────────────────────────────────

  /// Start a note. [velocity] is normalised to `[0, 1]`.
  void noteOn(int noteNumber, {int channel = 1, double velocity = 1.0}) =>
      _b.synth_note_on(_handle, channel, noteNumber, velocity);

  /// Release a note. [velocity] is the release velocity, normalised to
  /// `[0, 1]`.
  void noteOff(int noteNumber, {int channel = 1, double velocity = 0.0}) =>
      _b.synth_note_off(_handle, channel, noteNumber, velocity);

  /// Release every held note on [channel] (`0` = all channels). Voices enter
  /// their normal release; they are not cut.
  void allNotesOff({int channel = 0}) =>
      _b.synth_all_notes_off(_handle, channel);

  /// Bend every voice on [channel]. [value] is normalised to `[-1, 1]`
  /// (`0` = centre).
  void pitchWheel(double value, {int channel = 1}) =>
      _b.synth_pitch_wheel(_handle, channel, value);

  /// Send a control-change on [channel]. [value] is normalised to `[0, 1]`.
  /// CC 64 / 66 / 67 act as the sustain / sostenuto / soft pedals; other CC
  /// numbers are stored as the channel's last controller value.
  void controller(int number, double value, {int channel = 1}) =>
      _b.synth_controller(_handle, channel, number, value);

  /// Apply aftertouch pressure, normalised to `[0, 1]`. A [noteNumber] of
  /// `-1` (the default) is channel-wide; otherwise only the voice(s) sounding
  /// that note receive it.
  void aftertouch(double value, {int channel = 1, int noteNumber = -1}) =>
      _b.synth_aftertouch(_handle, channel, noteNumber, value);

  /// Set the sustain pedal (CC 64) on [channel].
  void sustain(bool down, {int channel = 1}) =>
      _b.synth_sustain(_handle, channel, down ? 1 : 0);

  /// Set the sostenuto pedal (CC 66) on [channel].
  void sostenuto(bool down, {int channel = 1}) =>
      _b.synth_sostenuto(_handle, channel, down ? 1 : 0);

  /// Set the soft pedal (CC 67) on [channel].
  void softPedal(bool down, {int channel = 1}) =>
      _b.synth_soft_pedal(_handle, channel, down ? 1 : 0);

  // ─── VA patch parameters ──────────────────────────────────────────────────
  // Every VA setter is a glitch-free atomic on the audio thread, so all are
  // safe to call while voices play. `osc` is the oscillator index 0..2.

  /// Set oscillator [osc]'s waveform.
  void setVaOscWave(int osc, VaWaveform wave) =>
      _b.synth_va_set_osc_wave(_handle, osc, wave.native);

  /// Set oscillator [osc]'s detune in semitones.
  void setVaOscDetune(int osc, double semitones) =>
      _b.synth_va_set_osc_detune(_handle, osc, semitones);

  /// Set oscillator [osc]'s output level.
  void setVaOscLevel(int osc, double level) =>
      _b.synth_va_set_osc_level(_handle, osc, level);

  /// Set oscillator [osc]'s pulse width (for [VaWaveform.pulse]).
  void setVaOscPulseWidth(int osc, double width) =>
      _b.synth_va_set_osc_pulse_width(_handle, osc, width);

  /// Set the wavetable morph position (for [VaWaveform.wavetable]).
  void setVaWavetablePosition(double position) =>
      _b.synth_va_set_wavetable_position(_handle, position);

  /// Set the filter cutoff in Hz.
  void setVaCutoff(double hz) => _b.synth_va_set_cutoff(_handle, hz);

  /// Set the filter resonance.
  void setVaResonance(double resonance) =>
      _b.synth_va_set_resonance(_handle, resonance);

  /// Set the filter key-tracking amount.
  void setVaKeyTracking(double amount) =>
      _b.synth_va_set_key_tracking(_handle, amount);

  /// Set the filter-envelope depth in octaves.
  void setVaFilterEnvAmount(double octaves) =>
      _b.synth_va_set_filter_env_amount(_handle, octaves);

  /// Set the filter velocity depth in octaves.
  void setVaFilterVelAmount(double octaves) =>
      _b.synth_va_set_filter_vel_amount(_handle, octaves);

  /// Set the amplitude-envelope attack in seconds.
  void setVaAmpAttack(double seconds) =>
      _b.synth_va_set_amp_attack(_handle, seconds);

  /// Set the amplitude-envelope decay in seconds.
  void setVaAmpDecay(double seconds) =>
      _b.synth_va_set_amp_decay(_handle, seconds);

  /// Set the amplitude-envelope sustain level in `[0, 1]`.
  void setVaAmpSustain(double level) =>
      _b.synth_va_set_amp_sustain(_handle, level);

  /// Set the amplitude-envelope release in seconds.
  void setVaAmpRelease(double seconds) =>
      _b.synth_va_set_amp_release(_handle, seconds);

  /// Set the amplitude velocity-sensitivity amount.
  void setVaAmpVelAmount(double amount) =>
      _b.synth_va_set_amp_vel_amount(_handle, amount);

  /// Set the filter-envelope attack in seconds.
  void setVaFilterAttack(double seconds) =>
      _b.synth_va_set_filter_attack(_handle, seconds);

  /// Set the filter-envelope decay in seconds.
  void setVaFilterDecay(double seconds) =>
      _b.synth_va_set_filter_decay(_handle, seconds);

  /// Set the filter-envelope sustain level in `[0, 1]`.
  void setVaFilterSustain(double level) =>
      _b.synth_va_set_filter_sustain(_handle, level);

  /// Set the filter-envelope release in seconds.
  void setVaFilterRelease(double seconds) =>
      _b.synth_va_set_filter_release(_handle, seconds);

  /// Set the LFO shape.
  void setVaLfoType(LfoType type) =>
      _b.synth_va_set_lfo_type(_handle, type.native);

  /// Set the LFO rate in Hz.
  void setVaLfoRate(double hz) => _b.synth_va_set_lfo_rate(_handle, hz);

  /// Set the LFO-to-pitch depth in semitones.
  void setVaLfoToPitch(double semitones) =>
      _b.synth_va_set_lfo_to_pitch(_handle, semitones);

  /// Set the LFO-to-cutoff depth in octaves.
  void setVaLfoToCutoff(double octaves) =>
      _b.synth_va_set_lfo_to_cutoff(_handle, octaves);

  /// Set the LFO-to-wavetable morph depth.
  void setVaLfoToWavetable(double amount) =>
      _b.synth_va_set_lfo_to_wavetable(_handle, amount);

  /// Set the VA voice's output gain.
  void setVaGain(double gain) => _b.synth_va_set_gain(_handle, gain);

  /// Install a single-cycle waveform into the VA wavetable morph bank at
  /// [slot]. [cycle] holds one period of normalised samples.
  ///
  /// Setup-thread only — this reshapes table storage, so call it before the
  /// synth is played, not while voices render.
  void loadVaWavetable(int slot, List<double> cycle) {
    if (cycle.isEmpty) return;
    using((arena) {
      final buf = arena<Float>(cycle.length);
      for (var i = 0; i < cycle.length; i++) {
        buf[i] = cycle[i];
      }
      _b.synth_va_load_wavetable(_handle, slot, buf, cycle.length);
    });
  }

  // ─── FM patch ─────────────────────────────────────────────────────────────
  // FM edits take effect on the NEXT note-on (the FM core bakes operator state
  // at key-down), so unlike the VA setters these are not glitch-free mid-note.
  // `op` is the operator index 0..5 (OP1..OP6).

  /// Copy patch [index] from a DX7 [bank] into the synth's FM patch — the way
  /// to reach the full 155-parameter DX7 voice. The patch is copied, so [bank]
  /// may be disposed afterwards. Throws [YseException] on failure.
  void setFmPatch(Dx7Bank bank, int index) {
    checkStatus(_b.synth_fm_set_patch(_handle, bank.handle, index), _b);
  }

  /// Set the FM algorithm (`0..31`).
  void setFmAlgorithm(int algorithm) =>
      _b.synth_fm_set_algorithm(_handle, algorithm);

  /// Set the global feedback amount (`0..7`).
  void setFmFeedback(int feedback) =>
      _b.synth_fm_set_feedback(_handle, feedback);

  /// Set the transpose (`0..48`, `24` = none).
  void setFmTranspose(int transpose) =>
      _b.synth_fm_set_transpose(_handle, transpose);

  /// Set the LFO speed (`0..99`).
  void setFmLfoSpeed(int speed) => _b.synth_fm_set_lfo_speed(_handle, speed);

  /// Set the LFO delay (`0..99`).
  void setFmLfoDelay(int delay) => _b.synth_fm_set_lfo_delay(_handle, delay);

  /// Set the LFO waveform (`0..5`).
  void setFmLfoWaveform(int waveform) =>
      _b.synth_fm_set_lfo_waveform(_handle, waveform);

  /// Set the LFO pitch-modulation depth (`0..99`).
  void setFmLfoPitchModDepth(int depth) =>
      _b.synth_fm_set_lfo_pitch_mod_depth(_handle, depth);

  /// Set the LFO amplitude-modulation depth (`0..99`).
  void setFmLfoAmpModDepth(int depth) =>
      _b.synth_fm_set_lfo_amp_mod_depth(_handle, depth);

  /// Set the pitch-modulation sensitivity (`0..7`).
  void setFmPitchModSens(int sensitivity) =>
      _b.synth_fm_set_pitch_mod_sens(_handle, sensitivity);

  /// Set operator [op]'s output level (`0..99`).
  void setFmOpOutputLevel(int op, int level) =>
      _b.synth_fm_set_op_output_level(_handle, op, level);

  /// Set operator [op]'s coarse frequency (`0..31`).
  void setFmOpFreqCoarse(int op, int coarse) =>
      _b.synth_fm_set_op_freq_coarse(_handle, op, coarse);

  /// Set operator [op]'s fine frequency (`0..99`).
  void setFmOpFreqFine(int op, int fine) =>
      _b.synth_fm_set_op_freq_fine(_handle, op, fine);

  /// Set operator [op]'s detune (`0..14`, `7` = centre).
  void setFmOpDetune(int op, int detune) =>
      _b.synth_fm_set_op_detune(_handle, op, detune);

  /// Set operator [op]'s oscillator mode (`0` = ratio, `1` = fixed).
  void setFmOpOscMode(int op, int mode) =>
      _b.synth_fm_set_op_osc_mode(_handle, op, mode);

  /// Enable or disable operator [op].
  void setFmOpEnabled(int op, bool enabled) =>
      _b.synth_fm_set_op_enabled(_handle, op, enabled ? 1 : 0);

  // ─── per-note 3D positioning (the swarm) ──────────────────────────────────

  /// Attach one of the built-in per-note position [handler]s, giving every
  /// voice its own 3D position and movement.
  ///
  /// Must be called *before* the synth is attached/played — like the
  /// `add*Voices` methods, the engine rejects a handler swap once the voice
  /// pool is built (it logs a warning and keeps the existing handler). Throws
  /// [YseException] only for an unknown handler kind.
  void setPositionHandler(PositionHandler handler) {
    using((arena) {
      checkStatus(
        _b.synth_set_position_handler(
          _handle,
          handler._kind,
          handler._toNative(arena),
        ),
        _b,
      );
    });
  }

  /// Move the shared centre `(x, y, z)` that the spread / orbit handlers read.
  ///
  /// A bounded, allocation-free message safe to call every control tick; all
  /// of the synth's live handlers pick up the new centre on the next audio
  /// block.
  void setHandlerCenter(double x, double y, double z) {
    _b.synth_handler_param(
      _handle,
      YseSynthHandlerParam.YSE_HANDLER_PARAM_CENTER_X.value,
      x,
    );
    _b.synth_handler_param(
      _handle,
      YseSynthHandlerParam.YSE_HANDLER_PARAM_CENTER_Y.value,
      y,
    );
    _b.synth_handler_param(
      _handle,
      YseSynthHandlerParam.YSE_HANDLER_PARAM_CENTER_Z.value,
      z,
    );
  }

  /// Imperatively place the voice(s) sounding [noteNumber] on [channel] at
  /// `(x, y, z)` — for app-driven trajectories. Primarily useful when no
  /// position handler is attached (a handler re-steers the voice next block).
  void setNotePosition(
    int noteNumber,
    double x,
    double y,
    double z, {
    int channel = 1,
  }) => _b.synth_note_position(_handle, channel, noteNumber, x, y, z);

  /// Best-effort snapshot of the current position of a voice sounding
  /// [noteNumber] on [channel]. Returns [Pos.zero] if none is sounding. A
  /// single snapshot intended for tests / metering, not a readback stream.
  Pos getVoicePosition(int noteNumber, {int channel = 1}) {
    return using((arena) {
      final x = arena<Float>();
      final y = arena<Float>();
      final z = arena<Float>();
      _b.synth_get_voice_position(_handle, channel, noteNumber, x, y, z);
      return Pos(x.value, y.value, z.value);
    });
  }

  /// Destroy the underlying native synth and detach the finalizer.
  ///
  /// Idempotent. Dispose any [Sound] rendering this synth *before* the synth.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.synth_destroy(_handle);
    _handle = nullptr;
  }
}
