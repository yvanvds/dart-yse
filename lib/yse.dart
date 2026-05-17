/// Dart bindings for the YSE sound engine.
///
/// All API calls must be made from the same isolate that called
/// [System.instance].`init()`. Call [System.instance].`update()` once per
/// frame to drive state transitions and listener-velocity updates, or use
/// [System.instance].`startUpdateTimer()` for a convenient periodic timer.
///
/// Typical usage:
/// ```dart
/// import 'package:yse/yse.dart';
///
/// final sys = System.instance;
/// sys.init();
/// sys.startUpdateTimer();
///
/// final sound = Sound.fromFile('drone.ogg', loop: true);
/// sound.play();
///
/// // ... game loop continues ...
///
/// sound.dispose();
/// sys.close();
/// ```
library;

export 'src/channel.dart' show Channel;
export 'src/device.dart' show Device, DeviceSetup;
export 'src/dsp_buffer.dart' show DspBuffer;
export 'src/dsp_object.dart' show DspObject;
export 'src/enums.dart'
    show ChannelType, DelayTap, LfoType, OutType, ReverbPreset, SweepShape;
export 'src/exception.dart' show YseException;
export 'src/listener.dart' show Listener;
export 'src/midi.dart' show MidiFile, MidiOut;
export 'src/patcher.dart' show Obj, PHandle, Patcher;
export 'src/pos.dart' show Pos;
export 'src/reverb.dart' show Reverb;
export 'src/sound.dart' show Sound;
export 'src/system.dart' show System;
