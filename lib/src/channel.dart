import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'dsp_object.dart';
import 'exception.dart';
import 'ffi_helpers.dart';
import 'library.dart';

/// A node in the channel tree — a group of sounds that mix together.
///
/// Channels work like channel groups on a mixing console: every sound is
/// attached to a channel, and channels can themselves be attached to a
/// parent channel, forming a tree rooted at the master channel.
///
/// Use the pre-built channel singletons ([Channel.master], [Channel.fx],
/// etc.) directly, or build subtrees by passing them as the [parent] to
/// [Channel.create].
class Channel {
  final YseBindings _b;
  final Pointer<YseChannel> _handle;
  final bool _owned;

  /// Insert chain heads attached via [dsp], keyed by native channel address.
  ///
  /// The engine holds only a borrowed pointer (see [dsp]). Holding the
  /// wrapper here keeps its finalizer from freeing the effect under a live
  /// channel, and lets [dsp] hand back the same [DspObject] instance rather
  /// than minting a second wrapper over one native handle. Kept per handle,
  /// not per wrapper, because the singleton getters ([master], [fx], …) mint
  /// a fresh wrapper on every access: `Channel.master.dsp = fx` must hold
  /// `fx` after that wrapper is gone (#84). A channel wrapper can also be
  /// dropped without [dispose], leaving the native channel live.
  static final Map<int, DspObject> _inserts = {};

  Channel._(this._b, this._handle, this._owned);

  /// Internal: wrap a borrowed pointer that the caller does not own
  /// (singletons returned by `yse_channel_*` accessors).
  factory Channel._borrowed(Pointer<YseChannel> handle) =>
      Channel._(bindings, handle, false);

  /// Construct a new channel attached to [parent].
  ///
  /// Throws [YseException] when the engine refuses the new channel.
  factory Channel.create(String name, {required Channel parent}) {
    final b = bindings;
    return using((arena) {
      final namePtr = name.toNativeUtf8(allocator: arena);
      final h = b.channel_create(namePtr.cast(), parent._handle);
      if (h.address == 0) {
        final detail = b.last_error().cast<Utf8>().toDartString();
        b.clear_last_error();
        throw YseException('Could not create channel "$name": $detail');
      }
      return Channel._(b, h, true);
    });
  }

  /// Construct a new channel with an explicit number of aux-[send] slots.
  ///
  /// [Channel.create] gives every channel four send slots; use this when a
  /// channel needs to fan out to more return buses than that. The slot count
  /// is fixed at construction — the engine sizes it once, off the audio
  /// thread, and never resizes — so pick a count that covers the channel's
  /// busiest routing.
  ///
  /// Throws [YseException] when the engine refuses the new channel.
  factory Channel.createWithSends(
    String name, {
    required Channel parent,
    required int sendSlots,
  }) {
    final b = bindings;
    return using((arena) {
      final namePtr = name.toNativeUtf8(allocator: arena);
      final h = b.channel_create_with_sends(
        namePtr.cast(),
        parent._handle,
        sendSlots,
      );
      if (h.address == 0) {
        final detail = b.last_error().cast<Utf8>().toDartString();
        b.clear_last_error();
        throw YseException('Could not create channel "$name": $detail');
      }
      return Channel._(b, h, true);
    });
  }

  /// Construct a send/return bus — an aux bus that sits outside the normal
  /// mix tree.
  ///
  /// A return bus is an ordinary channel in every other respect (it keeps
  /// [dsp] inserts, [attachReverb], [volume] and metering), but it is
  /// excluded from the parent/child mix tree: instead, other channels route
  /// scaled copies of their signal into it with [send], and its output folds
  /// into the master mix after the source tree — the classic aux-send
  /// topology.
  ///
  /// A return may itself [send] onward into another return (e.g. a
  /// delay → reverb chain). **The send graph must stay acyclic:** the engine
  /// rejects and logs a wiring that would close a cycle rather than crashing,
  /// but the edge simply will not connect.
  ///
  /// [sendSlots] fixes how many onward sends this return can drive (see
  /// [Channel.createWithSends]). Destroy it with [dispose] like any channel.
  ///
  /// Throws [YseException] when the engine refuses the new bus.
  factory Channel.createReturn(String name, {int sendSlots = 4}) {
    final b = bindings;
    return using((arena) {
      final namePtr = name.toNativeUtf8(allocator: arena);
      final h = b.channel_create_return(namePtr.cast(), sendSlots);
      if (h.address == 0) {
        final detail = b.last_error().cast<Utf8>().toDartString();
        b.clear_last_error();
        throw YseException('Could not create return bus "$name": $detail');
      }
      return Channel._(b, h, true);
    });
  }

  /// The root of the channel tree. Every channel ultimately routes here.
  static Channel get master => Channel._borrowed(bindings.channel_master());

  /// Pre-built channel for short sound effects.
  static Channel get fx => Channel._borrowed(bindings.channel_fx());

