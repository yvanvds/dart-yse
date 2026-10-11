// Tests for MidiIn stream teardown (issue #76): every raw MIDI-in buffer the
// bridge receives is freed exactly once, including buffers still queued on
// the listener port when the stream is torn down.
//
// CI has no MIDI device and no loopback port, so the drain itself is tested
// on the bridge directly: the test posts its own malloc'd buffers through the
// bridge's native function, exactly as the engine's RtMidi thread would, and
// hands the bridge the matching deallocator. The engine-facing part only
// opens a port that cannot exist and checks the subscribe / cancel /
// dispose paths reachable without a device. It drives the real
// `libyse.dll` / `libyse.so`, so set `YSE_DLL_PATH` (see README / CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test test/midi_in_test.dart
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test test/midi_in_test.dart
//
// Not covered: messages from a real device. That needs a virtual or loopback
// MIDI port, which neither the Windows nor the Linux CI runner has.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:test/test.dart';
import 'package:yse/src/midi.dart'
    show MidiInRawBridge, MidiInRawMessage, midiInMessagesFreed;
import 'package:yse/yse.dart';

/// A port index no host enumerates.
const _noSuchPort = 65535;

void main() {
  /// Polls [condition] until it holds or [timeout] passes.
  Future<void> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('condition not met within $timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('MidiInRawBridge', () {
    var freed = 0;
    void free(Pointer<UnsignedChar> p) {
      malloc.free(p);
      freed++;
    }

    setUp(() => freed = 0);

    /// Posts a malloc'd 3-byte note-on through [bridge], as the engine does.
    void post(MidiInRawBridge bridge, int note) {
      final bytes = malloc<UnsignedChar>(3);
      bytes[0] = 0x90;
      bytes[1] = note;
      bytes[2] = 100;
      bridge.nativeFunction
          .asFunction<
            void Function(double, Pointer<UnsignedChar>, int, Pointer<Void>)
          >()(note.toDouble(), bytes, 3, nullptr);
    }

    test('copies each message and frees its buffer', () async {
      final got = <MidiInRawMessage>[];
      final bridge = MidiInRawBridge(got.add, free: free);
      final before = midiInMessagesFreed;
      for (var i = 0; i < 4; i++) {
        post(bridge, 60 + i);
      }
      await waitFor(() => got.length == 4);
      bridge.retire();

      expect(freed, 4);
      expect(midiInMessagesFreed - before, 4);
      expect(got.map((m) => m.bytes), [
        for (var i = 0; i < 4; i++) [0x90, 60 + i, 100],
      ]);
      expect(got.map((m) => m.timestamp), [60.0, 61.0, 62.0, 63.0]);
    });

    test(
      'retire frees buffers still queued and delivers none of them',
      () async {
        final got = <MidiInRawMessage>[];
        final bridge = MidiInRawBridge(got.add, free: free);
        const n = 50;
        for (var i = 0; i < n; i++) {
          post(bridge, i);
        }
        // All n calls are still queued on the listener port.
        expect(freed, 0);
        bridge.retire();

        // Closing the listener outright would drop the queued calls and leak
        // their buffers; the drain marker makes the bridge free every one.
        await waitFor(() => freed == n);
        expect(got, isEmpty, reason: 'nothing is delivered after retire');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(freed, n, reason: 'each buffer is freed exactly once');
      },
    );
  });

  group('MidiIn without a device', () {
    test('raw and parsed streams subscribe, cancel and re-subscribe', () async {
      final port = MidiIn.open(_noSuchPort);
      addTearDown(port.dispose);
      expect(port.isOpen, isFalse);

      final raw = port.rawMessages.listen((_) {});
      final parsed = port.parsedMessages.listen((_) {});
      await raw.cancel();
      await parsed.cancel();

      final again = port.rawMessages.listen((_) {});
      await again.cancel();
    });

    test('dispose closes both streams', () async {
      final port = MidiIn.open(_noSuchPort);
      final rawDone = Completer<void>();
      final parsedDone = Completer<void>();
      port.rawMessages.listen((_) {}, onDone: rawDone.complete);
      port.parsedMessages.listen((_) {}, onDone: parsedDone.complete);

      port.dispose();
      await rawDone.future;
      await parsedDone.future;
      port.dispose(); // idempotent
    });
  });
}
