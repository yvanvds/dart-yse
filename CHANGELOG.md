# Changelog

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

- Windows only. Linux + Android are next.
- `Player` is wrapped but its upstream `player::create(synth&)` factory
  is commented out (synth subsystem deferred upstream) — every method
  call crashes the process. Don't use until YSE restores the synth.
- The callback-based `YSE::io` VFS isn't wrapped — `BufferIO` covers
  the common asset-pack use case.
- Custom `dspSourceObject` subclassing isn't wrapped — buffer-source
  sounds via `Sound.fromBuffer` are the procedural-audio path for now.
- No native-assets build hook yet: consumers point `YSE_DLL_PATH` at a
  locally-built `libyse.dll`. See README for the manual setup.
