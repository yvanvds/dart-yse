// Obj's constants are self-documenting (matched to the YSE::OBJ source of
// truth in upstream's patcher/pObjectList.hpp); the class-level doc and
// the upstream docs explain the set. Per-constant docs would just repeat
// the identifier.
// ignore_for_file: public_member_api_docs

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'enums.dart';
import 'ffi_helpers.dart';
import 'library.dart';

/// Compile-time string identifiers for patcher object types.
///
/// Pass any of these to [Patcher.createObject] instead of raw string
/// literals. The `~` prefix marks DSP / audio-rate objects, `.` marks
/// control-rate objects. Mirrors `YSE::OBJ` in
/// `patcher/pObjectList.hpp`.
class Obj {
  Obj._();

  static const String patcher = 'patcher';

  // I/O.
  static const String dDac = '~dac';
  static const String dAdc = '~adc';
  static const String dOut = '~out';
  static const String dLine = '~line';
  static const String gReceive = '.r';
  static const String gSend = '.s';

  // DSP generators.
  static const String dSine = '~sine';
  static const String dSaw = '~saw';
  static const String dNoise = '~noise';

  // Control objects.
  static const String gInt = '.i';
  static const String gFloat = '.f';
  static const String gSlider = '.slider';
  static const String gButton = '.b';
  static const String gToggle = '.t';
  static const String gMessage = '.m';
  static const String gList = '.l';
  static const String gText = '.text';
  static const String gCounter = '.counter';
  static const String gSwitch = '.switch';
  static const String gGate = '.gate';
  static const String gRoute = '.route';

  // Control math.
  static const String gAdd = '.+';
  static const String gSubtract = '.-';
  static const String gMultiply = '.*';
  static const String gDivide = './';

  // DSP math.
  static const String dAdd = '~+';
  static const String dSubtract = '~-';
  static const String dMultiply = '~*';
  static const String dDivide = '~/';
  static const String dClip = '~clip';

  // Conversion.
  static const String midiToFrequency = '.mtof';
  static const String frequencyToMidi = '.ftom';

  // Filters.
  static const String dLowpass = '~lp';
  static const String dHighpass = '~hp';
  static const String dBandpass = '~bp';
  static const String dVcf = '~vcf';

  // Timing / random.
  static const String gRandom = '.random';
  static const String gMetro = '.metro';

  // MIDI.
  static const String mOut = '.midiout';
  static const String mNoteOn = '.noteon';
  static const String mNoteOff = '.noteoff';
  static const String mControl = '.controlchange';
  static const String mPolyPress = '.polypressure';
  static const String mChanPress = '.channelpressure';
  static const String mProgChange = '.programchange';

  /// Whether [type] is a known object type identifier.
  static bool isValid(String type) => using((arena) {
        final cstr = type.toNativeUtf8(allocator: arena);
        return bindings.patcher_is_valid_object(cstr.cast()) != 0;
      });
}

/// Modular DSP/event graph (Max/MSP-style patcher).
///
/// Build a graph programmatically with [createObject] + [connect], or
/// load one from a JSON dump via [parseJson]. Drive it directly with
/// [passBang] / [passInt] / [passFloat] / [passString] into named
/// `.r` (`Obj.gReceive`) objects, or hand it to a [Sound] via
/// [Sound.fromPatcher] to use it as an audio source.
class Patcher implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.patcher_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YsePatcher> _handle;

  Patcher._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Construct a patcher with [mainOutputs] audio output channels.
  factory Patcher({int mainOutputs = 2}) {
    final b = bindings;
    final h = b.patcher_create();
    if (h.address == 0) {
      throw StateError('yse_patcher_create returned null');
    }
    final p = Patcher._(b, h);
    b.patcher_init(h, mainOutputs);
    return p;
  }

  /// Internal: native handle (used by `Sound.fromPatcher`).
  Pointer<YsePatcher> get handle => _handle;

  // ─── object management ─────────────────────────────────────────────────

  /// Add an object of [type] to the patcher (see [Obj] for constants).
  ///
  /// [args] is the creation argument string (object-specific format).
  /// The returned [PHandle] is owned by the patcher — release with
  /// [deleteObject], never directly.
  PHandle createObject(String type, {String args = ''}) => using((arena) {
        final typePtr = type.toNativeUtf8(allocator: arena);
        final argsPtr = args.toNativeUtf8(allocator: arena);
        final h = _b.patcher_create_object(_handle, typePtr.cast(), argsPtr.cast());
        if (h.address == 0) {
          throw StateError('createObject("$type", "$args") returned null');
        }
        return PHandle._(h);
      });

  /// Remove [obj] from the patcher.
  void deleteObject(PHandle obj) => _b.patcher_delete_object(_handle, obj._handle);

  /// Remove every object from the patcher.
  void clear() => _b.patcher_clear(_handle);

  /// Connect [from]'s [outlet] to [to]'s [inlet].
  void connect(PHandle from, {required int outlet, required PHandle to, required int inlet}) =>
      _b.patcher_connect(_handle, from._handle, outlet, to._handle, inlet);

  /// Remove the connection from [from]'s [outlet] to [to]'s [inlet].
  void disconnect(PHandle from, {required int outlet, required PHandle to, required int inlet}) =>
      _b.patcher_disconnect(_handle, from._handle, outlet, to._handle, inlet);

  // ─── persistence ───────────────────────────────────────────────────────

  /// Serialise the current graph to JSON.
  String dumpJson() => fetchString(
        (buf, cap) => _b.patcher_dump_json(_handle, buf, cap),
      );

  /// Replace the current graph with the contents of a JSON dump.
  void parseJson(String content) => using((arena) {
        final cstr = content.toNativeUtf8(allocator: arena);
        _b.patcher_parse_json(_handle, cstr.cast());
      });

  // ─── enumeration ───────────────────────────────────────────────────────

  /// Number of objects in the patcher.
  int get objects => _b.patcher_objects(_handle);

  /// Object at position [index] in the list (0-indexed).
  PHandle getHandleAt(int index) =>
      PHandle._(_b.patcher_get_handle_from_list(_handle, index));

  /// Object whose ID is [id].
  PHandle getHandleById(int id) =>
      PHandle._(_b.patcher_get_handle_from_id(_handle, id));

  // ─── message I/O ───────────────────────────────────────────────────────

  /// Send a bang to the named `.r` receive object. Returns false if no
  /// such receiver exists.
  bool passBang(String to) => using((arena) {
        final cstr = to.toNativeUtf8(allocator: arena);
        return _b.patcher_pass_bang(_handle, cstr.cast()) != 0;
      });

  /// Send an integer to a named receiver.
  bool passInt(int value, String to) => using((arena) {
        final cstr = to.toNativeUtf8(allocator: arena);
        return _b.patcher_pass_int(_handle, value, cstr.cast()) != 0;
      });

  /// Send a float to a named receiver.
  bool passFloat(double value, String to) => using((arena) {
        final cstr = to.toNativeUtf8(allocator: arena);
        return _b.patcher_pass_float(_handle, value, cstr.cast()) != 0;
      });

  /// Send a string to a named receiver.
  bool passString(String value, String to) => using((arena) {
        final valPtr = value.toNativeUtf8(allocator: arena);
        final toPtr = to.toNativeUtf8(allocator: arena);
        return _b.patcher_pass_string(_handle, valPtr.cast(), toPtr.cast()) != 0;
      });

  /// Destroy the underlying native patcher and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.patcher_destroy(_handle);
    _handle = nullptr;
  }
}