  /// Pre-built channel for playlists and music tracks.
  static Channel get music => Channel._borrowed(bindings.channel_music());

  /// Pre-built channel for environmental and ambient sounds.
  static Channel get ambient => Channel._borrowed(bindings.channel_ambient());

  /// Pre-built channel for dialogue and voice-over.
  static Channel get voice => Channel._borrowed(bindings.channel_voice());

  /// Pre-built channel for user-interface sounds.
  static Channel get gui => Channel._borrowed(bindings.channel_gui());

  /// Volume in the range [0.0, 1.0].
  double get volume => _b.channel_get_volume(_handle);
  set volume(double value) => _b.channel_set_volume(_handle, value);

  /// Re-parent this channel. All attached sounds and subchannels follow.
  void moveTo(Channel parent) => _b.channel_move_to(_handle, parent._handle);

  /// Move the global reverb effect onto this channel.
  ///
  /// libYSE runs a single reverb instance for performance reasons. By
  /// default it sits on the master channel; call this to restrict reverb
  /// to a subtree.
  void attachReverb() => _b.channel_attach_reverb(_handle);

  /// Whether sounds on this channel may be virtualised when the engine
  /// runs out of voices.
  bool get virtual => _b.channel_get_virtual(_handle) != 0;
  set virtual(bool value) => _b.channel_set_virtual(_handle, value ? 1 : 0);

  /// Whether this channel has a live implementation.
  bool get isValid => _b.channel_is_valid(_handle) != 0;

  /// The channel's *log* name: the value passed to [Channel.create] (or
  /// [Channel.createWithSends] / [Channel.createReturn]), or the engine's
  /// own name for a pre-built singleton. It labels the channel in engine log
  /// output and is fixed for the channel's lifetime.
  ///
  /// This is **not** the bus address — see [busName]. The engine keeps the
  /// two independent on purpose: creating a channel named `"drums"` does not
  /// put it on the bus, and naming it `drums` on the bus does not change this
  /// value.
  String get name =>
      fetchString((buf, cap) => _b.channel_get_name(_handle, buf, cap));

  /// Bus names set through any [Channel] wrapper, keyed by native handle
  /// address. Kept per handle rather than per wrapper because the pre-built
  /// singleton getters ([master], [fx], …) mint a fresh wrapper on every
  /// access, and `Channel.master.busName` must read back what
  /// `Channel.master.busName = …` set.
  static final Map<int, String> _busNames = {};

  /// The name this channel answers to on the global bus, or `null` when it is
  /// anonymous (the default).
  ///
  /// Once named `foo`, the engine subscribes the channel to
  /// `channel.foo.volume` (a `BusFloat`, or a `BusInt`), so a `Bus.publish`
  /// (or a script's `yse.send`, or a patcher `.s`) sets its [volume] with no
  /// host round-trip. The value applies when the engine drains its bus queue
  /// — on the control thread, so it is visible after the publish (or the next
  /// `System.update()` for a publish from another thread).
  ///
  /// Independent of [name], the log name given at create: setting one never
  /// touches the other.
  ///
  /// Setting `null` or `''` clears the name and its subscription; renaming
  /// re-subscribes. Names are unique per channel — a duplicate is rejected
  /// and logged by the engine, with no error here (this getter still reports
  /// the requested name). Only effective while the engine is between init and
  /// close; `System.close()` forgets every channel bus name. There is no
  /// native getter: this returns the last value set through the wrapper API
  /// for this native channel.
  String? get busName => _busNames[_handle.address];
  set busName(String? name) {
    using((arena) {
      _b.channel_set_name(
        _handle,
        name == null || name.isEmpty
            ? nullptr
            : name.toNativeUtf8(allocator: arena).cast(),
      );
    });
    if (name == null || name.isEmpty) {
      _busNames.remove(_handle.address);
    } else {
      _busNames[_handle.address] = name;
    }
  }

  /// Number of output speakers this channel feeds. Index into [peakLinear]
  /// and [peakDb] with values in `[0, numOutputs)`.
  int get numOutputs => _b.channel_get_num_outputs(_handle);

  /// Peak amplitude (linear `[0.0, 1.0+]`) measured at the end of dsp(),
  /// before the channel volume is applied. Useful for input-level meters.
  ///
  /// Pass an [output] index in `[0, numOutputs)` for a per-speaker reading;
  /// out-of-range indices return 0.
  double peakLinearPre({int? output}) => output == null
      ? _b.channel_get_peak_linear_pre(_handle)
      : _b.channel_get_peak_linear_pre_output(_handle, output);

  /// Peak amplitude (linear `[0.0, 1.0+]`) measured immediately after
  /// the channel volume is applied — what listeners hear.
  double peakLinearPost({int? output}) => output == null
      ? _b.channel_get_peak_linear_post(_handle)
      : _b.channel_get_peak_linear_post_output(_handle, output);

