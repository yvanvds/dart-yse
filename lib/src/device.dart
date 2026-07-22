import 'dart:ffi';

import 'bindings/yse_bindings.g.dart';
import 'ffi_helpers.dart';
import 'library.dart';

/// Read-only descriptor of an audio device on the host system.
///
/// Enumerated by the engine — only valid instances are those handed out
/// by [System.devices]. Inspect [name], [hostName], the channel-name
/// lists, supported sample rates, and buffer sizes; then build a
/// [DeviceSetup] from one and pass it to [System.openDevice].
class Device {
  final YseBindings _b;
  final Pointer<YseDevice> _handle;

  Device._(this._b, this._handle);

  /// Internal: wrap a borrowed pointer returned by `yse_system_get_device`.
  factory Device.borrowed(Pointer<YseDevice> handle) =>
      Device._(bindings, handle);

  /// Internal: native handle (for cross-wrapper plumbing).
  Pointer<YseDevice> get handle => _handle;

  /// Device name as reported by the host.
  String get name =>
      fetchString((buf, cap) => _b.device_get_name(_handle, buf, cap));

  /// Host (driver) name: `ASIO`, `WASAPI`, `ALSA`, `JACK`, ...
  String get hostName =>
      fetchString((buf, cap) => _b.device_get_type_name(_handle, buf, cap));

  /// Output channel names.
  List<String> get outputChannelNames {
    final n = _b.device_num_output_channels(_handle);
    return List<String>.generate(
      n,
      (i) => fetchString(
        (buf, cap) => _b.device_get_output_channel_name(_handle, i, buf, cap),
      ),
      growable: false,
    );
  }

  /// Input channel names.
  List<String> get inputChannelNames {
    final n = _b.device_num_input_channels(_handle);
    return List<String>.generate(
      n,
      (i) => fetchString(
        (buf, cap) => _b.device_get_input_channel_name(_handle, i, buf, cap),
      ),
      growable: false,
    );
  }

  /// All sample rates this device reports as supported.
  List<double> get sampleRates {
    final n = _b.device_num_sample_rates(_handle);
    return List<double>.generate(
      n,
      (i) => _b.device_get_sample_rate(_handle, i),
      growable: false,
    );
  }

  /// All buffer sizes this device reports as supported.
  List<int> get bufferSizes {
    final n = _b.device_num_buffer_sizes(_handle);
    return List<int>.generate(
      n,
      (i) => _b.device_get_buffer_size(_handle, i),
      growable: false,
    );
  }

  /// Default buffer size for this device.
  int get defaultBufferSize => _b.device_default_buffer_size(_handle);

  /// Reported output latency in samples.
  int get outputLatency => _b.device_output_latency(_handle);

  /// Reported input latency in samples.
  int get inputLatency => _b.device_input_latency(_handle);

  /// Host-assigned device ID.
  int get id => _b.device_get_id(_handle);

  @override
  String toString() =>
      'Device($name on $hostName, '
      '${outputChannelNames.length}out/${inputChannelNames.length}in)';
}

/// Configuration passed to [System.openDevice].
///
/// Build one by selecting an output [Device], optionally an input [Device],
/// and (also optionally) explicit sample-rate / buffer-size overrides. The
/// engine falls back to the device's defaults for fields you don't set.
class DeviceSetup implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.device_setup_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseDeviceSetup> _handle;

  DeviceSetup._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Construct an empty setup. Configure with the [input], [output],
  /// [sampleRate], and [bufferSize] setters before passing to
  /// [System.openDevice].
  factory DeviceSetup() {
    final b = bindings;
    final h = b.device_setup_create();
    if (h.address == 0) {
      throw StateError('yse_device_setup_create returned null');
    }
    return DeviceSetup._(b, h);
  }

  /// Internal: native handle (used by `System.openDevice`).
  Pointer<YseDeviceSetup> get handle => _handle;

  /// Select the input device.
  set input(Device value) => _b.device_setup_set_input(_handle, value.handle);

  /// Select the output device.
  set output(Device value) => _b.device_setup_set_output(_handle, value.handle);

  /// Override the device's default sample rate.
  set sampleRate(double value) =>
      _b.device_setup_set_sample_rate(_handle, value);

  /// Override the device's default buffer size.
  set bufferSize(int value) => _b.device_setup_set_buffer_size(_handle, value);

  /// Destroy the underlying native setup and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.device_setup_destroy(_handle);
    _handle = nullptr;
  }
}