/// Handle to one object inside a [Patcher].
///
/// Owned by the patcher — destruction is via [Patcher.deleteObject], not
/// by the [PHandle] going out of scope.
class PHandle {
  final Pointer<YsePHandle> _handle;
  PHandle._(this._handle);

  /// Type identifier of the underlying object (matches one of [Obj]).
  String get type => fetchString(
        (buf, cap) => bindings.phandle_get_type(_handle, buf, cap),
      );

  /// Display name set in the patcher source.
  String get name => fetchString(
        (buf, cap) => bindings.phandle_get_name(_handle, buf, cap),
      );

  /// Original creation argument string.
  String get params => fetchString(
        (buf, cap) => bindings.phandle_get_params(_handle, buf, cap),
      );

  /// Current GUI display value for objects that have one
  /// (sliders, toggles, ...).
  String get guiValue => fetchString(
        (buf, cap) => bindings.phandle_get_gui_value(_handle, buf, cap),
      );

  /// Patcher-assigned unique ID.
  int get id => bindings.phandle_get_id(_handle);

  /// Number of inlets on this object.
  int get inputs => bindings.phandle_get_inputs(_handle);

  /// Number of outlets on this object.
  int get outputs => bindings.phandle_get_outputs(_handle);

  /// Whether [inlet] accepts an audio signal.
  bool isDspInput(int inlet) => bindings.phandle_is_dsp_input(_handle, inlet) != 0;

  /// Data type produced by [pin].
  OutType outputDataType(int pin) => OutType.values.firstWhere(
        (e) => e.native == bindings.phandle_output_data_type(_handle, pin),
        orElse: () => OutType.invalid,
      );

  /// Number of connections leaving [outlet].
  int connectionCount(int outlet) =>
      bindings.phandle_get_connections(_handle, outlet);

  /// ID of the target object of one [connection] from [outlet].
  int connectionTargetId(int outlet, int connection) =>
      bindings.phandle_get_connection_target(_handle, outlet, connection);

  /// Inlet on the target reached by [connection] from [outlet].
  int connectionTargetInlet(int outlet, int connection) =>
      bindings.phandle_get_connection_target_inlet(_handle, outlet, connection);

  /// Send a bang to [inlet].
  void sendBang(int inlet) => bindings.phandle_set_bang(_handle, inlet);

  /// Send an integer to [inlet].
  void sendInt(int inlet, int value) => bindings.phandle_set_int(_handle, inlet, value);

  /// Send a float to [inlet].
  void sendFloat(int inlet, double value) =>
      bindings.phandle_set_float(_handle, inlet, value);

  /// Send a string/list to [inlet].
  void sendList(int inlet, String value) => using((arena) {
        final cstr = value.toNativeUtf8(allocator: arena);
        bindings.phandle_set_list(_handle, inlet, cstr.cast());
      });

  /// Reconfigure the object with a new argument string.
  void setParams(String args) => using((arena) {
        final cstr = args.toNativeUtf8(allocator: arena);
        bindings.phandle_set_params(_handle, cstr.cast());
      });

  /// Read a GUI property by [key].
  String getGuiProperty(String key) => fetchString(
        (buf, cap) => using((arena) {
          final cstr = key.toNativeUtf8(allocator: arena);
          return bindings.phandle_get_gui_property(_handle, cstr.cast(), buf, cap);
        }),
      );

  /// Write a GUI property.
  void setGuiProperty(String key, String value) => using((arena) {
        final keyPtr = key.toNativeUtf8(allocator: arena);
        final valPtr = value.toNativeUtf8(allocator: arena);
        bindings.phandle_set_gui_property(_handle, keyPtr.cast(), valPtr.cast());
      });
}
