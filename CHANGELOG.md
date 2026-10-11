# Changelog

## 0.2.0 — libYSE 3.1.0

**Engine bumped to libYSE v3.1.0** (from v2.4.0-3); bindings regenerated
(#55). v3.1.0 is v3.0.1 plus upstream #1022 (`bandPass` unity gain),
#1026 (device enumeration without a stream), #1027 (auto-reconnect to the
opened device, with an outcome API) and #1028 / #1029 (device callback
fixes). The 3.0 C ABI is not compatible with 2.4, and the engine changed
several behaviours without changing a signature, so this is a **breaking
release**. The new docs page *Upgrading to package:yse 0.2.0*
(`docs/source/intro/upgrading.rst`, published at
https://yvanvds.github.io/dart-yse/intro/upgrading.html) gives the old and
new Dart code for every change below (#70).

### The engine comes with the package

- **Native-assets build hook** (#95). `hook/build.dart` downloads the
  prebuilt libYSE v3.1.0 release for Windows x64 and Linux x64, checks it
  against the sha256 digest embedded in the package
  (`lib/src/engine_release.dart`, tested against the submodule pin and the
  release), and bundles it as a code asset, so `dart pub add yse` followed
  by `dart run`, `dart test`, `dart build cli` or `flutter run` needs no
  manual engine setup. On Windows the engine's runtime DLLs are bundled
  next to `libyse.dll`. The download is cached under `.dart_tool/`; later
  builds work offline. Linux needs the PortAudio, libsndfile and RtMidi
  runtime packages; Android still gets the engine from `yse_flutter_libs`.
- **Requires Dart 3.10** (Flutter 3.38), where build hooks are stable; the
  SDK constraint moved from `^3.8.0` to `^3.10.0`. New dependencies:
  `hooks`, `code_assets` and `crypto`.
- **Loader order** is now `YSE_DLL_PATH`, then the bundled release, then
  the submodule's source build (`third_party/yse-soundengine/build/bin`).
  In a dart-yse checkout a source build is therefore only used when
  `YSE_DLL_PATH` names it. The unreleased-engine banner (#89) treats the
  bundled release as pinned.

### Breaking changes

- **`System.init()` throws when no device opens** (#56). It throws
  `YseException` (`YSE_ERR_AUDIO_DEVICE`) and leaves the engine closed
  when there is no default output device or it refuses to open or start;
  up to libYSE 2.4 it returned normally with nothing open. Fall back to
  `initOffline()`.
- **`System.openDevice()` throws when the engine opened nothing** (#56,
  closes #52): no output device set, a stale device (`Device.id` -1 or no
  longer resolving), a stream error (including a device that refuses the
  session rate), or an offline session without a backend. The running
  stream and speaker layout are left untouched. It used to return
  normally.
- **48 kHz default session rate** (#56, closes #53). The default is now
  48 kHz (was 44.1 kHz), so offline renders that assumed 44.1 kHz change
  length; choose the rate with the new `System.requestedSampleRate`.
  `DeviceSetup.sampleRate` cannot change a running session's rate.
  `DspObject.granulator`'s default `poolSize` is 5 s at 48 kHz
  (`48000 * 5`, was `44100 * 5`).
- **`System.setAutoReconnect`** (#54, #56): `delayMs` is wall-clock
  milliseconds (libYSE 2.4 compared it against a count of `update()`
  ticks), with a 500 ms start-up grace. The watchdog now reopens the
  device of the last successful `openDevice()` (found again by name and
  host, with its channel count and buffer size) instead of the default
  output device; a session that never called `openDevice()` still reopens
  the current default. `System.resume()` reopens the same device and never
  falls back to another one, and is a no-op on an offline session.
- **`DspBuffer` subclasses are real Dart subclasses** (#55).
  `DspBuffer.plain` stays; `DspBuffer.drawable` / `.file` / `.wavetable`
  are replaced by `DrawableBuffer(...)`, `FileBuffer(...)` and
  `Wavetable(...)`. The 3.0 C API no longer checks the subclass (it
  `static_cast`s), so calling e.g. `drawLine` on a plain buffer was
  undefined behaviour; the type system now rules it out.
- **Patcher IDs** (#55): `PHandle.id`, `PHandle.connectionTargetId` and
  `PHandle.connectionTargetInlet` return `int?`, with `null` for the
  engine's `YSE_PATCHER_ID_NONE` / `YSE_PATCHER_INLET_NONE` sentinels.
  Patcher IDs now start at 0 and are reused after a delete. Patch-file IDs
  are per patcher from 0, and the patcher name is saved in the JSON (#64).
- **`Patcher()` and `Patcher.parseJson` throw `YseException` on failure**
  (#55). `parseJson` adds to the existing patch (call `clear()` first to
  replace it) and rolls back a failed load.
- **Patcher bus slots carry the `patcher.` prefix** (#50, #55): a patcher
  named `foo` publishes its `.s` slots to `patcher.foo.<slot>` and its `.r`
  slots hear `patcher.foo.<slot>` (libYSE 2.4: `foo.<slot>`).
- **`Obj.dOut` (`~out`) is removed** (#55); no engine object ever
  implemented it. Every other existing `Obj` name is kept.
- **`PCategory` gains the 11 new 3.0 registry categories** (#55), so an
  exhaustive `switch` over it needs the new cases.
  `PatcherObjectType.description` is now a tooltip-length summary (#64).
- **`Player(Synth synth)`** (#85). Since engine v2.3.0
  `yse_player_create` takes the synth the player plays its notes on and
  returns NULL without one; the wrapper passed `nullptr` (since #22), so
  `Player()` always threw `YseException` and the class was unusable.
- **Late voice groups throw** (#81, upstream yse-soundengine#1177).
  `Synth.addSineVoices` / `addVaVoices` / `addFmVoices` /
  `addSamplerVoices` and `Synth.setPositionHandler` throw `StateError` once
  `voiceCount` is non-zero; the engine drops these calls after the voice
  pool is built and only logs a warning.
- **`DspObject` kind-specific accessors check the kind** (#72). `q`, the
  `sweep*` accessors, `setDelayTap` / `delayTime` / `delayGain`,
  `phaserRange`, `differenceAmplitude` and every granulator accessor throw
  `YseException` on the wrong kind before calling native code, where they
  used to write through a mistyped pointer.
- **`System.close()` closes bus streams** (#59): it releases every `Bus`
  subscription and tap and closes their streams. Before, a tap stream went
  silent but stayed cached, so re-tapping the same prefix after a re-init
  never fired. Subscribe again after the next init.
- **`pass*` with a `Patcher.messages` listener** (#62): while `messages`
  has a listener, `passBang` / `passInt` / `passFloat` / `passString`
  return `true` for a name nothing receives.
- **Deprecated:** `LiveCoding.bus` forwards to the new `Bus.tap` (#59).
  `BusValue` / `BusFrame` moved to `bus.dart`; `package:yse/yse.dart`
  still exports them.
- **Patcher behaviour changes that alter existing patches** (no wrapper
  change; #64): `.route` strips the selector and matches floats
  (`.routepass` is the old behaviour); `.metro` period changes apply while
  running and its left inlet takes bang / stop / float; `.counter` honours
  its start value and step inlet; `~saw` is bipolar; multiple `~dac`s sum;
  `.m` sends the typed message it spells; `.midiout` takes byte lists;
  `~+` / `~-` default their right operand to 0 and `~bp` defaults to Q 1;
  `.programchange` / `.channelpressure` no longer send an extra byte;
  `~line stop` holds.
- **Engine behaviour changes picked up:** `bandPass` (and `~bp`) has
  unity gain at its centre frequency (upstream #1022); the random
  generator is thread-safe, reproducible by default and draws floats in
  `[0, 1)`; `Channel.virtual = false` turns virtualisation off (upstream
  #864); doppler uses a wall clock (upstream #667); an out-of-range
  `MidiOut` channel is clamped to `0..15` (upstream #1014); domain clocks
  and clips advance per rendered block, may be disposed in any order, and
  a clip survives `System.close()`.

### Sessions and devices

- **libYSE 3 session and device semantics** (#56):
  - New `System.requestedSampleRate` (get/set before `init` /
    `initOffline`; survives `close`, 0 clears it). An offline session runs
    exactly at the requested rate.
  - New `System.setChannelConfiguration(layout, outputs)` sets the speaker
    layout of a session with no device (offline, headless CI).
  - New `DeviceSetup.outputChannels`.
  - Dartdoc corrected for `setAutoReconnect` (`delayMs` is wall-clock
    milliseconds), `resume` (no-op on an offline session),
    `missedCallbacks`, `devices`, `Device.defaultBufferSize`, the MIDI
    device-name getters and `underwaterDepth` (world units below the
    surface, not 0..1).
- **Render threads, block size and RNG seeding** (#57):
  - New `System.renderThreads` (get/set; `-1` auto, `0` audio thread only,
    `n` workers; set before init, survives `close`) and
    `System.activeRenderThreads`.
  - New static `System.blockSize` (128): `renderOffline(blocks)` renders
    `blocks * blockSize` frames.
  - New static `System.randomSeed(seed)` / `System.randomize()` seed the
    engine's generator (`.random`, granulator jitter, LFO random shapes).
    The engine is reproducible by default.
- **Sound occlusion callback** (#58): new `System.occlusion`, an
  `OcclusionFn` (`double Function(Pos source, Pos listener)`) the engine
  calls synchronously during `update()` once per sound with
  `Sound.occlusion` enabled; the result (0..1) ducks the sound. One
  callback per process; `null` removes it and `System.close()` clears it.
  An exception thrown by the callback counts as unoccluded for that update
  and is reported to the zone that installed it.
- **List audio devices without opening one** (#51, upstream
  yse-soundengine#1026):
  - New `System.refreshDevices()` fills `System.devices` (and
    `defaultDevice` / `defaultHost`) without opening a stream. It works
    before `init`, on an `initOffline()` session and on a running device
    session, and returns `false` with an empty list when the audio
    backend cannot start.
  - It also starts the backend, so `openDevice()` now works on an
    `initOffline()` session in a process that never called `init()`.
  - Hot-plug: with no stream open the backend restarts and picks up
    devices plugged in or removed since. With a stream open the list is
    re-read from the existing enumeration, so a new device appears only
    after the device is closed and the list is refreshed again.
  - The refresh replaces the list; match devices by name and host, not
    by index.
- **Auto-reconnect reports the outcome** (#54, upstream
  yse-soundengine#1027):
  - New optional `setAutoReconnect` parameters `fallbackToDefault` (open
    the default device when the session's own cannot be reopened; off by
    default) and `maxAttempts` (stop after that many consecutive failed
    attempts; 0 = no limit).
  - New `System.reconnectState` (`ReconnectState`: `none`,
    `reconnecting`, `restored`, `fellBackToDefault`, `failed`),
    `System.reconnectCount`, and `System.activeDevice` /
    `System.activeHost` for the device actually playing.

### Bus

- **`Bus`: host publish and exact-address subscribe** (#59):
  - New `Bus` class: `Bus.publish(address, value)`, `Bus.subscribe(address)`
    (exact match) and `Bus.tap(prefix)`. `BusValue` / `BusFrame` move to it.
  - New `Synth.busName`, so a synth answers on `synth.<name>.*`.
- **Named sounds and channels on the bus** (#60):
  - New `Sound.busName`: a named sound answers on `sound.<name>.volume`,
    `.speed` and `.position`.
  - New `Channel.busName`: a named channel answers on
    `channel.<name>.volume`. It is separate from `Channel.name`, the log
    name given to `Channel.create`. `busName` is the name used for bus
    addressing on all three kinds. The value is remembered per native
    channel, so `Channel.master.busName` reads back across wrappers.
    `System.close()` forgets it.

### Patcher

- **Named patchers** (#50, upstream yse-soundengine#896):
  - New `Patcher.name` (get/set) and a `name:` parameter on `Patcher(...)`.
    Every patcher has a name: `null` / `''` restores the auto-generated
    `patcher_<N>`. Names are not unique; two patchers with the same name
    share their slots.
  - A name longer than `Patcher.maxNameLength` (55) throws `YseException`
    and keeps the current name. The name is saved by `dumpJson` and
    applied by `parseJson` unless one was already set.
  - It is named `name`, not `busName` like `Synth` / `Sound` / `Channel`,
    because it is the patcher's own engine-side name (read back from the
    engine, saved with the patch), not only a bus address.
- **Subpatchers** (#61, upstream yse-soundengine#545 / #764):
  - New `Patcher.setContainer(obj, container)` puts an object inside an
    `Obj.patcher` object (or back at the top level with `null`); read it
    back with `PHandle.container`. The engine refuses an illegal move (not
    a `patcher` container, or a cycle) without a status, so the wrapper
    reads the containment back and throws `YseException`; a handle from
    another `Patcher` throws `ArgumentError`.
  - New `PHandle.subpatcherInlets` / `subpatcherOutlets`: the pin range a
    subpatcher presents (`.inlet` / `~inlet` share one index space).
    `PHandle.inputs` / `outputs` answer 0 for a subpatcher.
  - `connect` / `disconnect` to a subpatcher resolve to its boundary
    object; deleting a subpatcher deletes its contents transitively.
  - `PHandle` now has value equality: two handles to the same engine
    object compare equal.
- **Patcher send callback** (#62, upstream yse-soundengine#907):
  - New `Patcher.messages`: a broadcast stream of `PatcherMessage`
    (`address`, `BusValue`) for every message sent to a name no `.r` in
    the patcher receives — a `.s` in the patch, or an unreceived `pass*`.
    Lists arrive as `BusString`. The native callback is installed on the
    first listen and cleared on the last cancel, by `Patcher.dispose()`
    and by `System.close()`.
  - The engine calls it on the emitting thread, which is an engine worker
    for timer-driven messages, so the bridge is a
    `NativeCallable.listener` and delivery is asynchronous. Every native
    message block is freed exactly once, including messages still queued
    at teardown.
- **GUI value protocol** (#63, upstream yse-soundengine#551 / #846):
  - New `PHandle.guiValueCount`, `PHandle.guiValueAt(index)` (`''` past
    the count) and `PHandle.guiValueIsSettable`.
  - New `PHandle.restoreGuiValue(state)` and
    `PHandle.setGuiValueAt(index, value)`: thin wrappers that send the
    state back on inlet 0 (`state`, or `set <index> <value>`; `.textedit`
    takes the value as its whole state). They throw `StateError` on a
    non-settable object such as `.b`. There is no engine setter by design.
  - Dartdoc on `guiValue` / `getGuiProperty` / `setGuiProperty` now spells
    out the contract: polls may be destructive, per-cell reads are not
    atomic, and GUI properties are persisted decoration, not live state.
    New "GUI controls" section in the patcher API docs.
- **`Obj` covers the whole registry** (#64): a constant for every one of
  the 305 registry objects (was 42), generated by
  `tool/gen_obj_constants.dart` from the bound registry and upstream
  `pObjectList.hpp`, with the object's summary as dartdoc. Names mirror
  `YSE::OBJ` (`G_ARRAY_INDEXOF` → `gArrayIndexof`). New `Obj.all` lists
  them all. Subpatcher boundaries: `Obj.gInlet`, `gOutlet`, `dInlet`,
  `dOutlet`.
- New `PatcherObjectType.requiresMidiDevice` (#64): true for objects that
  hold a MIDI port, which exist only in builds with MIDI device support
  (not macOS / Android).

### Buffers, DSP and reverb

- **Buffer math, copy / swap, file rate and multichannel buffers** (#65,
  upstream yse-soundengine#909):
  - New `DspBuffer.addBuffer` / `subBuffer` / `mulBuffer` / `divBuffer`:
    sample-wise math against another buffer over the shorter length;
    dividing by a zero sample gives 0.
  - New `DspBuffer.copyFrom(src, srcPos:, dstPos:, count:)`. An
    out-of-range span throws `YseException` (the engine would skip it
    silently); a negative argument throws `RangeError`; overlapping ranges
    within one buffer throw `ArgumentError`.
  - New `DspBuffer.swap(other)` exchanges samples between buffers of equal
    length (`YseException` otherwise); each keeps its class and rate.
  - New `FileBuffer.fileSampleRate`: the native rate of the last loaded
    file, 0 before a load, unchanged by a re-init at another rate. It is
    `FileBuffer`-only, since the C entry point trusts the subclass.
  - New `DspMultiBuffer(List<DspBuffer>)` (copies its channels; finalized
    natively) with `channelCount`, and `Sound.fromMultiBuffer` to play it
    as a stereo / surround source.
  - `FileBuffer.saveFile` dartdoc states the format (mono 32-bit float WAV
    at the file's rate) and that it fails while a custom `BufferIO` is
    active.
- **Underwater insert, chain walking, reverb preset values + morph** (#66,
  upstream yse-soundengine#909):
  - New `Underwater` `DspObject` subclass with a `depth` get/set (world
    units below the surface: `<= 1` transparent, `1..5` crossfades, `>= 5`
    fully neutral, negative clamps to 0). The inherited `impact` is not
    applied. Independent of `System.underwaterFx` / `underwaterDepth`.
  - New `DspObject.next`: the object linked after this one, or `null`. It
    returns the *existing* Dart wrapper (via a weak native-address
    registry), so `identical(a.next, b)` after `a.link(b)` and no second
    owning wrapper is ever created. It reads the engine, so it follows
    `link`'s insert-between semantics and a disposed object being spliced
    out.
  - New `ReverbPresetValues.fromPreset(preset)` (the exact values
    `Reverb.preset` applies) and `ReverbPresetValues.lerp(a, b, t)` (the
    engine's morph core, `t` clamped to `[0, 1]`, exact at both ends).
    Neither needs an engine session.
  - New `Reverb.applyValues(values)` applies a full parameter set to a
    zone, exactly as `Reverb.preset` does for a named one.

### Synth, music and MIDI

- **`Player` works: it plays on a `Synth`** (#85). Attach the synth to a
  playing `Sound.fromSynth` to hear the player; the new `Player.synth`
  returns it. The player holds what the engine borrows: its synth, every
  scale the scale cross-fade may still read (the last one set without a
  fade and each fade target since) and its motif pool (`addMotif` holds,
  `removeMotif` releases). All are released only after the player's
  native destroy; `dispose()` releases the scales and motifs at once and
  keeps the synth until the wrapper is collected, because the engine still
  sends note-offs to it when it retires the player on its next audio block
  (upstream yse-soundengine#1181). If you dispose the synth yourself, let
  one block run after `player.dispose()` first. `Player.setScale` /
  `addMotif` docs no longer claim the player copies its scale: the engine
  borrows both (#84). `example/demo17_music.dart` now plays a player;
  README and docs no longer call `Player` a placeholder.
- **DX7 banks from memory, patch lookup, Note-driven synth calls,
  `PNote.channel`** (#67, upstream yse-soundengine#909):
  - New `Dx7Bank.fromBytes(Uint8List)` parses a bank already in memory
    (Flutter assets, Android APKs). The bytes are copied for the call only.
  - New `Dx7Bank.indexOf(name)`: the index of the first patch whose
    space-trimmed name matches exactly (case-sensitive), or `null`. Pairs
    with `Synth.setFmPatch`.
  - New `Synth.playNote(Note)` / `Synth.releaseNote(Note)`: the note's
    channel is the channel, its pitch rounded to the nearest integer is the
    note number, and its volume is the velocity.
  - New `PNote.channel` get/set.
  - Docs: MIDI channel numbering has two bases. `MidiOut` and parsed
    `MidiIn` messages use wire-level `0..15`; `Synth`, `ClipEvent`,
    `Note` / `PNote` and the `MidiIn.connectSynth` filter use `1..16`, with
    `0` meaning omni on a synth call. Stated on each class and in a table
    on the MIDI docs page. The wrapper's defaults already match.
  - Docs: a `DomainClock` and its `ClipTransport`s may now be disposed in
    any order (a clip on a destroyed clock stops firing), disposing a clip
    releases its sounding notes, a clip survives `System.close()`, and
    clocks advance per rendered block. `ClipTransport.stop()` was already a
    plain pass-through to the engine's own note-off flush, so nothing in
    the wrapper became redundant.
- **`MidiOut.raw` for two-byte messages and SysEx** (#68, upstream
  yse-soundengine#748 / #903):
  - New `MidiOut.raw(List<int> bytes)` sends one complete message exactly
    as given — no padding, no truncation — so program change, channel
    pressure, single-byte realtime messages and SysEx of any length can be
    sent. The bytes are copied for the call; an empty list is a no-op. The
    message is checked in Dart first and an `ArgumentError` names the
    problem: a value outside `0..255`, a missing status byte (no running
    status), a data byte with the high bit set, a length that doesn't match
    the status, a SysEx without its closing `0xF7`, or an undefined status.
  - `raw3` is unchanged; its docs now point at `raw` for anything that isn't
    a three-byte message.
  - Docs: an out-of-range `MidiOut` channel is clamped to `0..15` by the
    engine (libYSE 3.0.1, upstream #1014) instead of corrupting the status
    byte, and `MidiOut.open` on a port that doesn't exist leaves the port
    unopened, so every send is a silent no-op.
  - `BufferIO` deliberately does not wrap `yse_buffer_io_exists` /
    `yse_buffer_io_remove` (upstream #909). They look a buffer up by the
    native address passed at registration, which a Dart caller never holds:
    `addAsset` registers a copy the wrapper allocates itself, and with
    `storeCopy = true` the engine registers its own copy, so the address
    never matches anyway. `exists` / `removeAsset` cover the same need by
    ID.
- `DomainClock` / `ClipTransport.bind` report failures through
  `YseException` with the engine's error detail (#55).
- `Channel.name` reads through the 3.0 caller-buffer getter (#55).

### Lifetime and safety fixes

- **Sounds and patcher inserts keep their borrowed sources alive** (#65,
  #80). `Sound.fromBuffer`, `Sound.fromMultiBuffer`, `Sound.fromPatcher`
  and `Sound.fromSynth` hold a Dart reference to their source, and
  `Sound.dsp` holds the assigned chain head, as `Channel.dsp` already did.
  `DspObject.patcherInsert` holds its `Patcher`. Before, dropping the
  caller's only reference let garbage collection run the source's native
  finalizer while the engine still used it: a dropped buffer or `Synth`
  was freed under its playing sound, and a dropped `Patcher` lost its
  control surface (the engine keeps rendering a graph it has taken over).
  Explicitly disposing a source before its sound is still unsupported; the
  docs now say so for every loader.
- **Every borrowed object stays alive under its consumer** (#84):
  - `DspObject.link` chains: each effect holds the one linked after it,
    following the engine's own rewiring (`link` inserts between, `unlink`
    detaches, `dispose` splices the successor onto the predecessor). A
    chain whose head is held — by a `Sound`, a `Channel` or your own
    variable — keeps every link alive.
  - `Channel.dsp` holds its insert per native channel, so
    `Channel.master.dsp = fx` (and the other singleton getters, which
    return a fresh wrapper each time) keeps `fx` alive, and
    `Channel.master.dsp` reads it back. Released on reassignment,
    `Channel.dispose` and `System.close`.
  - `ClipTransport.connectSynth` / `connectMidiOut`, `MidiFile.connectSynth`
    and `MidiIn.connectSynth` hold each sink until it is disconnected or the
    owner is disposed. `Motif.setFirstPitch` holds its `Scale`.
  - Finalizer order: when an owner and what it borrows become unreachable
    in the same collection, their native finalizers used to run in
    unspecified order, so a sound's buffer or synth could be freed before
    the sound. Borrowed objects are now released only after the owner's
    native destroy has run (they are the token of a Dart `Finalizer` on the
    owner, released when its callback is delivered).
- **`Log.messages` and `MidiIn.rawMessages` no longer leak queued
  messages at teardown** (#76). Both used to close their
  `NativeCallable.listener` straight after clearing the native callback.
  That dropped the calls still queued on its port, so the engine-malloc'd
  string or byte buffer of every message emitted just before the last
  cancel (or `MidiIn.dispose`) was never freed. They now use the
  drain-marker teardown from `Patcher.messages` (#62): clear the callback,
  post a NULL marker through the same port, and close the callable only
  when the marker arrives. Every buffer is freed exactly once, and
  messages still queued are dropped rather than delivered.
  `MidiIn.dispose` now destroys the port before it retires the callbacks.
  The parsed MIDI stream carries no native buffers and is unchanged.
- `DspObject` kind checks (#72) and late-voice-group checks (#81): see
  *Breaking changes*. The mix-grade modules (`Compressor`,
  `ParametricEq`, ...) were already safe because they are typed
  subclasses.
- `System.devices` guards a NULL device pointer, and `Device.id` documents
  -1 (#55).

### Docs, examples and tooling

- **Upgrade guide and new pages** (#70): `intro/upgrading` (0.1.0 →
  0.2.0, old and new code per change), `intro/sessions_and_devices`
  (sessions, sample rates, offline rendering, device selection,
  `refreshDevices`, auto-reconnect), a clocks-and-clips tutorial
  (`tutorials/06_clocks_and_clips`), a per-callback threading table in
  `intro/mental_model`, and refreshed devices / patcher / synth / install
  pages. The `:yse-cpp:` links on the API pages had title and target
  swapped (so they pointed at `.../YSE::device` and the like); they now
  point at the upstream libYSE pages.
- **Examples** (#70): new `example/demo19_bus.dart` (publish / subscribe
  / tap, named synth, sound, channel and patcher) and
  `example/demo20_clocks_clips.dart` (`DomainClock` + `ClipTransport` +
  `Synth`). `demo06_devices.dart` lists devices with `refreshDevices()` on
  an offline session instead of opening the default device;
  `hello_sound.dart` reports a failed `init()`; `demo07_dsp_buffer.dart`
  uses `DrawableBuffer` / `FileBuffer` (#55); `demo08_dsp_modules.dart`
  sizes the granulator pool for 48 kHz; `demo17_music.dart` plays a
  `Player` (#85). The Android sample sets `renderThreads = 0`.
- **Patcher object reference covers all 305 objects** (#69). The docs
  site's object reference listed the 42 objects of a stale upstream 2.x
  snapshot. It is now an index plus one page per category (templates
  ported from upstream libYSE), with each object's 3.x summary, its `Obj`
  constant, and a *MIDI device only* flag for the objects that are not
  available on macOS / Android. The snapshot
  (`docs/source/_data/patcher_objects.json`) is now generated from the
  bound registry by `tool/gen_patcher_snapshot.dart`, and
  `test/gen_patcher_snapshot_test.dart` fails when it drifts. The page
  moved from `api/patcher_objects.html` to `api/patcher_objects/`.
- **Patcher object reference shows the long-form notes** (#78). Under
  each object's summary the reference now renders libYSE's longer notes
  (message formats, edge cases, examples) for the 251 objects that have
  them. `tool/port_patcher_notes.dart` copies them from the engine
  submodule into `docs/source/_data/patcher_notes/`, turning links into
  the upstream patcher guide into links to the libYSE site and C++ API
  names (`YSE::Randomize()`, `CreateObject`, ...) into their Dart
  equivalents; `test/port_patcher_notes_test.dart` fails when the copy
  drifts.
- **API generator** (#75, and the #56–#59 docs fix): `tool/emit_api_rst.dart`
  emits pages for typedefs (`BusFrame`, `OcclusionFn`), exits 1 when a
  re-exported name has no page, and translates dartdoc's fenced code
  blocks and pipe tables into RST so the Sphinx build stays warning-free.
- **Prebuilt engine for the pinned tag** (#88): new
  `tool/fetch_engine.dart` reads the release tag the engine submodule
  pins, downloads that tag's Windows x64 or Linux x64 release asset from
  the public yse-soundengine release URL (no `gh` needed), checks it
  against the sha256 digest GitHub reports, and unpacks it into the
  gitignored `.engine/<tag>/`. Running the tests and examples no longer
  needs MSYS2 or CMake: point `YSE_DLL_PATH` at the path it prints. It
  fails when the pin is not a release tag. Building from source stays
  documented as the alternative and is what CI still does.
- **Unreleased-engine mode, made visible** (#89): testing against an
  engine that has no release yet is opt-in, by pointing `YSE_DLL_PATH` at
  a build of a separate yse-soundengine clone (README, *Unreleased engine
  (opt-in)*). Every engine test suite now prints an `UNRELEASED ENGINE`
  banner when `System.version` differs from the pinned tag (`3.1.0` vs
  `v3.1.0`) or the library is loaded from outside `.engine/<tag>/` and
  the submodule's `build/bin`; it never fails a test. Committed bindings
  must come from the pinned tag. The pin helpers moved from
  `tool/fetch_engine.dart` to the shared `tool/engine_pin.dart`. The
  loader still does not search `.engine/` on its own.
- `ffigen.yaml` documents `dart run ffigen --config ffigen.yaml` (ffigen
  20 no longer finds the config on its own) (#55).
- `yse_flutter_libs` is bumped to 0.2.0: it packages the same pinned
  libYSE v3.1.0.
- **`yse_flutter_libs` packages the engine's Android release** (#91)
  instead of compiling libYSE with the NDK per ABI. The plugin's
  `android/engine.properties` names the tag and the sha256 of
  `libyse-<tag>-android.tar.gz`; Gradle downloads it once into the Gradle
  user home, checks the digest and adds `arm64-v8a` / `x86_64` as
  `jniLibs`, so consumers (including pub.dev and git dependencies) need
  neither the NDK nor the engine sources. `tool/fetch_engine.dart
  --platform android` unpacks the same asset into `.engine/<tag>/`,
  which the plugin uses in a checkout; the Gradle property
  `yse.engineDir` covers offline builds, and `yse.buildFromSource=true`
  keeps the NDK source build as an opt-in for unreleased engines.
  `test/flutter_libs_engine_test.dart` fails when `engine.properties`
  drifts from the submodule pin.
- **A relative `YSE_DLL_PATH` loads on Windows** (#92). The loader now
  resolves `YSE_DLL_PATH` against the working directory before loading.
  Before, a relative path failed with error 126: `SetDllDirectoryW` takes
  the working directory out of the DLL search order, and `LoadLibrary`
  looks a relative path up along that order, so `libyse.dll` itself was
  not found. A failed load now throws a `YseException` that names the
  resolved path and the likely cause (a missing dependency library).
  `test/library_load_test.dart` loads the engine through a relative path
  in a fresh process.

### Known upstream issues

Open in yvanvds/yse-soundengine, found while wrapping v3.1.0; details and
workarounds are on the upgrade page.

- #1033: an offline session with no `requestedSampleRate` inherits the
  previous session's rate (48 kHz only in a fresh process), and
  `setChannelConfiguration` takes effect only on a block that mixes a
  sound (channel layout applies only while a sound is alive).
- #1175: disposing a never-attached synth with VA or FM voices crashes the
  next synth that is attached to a sound.
- #1176: clearing a MIDI-in callback does not wait for a dispatch already
  in progress, so one in-flight message can race the wrapper's teardown.
- #1177: a synth's setup job can build it before its voices are added;
  the synth then keeps 0 voices with no error. The wrapper throws when it
  can detect a late voice group; it cannot detect an empty build.
- #1181: a disposed `Player` dereferences its synth on the next audio
  block; let one block run before disposing the synth.

### Added since 0.1.0 on the libYSE 2.x engine

These landed between 0.1.0 and the 3.x upgrade and ship for the first
time in 0.2.0:

- **Platforms.** **Android support:** `library.dart` resolves
  `libyse.so` on Android via the Android linker (no path lookup — the
  `.so` is bundled into the host APK / AAB under `lib/<abi>/`). A new
  sibling Flutter plugin `packages/yse_flutter_libs/` cross-compiles the
  engine for each ABI (default `arm64-v8a`, `x86_64`) by
  externalNativeBuild'ing the upstream CMakeLists with NDK 27 / minSdk 26.
  Consumers add both `yse` and `yse_flutter_libs` to their
  `pubspec.yaml`; Gradle picks up the resulting `libyse.so`
  automatically. Oboe is the audio backend (AAudio on API 26+ with
  OpenSL ES fallback). A minimal end-to-end sample lives at
  `example/android_sample/`. README has a parallel Android section
  covering the plugin model, ABI selection, permissions, and threading
  notes.
- **Linux support.** `library.dart` resolves `libyse.so` on Linux in
  addition to `libyse.dll` on Windows. RPATH is `$ORIGIN`, so sibling
  shared libs are discovered without `LD_LIBRARY_PATH`. Tested against
  Ubuntu 24.04 (the GitHub-Actions runner baseline). README has parallel
  Windows / Linux build sections. `tools/ci-linux/Dockerfile` builds an
  image with the engine deps plus the Dart SDK so Windows contributors
  can reproduce a Linux build locally without rebooting.
  `tool/linux_smoke.dart` exercises FFI load + `initOffline` /
  `renderOffline` for headless validation in Docker and CI. A GitHub
  Actions CI job (Ubuntu 24.04) builds the engine and runs
  `dart analyze` / `dart test` / the headless smoke on every push and PR,
  with a strict `dart format` gate (#46).
- **API reference site** (closes #6). New `docs/` tree builds a Sphinx
  site that mirrors the upstream libYSE docs site (sphinx-book-theme, same
  intro / tutorials / API layout) so contributors who already know the
  C++ docs find their way. `tool/emit_api_rst.dart` walks the classes
  re-exported from `lib/yse.dart` and emits one RST page per class
  straight from each class's dartdoc comments — comments stay the
  canonical source of truth. A `.github/workflows/docs.yml` workflow
  builds the site on every push to `main` and publishes to `gh-pages`.
- **`MidiIn`**: broadcast streams of raw and parsed input messages, with
  the native callback installed on first subscription and bridged from
  RtMidi's input thread.
- **Channel peak metering** (pre/post-volume, linear/dB, per output) and
  the live device getters `System.activeSampleRate` /
  `activeBufferSize` / `activeOutputLatency`.
- **`System.sessionSampleRate`**: the session rate, constant from `init`
  to `close` across pause / resume.
- **`LiveCoding`** (#14): submit Python scripts to the engine's embedded
  interpreter and receive tracebacks on `LiveCoding.errors`.
- **`DomainClock` and `ClipTransport`** (#21): named, rampable beat clocks
  and engine-timed MIDI clip playback; `ClipTransport.stop()` flushes
  note-offs for exactly the notes that clip has sounding (#40).
- **`Synth`** (#23): polyphonic voice pools (sine, virtual-analog, FM from
  DX7 banks, SFZ sampler) behind `Sound.fromSynth`, with per-note 3D
  positions (`PositionHandler`); channel and key-range parameters on the
  VA / FM / sampler voice groups (#41).
- **Channel aux sends, return buses and insert DSP** (#24):
  `Channel.createWithSends` / `createReturn`, per-slot sends, and
  `Channel.dsp`.
- **Mix-grade DSP modules** (#25): `Compressor`, `ParametricEq`,
  `Chorus`, `PlateReverb`, `FeedbackDelay`.
- **Patcher object metadata registry** (#26): `PatcherRegistry`,
  `PatcherObjectType` and its inlet / outlet / parameter descriptions.
- **libYSE 2.3.1 surface** (#38): `MorphingReverb`,
  `ReverbPresetValues`, `DspObject.patcherInsert(Patcher)`, and
  `MidiFile.connectSynth` / `MidiIn.connectSynth`.
- `DspObject.link(null)` detaches the forward edge (#42).
- **Host bus tap** (#43): `LiveCoding.bus(prefix)` as a broadcast stream
  of `(address, value)` frames (superseded by `Bus.tap`, #59).

## 0.1.0 — initial Windows release

First public release. Wraps the YSE sound engine
([github.com/yvanvds/yse-soundengine](https://github.com/yvanvds/yse-soundengine))
via a hand-authored C ABI bridge that lives upstream (`YseEngine/c_api/`)
plus ffigen-generated low-level bindings + hand-written idiomatic Dart
wrappers in this package.

**Wrapped subsystems:**

- `System` — lifecycle, devices, MIDI device enumeration, global reverb,
  underwater FX, update loop, version, CPU load
- `Listener` — position, velocity, orientation
- `Sound` — file / buffer / patcher sources, transport, 3D, mixing,
  DSP-chain attachment
- `Channel` — pre-built singletons (ChannelMaster / FX / Music / Ambient /
  Voice / Gui), user-created channels, volume, reverb attach
- `Reverb` — positioned + global, 11 presets, full parameter surface
- `Device` + `DeviceSetup` — descriptor enumeration + open-device config
- `DspBuffer` — plain / drawable / file / wavetable subclasses, bulk
  Float32List I/O, draw_line, file load/save, band-limited wavetables
- `DspObject` — 11 effects (lowpass, highpass, bandpass, sweep,
  basicDelay + lp/hp variants, phaser, ringModulator, difference,
  granulator) plus the inherited bypass / impact / LFO surface
- `Patcher` + `PHandle` + `Obj` constants — Max/MSP-style graph with
  JSON round-trip
- `MidiFile`, `MidiOut` — file playback + device output
- `Note`, `PNote`, `Scale`, `Motif` — music-theory primitives
- `Log` — broadcast `Stream<String>` of engine messages via
  `NativeCallable.listener` with ownership-transfer marshalling
- `BufferIO` — register `Uint8List` assets under string IDs

**Known limitations:**

- Android (and Linux) landed in the next release — see 0.2.0 above.
X but its upstream `player::create(synth&)` factory
  is commented out (synth subsystem deferred upstream) — every method
  call crashes the process. Don't use until YSE restores the synth.
  (Fixed in 0.2.0: `Player(Synth)`.)
- The callback-based `YSE::io` VFS isn't wrapped — `BufferIO` covers
  the common asset-pack use case.
- Custom `dspSourceObject` subclassing isn't wrapped — buffer-source
  sounds via `Sound.fromBuffer` are the procedural-audio path for now.
- No native-assets build hook yet: consumers point `YSE_DLL_PATH` at a
  locally-built `libyse.dll`. See README for the manual setup.