  /// [peakLinearPre] expressed in decibels. Silence reports −120 dB.
  double peakDbPre({int? output}) => output == null
      ? _b.channel_get_peak_db_pre(_handle)
      : _b.channel_get_peak_db_pre_output(_handle, output);

  /// [peakLinearPost] expressed in decibels. Silence reports −120 dB.
  double peakDbPost({int? output}) => output == null
      ? _b.channel_get_peak_db_post(_handle)
      : _b.channel_get_peak_db_post_output(_handle, output);

  /// Whether this channel is a send/return bus (created via
  /// [Channel.createReturn]) rather than an ordinary mix-tree channel.
  bool get isReturn => _b.channel_is_return(_handle) != 0;

  // ─── aux sends ──────────────────────────────────────────────────────────

  /// Wire send [slot] of this channel to [returnBus] at [level].
  ///
  /// [slot] indexes this channel's send slots, `[0, sendSlots)` — four by
  /// default, or the count fixed by [Channel.createWithSends] /
  /// [Channel.createReturn]. [returnBus] must be a return bus (see
  /// [isReturn]).
  ///
  /// Sends are post-fader by default — they follow this channel's [volume].
  /// Pass `preFader: true` for a cue-style send that is independent of the
  /// fader.
  ///
  /// The engine rejects and logs an illegal wiring (a target that is not a
  /// return, a self-send, a return → return edge that would close a cycle,
  /// or an out-of-range slot) on the calling thread; it never reaches the
  /// audio thread. This call is a no-op on such a wiring rather than an
  /// error.
  void send(
    int slot,
    Channel returnBus, {
    double level = 1.0,
    bool preFader = false,
  }) => _b.channel_send(
    _handle,
    slot,
    returnBus._handle,
    level,
    preFader ? 1 : 0,
  );

  /// Set the level of send [slot], ramped and click-free.
  ///
  /// Safe to call every control tick — the engine designs send levels as
  /// modulation targets, so continuous writes fuse into the per-block ramp
  /// without zippering (hence no fade argument).
  void setSendLevel(int slot, double level) =>
      _b.channel_set_send_level(_handle, slot, level);

  /// Current target level of send [slot], or `0.0` if the slot is unset or
  /// out of range.
  double getSendLevel(int slot) => _b.channel_get_send_level(_handle, slot);

  /// Detach send [slot], fully disconnecting it from its return bus.
  void clearSend(int slot) => _b.channel_clear_send(_handle, slot);

  // ─── insert DSP ─────────────────────────────────────────────────────────

  /// The pre-fader insert effect chain attached to this channel, or `null`
  /// when none is attached.
  ///
  /// Assign a [DspObject] chain head to place it in this channel's insert
  /// slot; the effect processes the channel's summed output in place, before
  /// reverb and the channel [volume]. Chain multiple effects with
  /// [DspObject.link] and assign the head. Assign `null` to detach.
  ///
  /// The engine holds only a borrowed reference: the assigned [DspObject]
  /// (and every object linked after it) must outlive the channel, or be
  /// detached first. The wrapper holds a Dart reference to the assigned head
  /// for this native channel — through any wrapper, including the fresh one
  /// each singleton getter returns — and each effect holds its linked
  /// successor, so garbage collection never frees the chain while it is
  /// attached. The reference is dropped when the head is replaced, the
  /// channel is [dispose]d, or `System.close()` ends the session. This
  /// mirrors `Sound.dsp` at the channel level.
  DspObject? get dsp {
    // Consult the engine so the getter reflects the live insert slot, then
    // hand back the wrapper we already hold for that handle.
    return _b.channel_get_dsp(_handle).address == 0
        ? null
        : _inserts[_handle.address];
  }

  set dsp(DspObject? head) {
    _b.channel_set_dsp(_handle, head?.handle ?? nullptr);
    if (head == null) {
      _inserts.remove(_handle.address);
    } else {
      _inserts[_handle.address] = head;
    }
  }

  /// Internal: native handle for cross-wrapper plumbing (sound → channel).
  Pointer<YseChannel> get handle => _handle;

  /// Destroy the underlying native channel.
  ///
  /// No-op for the pre-built singletons (those are owned by the engine).
  void dispose() {
    if (!_owned) return;
    Channel._busNames.remove(_handle.address);
    _b.channel_destroy(_handle);
    // The engine clears the insert's back-reference when it frees the
    // channel, so the effect may be collected from here on.
    Channel._inserts.remove(_handle.address);
  }
}

/// Forgets every remembered [Channel.busName]. Called by `System.close()`:
/// the engine drops bus subscriptions with the session. Internal to
/// `lib/src/`.
void clearChannelBusNames() => Channel._busNames.clear();

/// Drops every held [Channel.dsp] insert. Called by `System.close()` *after*
/// the engine has shut down (so no audio callback can still be running an
/// insert the collector might then free). Internal to `lib/src/`.
void releaseChannelInserts() => Channel._inserts.clear();
