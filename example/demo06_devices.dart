// M2 example — port of Demo06_Devices.cpp.
//
// Enumerates audio devices visible to YSE and prints their details
// (host, output channels, sample rates, buffer sizes). The C++ demo lets
// you switch devices interactively; this CLI port just lists.
//
// It lists without opening a stream: an offline session plus
// System.refreshDevices() (libYSE 3.1), so it also works when the default
// device is busy or missing. To open one, build a DeviceSetup from a
// listed Device and call System.openDevice — see the "Sessions and
// devices" docs page.
//
// Run:
//   YSE_DLL_PATH=D:\yse-soundengine\build\bin  dart run example/demo06_devices.dart

// ignore_for_file: avoid_print

import 'package:yse/yse.dart';

Future<void> main() async {
  final sys = System.instance;
  sys.initOffline();

  if (!sys.refreshDevices()) {
    print('The audio backend could not start; see the engine log.');
    sys.close();
    return;
  }

  print('Default device : ${sys.defaultDevice}');
  print('Default host   : ${sys.defaultHost}');
  print('');

  final devs = sys.devices;
  print('Found ${devs.length} device(s):');
  for (var i = 0; i < devs.length; i++) {
    final d = devs[i];
    final out = d.outputChannelNames;
    final sr = d.sampleRates;
    final bs = d.bufferSizes;
    print('');
    print('[$i] ${d.name}');
    print('    host           : ${d.hostName}');
    print('    output channels: ${out.length} ${out.isEmpty ? "" : out}');
    print('    input channels : ${d.inputChannelNames.length}');
    print('    sample rates   : $sr');
    print('    buffer sizes   : $bs (default ${d.defaultBufferSize})');
    print(
      '    latency        : in=${d.inputLatency} out=${d.outputLatency} samples',
    );
    print('    id             : ${d.id}');
  }

  sys.close();
}
