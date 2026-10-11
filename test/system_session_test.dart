// Integration tests for the libYSE 3 session and device semantics (issue
// #56): the requested session sample rate, the device-less speaker layout,
// and `openDevice` reporting a refused setup.
//
// These drive the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test
//
// Unlike the other suites this one owns the session per test: the sample
// rate is chosen before init, so each test brings the engine up itself and
// closes it again. Everything stays on the offline path — CI has no audio
// device, and `init()` now throws without one.
//
// The engine's session rate is process-global and, with no request set, a
// new session inherits the previous one's rate. Suites share one process, so
// tearDownAll puts the engine back on 48 kHz for whoever runs next.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:yse/yse.dart';

void main() {
  final sys = System.instance;

  /// Bring up an offline session and close it (and clear any rate request,
  /// which survives close) when the test ends.
  void offlineSession() {
    sys.initOffline();
    addTearDown(() {
      sys.close();
      sys.requestedSampleRate = 0;
    });
  }

  /// Keep a sound alive so rendered blocks actually reach the mixer — the
  /// engine skips the mix, and with it the layout resize, while no sound
  /// exists — then render until master reports [outputs] speakers.
  int renderLayout(int outputs) {
    final buffer = DspBuffer.plain(length: 1024);
    final sound = Sound.fromBuffer(buffer, loop: true, volume: 0);
    addTearDown(() {
      sound.dispose();
      buffer.dispose();
    });
    sound.play();
    for (var i = 0; i < 50 && Channel.master.numOutputs != outputs; i++) {
      sys.update();
      sys.renderOffline(1);
    }
    return Channel.master.numOutputs;
  }

  setUp(() => sys.requestedSampleRate = 0);

  tearDownAll(() {
    sys.requestedSampleRate = 48000;
    sys.initOffline();
    sys.close();
    sys.requestedSampleRate = 0;
  });

  group('requested sample rate', () {
    test('an offline session defaults to 48 kHz with no request', () {
      expect(sys.requestedSampleRate, 0);
      offlineSession();
      expect(sys.sessionSampleRate, 48000);
    });

    test('an offline session runs exactly at the requested rate', () {
      sys.requestedSampleRate = 44100;
      expect(sys.requestedSampleRate, 44100);
      offlineSession();
      expect(sys.sessionSampleRate, 44100);
      sys.renderOffline(4);
    });

    test('the request survives close and 0 clears it', () {
      addTearDown(() => sys.requestedSampleRate = 0);
      sys.requestedSampleRate = 96000;
      sys.initOffline();
      expect(sys.sessionSampleRate, 96000);
      sys.close();
      expect(sys.sessionSampleRate, 0);

      // Still requested for the next session.
      expect(sys.requestedSampleRate, 96000);
      sys.initOffline();
      expect(sys.sessionSampleRate, 96000);
      sys.close();

      sys.requestedSampleRate = 0;
      expect(sys.requestedSampleRate, 0);
    });

    test('a request overrides the previous session rate', () {
      sys.requestedSampleRate = 22050;
      sys.initOffline();
      sys.close();

      sys.requestedSampleRate = 32000;
      offlineSession();
      expect(sys.sessionSampleRate, 32000);
    });

    test('a negative rate is rejected', () {
      expect(() => sys.requestedSampleRate = -1, throwsArgumentError);
      expect(sys.requestedSampleRate, 0);
    });
  });

  group('setChannelConfiguration', () {
    test('gives an offline session a quad layout', () {
      offlineSession();
      // initOffline installs stereo.
      expect(renderLayout(2), 2);

      sys.setChannelConfiguration(ChannelType.quad, 4);
      expect(renderLayout(4), 4);
    });

    test('rejects a layout with no outputs', () {
      offlineSession();
      expect(
        () => sys.setChannelConfiguration(ChannelType.auto, 0),
        throwsArgumentError,
      );
      expect(renderLayout(2), 2);
    });
  });

  group('openDevice', () {
    test('an empty setup reports no output channels', () {
      final setup = DeviceSetup();
      addTearDown(setup.dispose);
      expect(setup.outputChannels, 0);
    });

    test('throws for a setup with no output device and leaves the layout '
        'alone', () {
      offlineSession();
      sys.setChannelConfiguration(ChannelType.quad, 4);
      expect(renderLayout(4), 4);

      final setup = DeviceSetup();
      addTearDown(setup.dispose);
      expect(
        () => sys.openDevice(setup),
        throwsA(
          isA<YseException>().having(
            (e) => e.status?.name,
            'status',
            'YSE_ERR_AUDIO_DEVICE',
          ),
        ),
      );
      expect(sys.activeSampleRate, 0);
      sys.update();
      sys.renderOffline(2);
      expect(Channel.master.numOutputs, 4);
    });
  });

  group('MIDI device names', () {
    test('an id past the device count reads as an empty name', () {
      offlineSession();
      expect(sys.midiInDeviceName(sys.midiInDeviceCount), isEmpty);
      expect(sys.midiOutDeviceName(sys.midiOutDeviceCount), isEmpty);
    });
  });
}
