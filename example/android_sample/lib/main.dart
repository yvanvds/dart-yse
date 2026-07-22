// Minimal Flutter sample exercising package:yse on Android.
//
// Flow:
//   1. Copy the bundled drone.ogg asset to the app's documents directory
//      (libsndfile needs a real filesystem path, not a Flutter asset
//      bundle URI).
//   2. Initialise the engine, load the sound on loop, start playback.
//   3. Drive sys.update() from a Timer.periodic on the UI isolate — this
//      is the same isolate that called init(), matching the threading
//      rule in the dart-yse README.
//   4. Stop / dispose / close on widget disposal.
//
// Run on a connected device or x86_64 emulator:
//   cd example/android_sample
//   flutter create --platforms=android .   # one-time scaffold
//   flutter run

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:yse/yse.dart';

void main() => runApp(const YseSampleApp());

class YseSampleApp extends StatelessWidget {
  const YseSampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'yse Android sample',
    theme: ThemeData(useMaterial3: true),
    home: const YsePlaybackPage(),
  );
}

class YsePlaybackPage extends StatefulWidget {
  const YsePlaybackPage({super.key});

  @override
  State<YsePlaybackPage> createState() => _YsePlaybackPageState();
}

class _YsePlaybackPageState extends State<YsePlaybackPage> {
  Sound? _sound;
  late final System _sys;
  Stream<DateTime>? _ticker;
  String _status = 'Initialising…';
  String? _engineVersion;

  @override
  void initState() {
    super.initState();
    _sys = System.instance;
    _start();
  }

  Future<void> _start() async {
    try {
      _engineVersion = System.version;
      _sys.init();

      final assetBytes = await rootBundle.load('assets/drone.ogg');
      final docDir = await getApplicationDocumentsDirectory();
      final soundFile = File('${docDir.path}/drone.ogg');
      await soundFile.writeAsBytes(
        assetBytes.buffer.asUint8List(),
        flush: true,
      );

      final sound = Sound.fromFile(soundFile.path, loop: true, volume: 0.6);
      sound.play();
      _sound = sound;

      // Pump the engine on the UI isolate every 16 ms.
      _ticker = Stream<DateTime>.periodic(const Duration(milliseconds: 16), (
        _,
      ) {
        _sys.update();
        return DateTime.now();
      });

      setState(() => _status = 'Playing drone.ogg on loop');
    } catch (e, st) {
      setState(() => _status = 'Failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _sound?.stop();
    _sound?.dispose();
    _sys.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('yse Android sample')),
      body: StreamBuilder<DateTime>(
        stream: _ticker,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'libYSE ${_engineVersion ?? '(loading)'}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(_status),
                const SizedBox(height: 24),
                if (_ticker != null) ...[
                  Text('CPU load: ${_sys.cpuLoad.toStringAsFixed(3)}'),
                  Text('Missed callbacks: ${_sys.missedCallbacks}'),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
