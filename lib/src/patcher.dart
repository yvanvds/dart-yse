import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'enums.dart';
import 'exception.dart';
import 'ffi_helpers.dart';
import 'library.dart';

// `Obj`, generated from the engine registry by tool/gen_obj_constants.dart.
part 'patcher_objects.dart';

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
  ///
  /// Pass [name] to name the patcher from the start (see [name] for the
  /// rules); `null` or `''` keeps the auto-generated `patcher_<N>` name.
  ///
  /// Throws [YseException] if the engine rejects the configuration (e.g. a
  /// negative [mainOutputs], or a [name] longer than [maxNameLength]).
  factory Patcher({int mainOutputs = 2, String? name}) {
    final b = bindings;
    final h = b.patcher_create();
    if (h.address == 0) {
      throw StateError('yse_patcher_create returned null');
    }
    final p = Patcher._(b, h);
    try {
      // Before init the engine stashes the name and applies it at init, so
      // the patcher never registers on the bus under its auto-name.
      if (name != null && name.isNotEmpty) p.name = name;
      checkStatus(b.patcher_init(h, mainOutputs), b);
    } catch (_) {
      p.dispose();
      rethrow;
    }
    return p;
  }

  /// Internal: native handle (used by `Sound.fromPatcher`).
  Pointer<YsePatcher> get handle => _handle;

  // ─── naming ────────────────────────────────────────────────────────────

  /// The longest [name] the engine accepts, in characters.
  static const int maxNameLength = 55;

  /// The patcher's name, which scopes every bus slot inside it.
  ///
  /// Every patcher has one: an unnamed patcher gets an auto-generated
  /// `patcher_<N>`. A `.s` (`Obj.gSend`) object with slot `x` in a patcher
  /// named `foo` publishes to `patcher.foo.x`, and a `.r` (`Obj.gReceive`)
  /// with slot `x` hears a [Bus.publish] to `patcher.foo.x`. Note the
  /// `patcher.` prefix: host code addressing a patcher slot must add it.
  ///
  /// Setting `null` or `''` restores the auto-generated name. Renaming
  /// re-anchors every slot under the new name. Names are **not** unique:
  /// two patchers with the same name share their slots and stores.
  ///
  /// The name can be set before the engine is initialised; it is applied
  /// at init. It is saved by [dumpJson] and applied by [parseJson] unless
  /// a name was already set.
  ///
  /// Throws [YseException] (`invalidArgument`) for a name longer than
  /// [maxNameLength] characters; the current name is kept.
  String get name =>
      fetchString((buf, cap) => _b.patcher_get_name(_handle, buf, cap));
  set name(String? value) {
    final status = using(
      (arena) => _b.patcher_set_name(
        _handle,
        value == null || value.isEmpty
            ? nullptr
            : value.toNativeUtf8(allocator: arena).cast(),
      ),
    );
    checkStatus(status, _b);
  }

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
    return PHandle._(this, h);
  });

  /// Remove [obj] from the patcher.
  ///
  /// Deleting a subpatcher (an [Obj.patcher] object) also deletes
  /// everything inside it, transitively — nested subpatchers and their
  /// contents included. Any [PHandle] you still hold that pointed inside
  /// the deleted group is **dangling** afterwards: do not use it.
  void deleteObject(PHandle obj) =>
      _b.patcher_delete_object(_handle, obj._handle);

  /// Remove every object from the patcher.
  void clear() => _b.patcher_clear(_handle);

  // ─── subpatchers ───────────────────────────────────────────────────────

  /// Put [obj] inside the subpatcher [container], or move it back to the
  /// top level when [container] is `null`.
  ///
  /// A subpatcher is an object of type [Obj.patcher]. It is not a separate
  /// [Patcher]: create its contents with [createObject] on this patcher,
  /// then move them inside with this call. Its pins are the boundary
  /// objects among its direct contents — `.inlet` / `~inlet`
  /// ([Obj.gInlet] / [Obj.dInlet]) and `.outlet` / `~outlet`
  /// ([Obj.gOutlet] / [Obj.dOutlet]), whose one creation argument is the
  /// pin index. Message and signal boundaries share one index space per
  /// side. Subpatchers nest.
  ///
  /// Containment is addressing, not storage: nested objects stay in this
  /// patcher's one flat graph, so nesting costs the audio thread nothing.
  /// Moving an object changes no connection, so place objects before you
  /// [connect] to the subpatcher's pins.
  ///
  /// Throws [ArgumentError] when [obj] or [container] belongs to another
  /// patcher. Throws [YseException] when the engine refuses the move —
  /// [container] is not an [Obj.patcher] object, or the move would put a
  /// subpatcher inside itself or one of its own descendants. A refused
  /// move changes nothing.
  void setContainer(PHandle obj, PHandle? container) {
    _checkOwned(obj, 'obj');
    if (container != null) _checkOwned(container, 'container');
    _b.patcher_set_container(
      _handle,
      obj._handle,
      container?._handle ?? nullptr,
    );
    // The engine refuses an illegal move with a log line and no status, so
    // read the containment back to report the refusal.
    if (obj.container != container) {
      throw YseException(
        'setContainer refused: cannot move ${obj.type} into '
        '${container?.type ?? 'the top level'} (container must be a '
        '"${Obj.patcher}" object and the move must not create a cycle)',
      );
    }
  }

  void _checkOwned(PHandle h, String name) {
    if (!identical(h._patcher, this)) {
      throw ArgumentError.value(h, name, 'belongs to another patcher');
    }
  }

  /// Connect [from]'s [outlet] to [to]'s [inlet].
  ///
  /// Either end may be a subpatcher ([Obj.patcher] object): the pin number
  /// is resolved to the boundary object inside it that claims that index,
  /// and the connection is recorded straight to that boundary object (so
  /// walking the graph or [dumpJson] reports the boundary object's ID).
  /// Connecting to a pin no boundary object claims is refused.
  void connect(
    PHandle from, {
    required int outlet,
    required PHandle to,
    required int inlet,
  }) => _b.patcher_connect(_handle, from._handle, outlet, to._handle, inlet);

  /// Remove the connection from [from]'s [outlet] to [to]'s [inlet].
  ///
  /// A subpatcher end resolves through its boundary objects as in
  /// [connect].
  void disconnect(
    PHandle from, {
    required int outlet,
    required PHandle to,
    required int inlet,
  }) => _b.patcher_disconnect(_handle, from._handle, outlet, to._handle, inlet);

  // ─── persistence ───────────────────────────────────────────────────────

  /// Serialise the current graph to JSON.
  String dumpJson() =>
      fetchString((buf, cap) => _b.patcher_dump_json(_handle, buf, cap));

  /// Load a JSON dump (as produced by [dumpJson]) into this patcher.
  ///
  /// Loading **adds to** the current graph: objects already in the patcher
  /// are kept and the loaded ones are created next to them. Call [clear]
  /// first to replace the patch.
  ///
  /// Throws [YseException] if [content] is malformed JSON or not a patch.
  /// A failed load is rolled back: the patcher is left exactly as it was.
  void parseJson(String content) {
    final status = using((arena) {
      final cstr = content.toNativeUtf8(allocator: arena);
      return _b.patcher_parse_json(_handle, cstr.cast());
    });
    checkStatus(status, _b);
  }

  // ─── enumeration ───────────────────────────────────────────────────────

  /// Number of objects in the patcher.
  int get objects => _b.patcher_objects(_handle);

  /// Object at position [index] in the list (0-indexed).
  PHandle getHandleAt(int index) =>
      PHandle._(this, _b.patcher_get_handle_from_list(_handle, index));

  /// Object whose ID is [id].
  PHandle getHandleById(int id) =>
      PHandle._(this, _b.patcher_get_handle_from_id(_handle, id));

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
///
/// Two [PHandle]s are equal when they refer to the same engine object, so a
/// handle read back from [container] compares equal to the one returned by
/// [Patcher.createObject].
class PHandle {
  final Patcher _patcher;
  final Pointer<YsePHandle> _handle;
  PHandle._(this._patcher, this._handle);

  @override
  bool operator ==(Object other) =>
      other is PHandle && other._handle.address == _handle.address;

  @override
  int get hashCode => _handle.address.hashCode;

  // ─── subpatchers ───────────────────────────────────────────────────────

  /// The subpatcher this object is directly inside, or `null` at the top
  /// level. Change it with [Patcher.setContainer].
  PHandle? get container {
    final c = _patcher._b.patcher_get_container(_patcher._handle, _handle);
    return c.address == 0 ? null : PHandle._(_patcher, c);
  }

  /// How many inlets this subpatcher presents to its parent: one past the
  /// highest index claimed by a `.inlet` or `~inlet` among its direct
  /// contents (messages and signals share one numbering). A subpatcher
  /// whose only `.inlet` has index 2 reports 3. `0` when this object is
  /// not an [Obj.patcher].
  ///
  /// Ask this, not [inputs]: a subpatcher owns no pins of its own, so
  /// [inputs] answers 0 for it.
  int get subpatcherInlets =>
      _patcher._b.patcher_subpatcher_inlets(_patcher._handle, _handle);

  /// How many outlets this subpatcher presents to its parent; the
  /// `.outlet` / `~outlet` counterpart of [subpatcherInlets]. Ask this, not
  /// [outputs], which answers 0 for a subpatcher.
  int get subpatcherOutlets =>
      _patcher._b.patcher_subpatcher_outlets(_patcher._handle, _handle);

  /// Type identifier of the underlying object (matches one of [Obj]).
  String get type =>
      fetchString((buf, cap) => bindings.phandle_get_type(_handle, buf, cap));

  /// Display name set in the patcher source.
  String get name =>
      fetchString((buf, cap) => bindings.phandle_get_name(_handle, buf, cap));

  /// Original creation argument string.
  String get params =>
      fetchString((buf, cap) => bindings.phandle_get_params(_handle, buf, cap));

  /// Current GUI display value for objects that have one
  /// (sliders, toggles, ...).
  String get guiValue => fetchString(
    (buf, cap) => bindings.phandle_get_gui_value(_handle, buf, cap),
  );

  /// Patcher-assigned ID, or `null` when this handle refers to no object
  /// (the engine's `YSE_PATCHER_ID_NONE`).
  ///
  /// IDs start at 0 in every patcher, so 0 is a real ID. They are dense and
  /// **reused**: deleting an object frees its number for the next object
  /// created, so an ID identifies an object only while that object is
  /// alive. Keep the [PHandle] if you need a reference that outlives the
  /// number.
  int? get id => _idOrNull(bindings.phandle_get_id(_handle));

  /// Number of inlets on this object.
  ///
  /// `0` for a subpatcher ([Obj.patcher]): its pins belong to the boundary
  /// objects inside it. Use [subpatcherInlets] instead.
  int get inputs => bindings.phandle_get_inputs(_handle);

  /// Number of outlets on this object.
  ///
  /// `0` for a subpatcher ([Obj.patcher]); use [subpatcherOutlets].
  int get outputs => bindings.phandle_get_outputs(_handle);

  /// Whether [inlet] accepts an audio signal.
  bool isDspInput(int inlet) =>
      bindings.phandle_is_dsp_input(_handle, inlet) != 0;

  /// Data type produced by [pin].
  OutType outputDataType(int pin) => OutType.values.firstWhere(
    (e) => e.native == bindings.phandle_output_data_type(_handle, pin),
    orElse: () => OutType.invalid,
  );

  /// Number of connections leaving [outlet].
  int connectionCount(int outlet) =>
      bindings.phandle_get_connections(_handle, outlet);

  /// ID of the target object of one [connection] from [outlet], or `null`
  /// when there is no such edge (the engine's `YSE_PATCHER_ID_NONE`: an
  /// outlet or connection index out of range). See [id] for ID lifetime.
  int? connectionTargetId(int outlet, int connection) => _idOrNull(
    bindings.phandle_get_connection_target(_handle, outlet, connection),
  );

  /// Inlet on the target reached by [connection] from [outlet], or `null`
  /// when there is no such edge (the engine's `YSE_PATCHER_INLET_NONE`).
  int? connectionTargetInlet(int outlet, int connection) {
    final inlet = bindings.phandle_get_connection_target_inlet(
      _handle,
      outlet,
      connection,
    );
    return inlet == YSE_PATCHER_INLET_NONE ? null : inlet;
  }

  static int? _idOrNull(int id) => id == YSE_PATCHER_ID_NONE ? null : id;

  /// Send a bang to [inlet].
  void sendBang(int inlet) => bindings.phandle_set_bang(_handle, inlet);

  /// Send an integer to [inlet].
  void sendInt(int inlet, int value) =>
      bindings.phandle_set_int(_handle, inlet, value);

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

/// Reads an engine-owned `const char*` into a Dart string.
///
/// The registry metadata getters hand back pointers into engine storage
/// whose lifetime is the whole process — they must **not** be freed. A
/// NULL pointer (unknown lookup, skipped field) decodes to the empty
/// string.
String _ownedString(Pointer<Char> p) =>
    p.address == 0 ? '' : p.cast<Utf8>().toDartString();

/// Read-only registry of every patcher object type the engine knows about.
///
/// The registry is the introspection surface behind the engine's own
/// patcher reference: it enumerates the object types
/// [Patcher.createObject] accepts and, per type, the documentation
/// metadata (description, category, and the inlet / outlet / parameter
/// schema). Use it to build a node palette or generate documentation
/// without hard-coding the catalogue.
///
/// All members are static; there is a single process-wide registry.
///
/// Threading: main-thread only, and **not** real-time safe — never call
/// from the audio callback (CLAUDE.md Boundaries). The engine builds its
/// metadata cache lazily on the first call and keeps it for the life of
/// the process.
class PatcherRegistry {
  PatcherRegistry._();

  /// Number of registered object types.
  static int get typeCount => bindings.patcher_get_type_count();

  /// Type identifier at [index] in the registry (0-based, lexicographic).
  ///
  /// Returns the empty string when [index] is out of range.
  static String typeNameAt(int index) =>
      _ownedString(bindings.patcher_get_type_name(index));

  /// Every registered type identifier, in registry (lexicographic) order.
  static List<String> typeNames() => [
    for (var i = 0; i < typeCount; i++) typeNameAt(i),
  ];

  /// Metadata handle for [typeName], or `null` if the registry has no such
  /// type. Compare against [Obj] constants, e.g. `PatcherRegistry.type(Obj.dSine)`.
  static PatcherObjectType? type(String typeName) {
    for (var i = 0; i < typeCount; i++) {
      if (typeNameAt(i) == typeName) return PatcherObjectType._(typeName);
    }
    return null;
  }

  /// Every registered type as a metadata handle, in registry order.
  static List<PatcherObjectType> types() => [
    for (final n in typeNames()) PatcherObjectType._(n),
  ];

  /// A fresh JSON snapshot of every registered object's full metadata.
  ///
  /// The result is one JSON object keyed by type name; each entry holds
  /// `name`, `category` (e.g. `OSC`, the `YSE_PCAT_` suffix), `is_dsp`,
  /// `requires_midi_device`, `description`, `inlets`, `outlets` and
  /// `params`.
  ///
  /// The engine allocates the buffer per call; this getter releases it
  /// through `yse_free_string` before returning, so no native memory
  /// leaks. Returns the empty string if the engine reports an allocation
  /// failure.
  static String metadataJson() {
    final ptr = bindings.patcher_get_metadata_json();
    if (ptr.address == 0) return '';
    try {
      return ptr.cast<Utf8>().toDartString();
    } finally {
      bindings.free_string(ptr);
    }
  }

  // The registry is fixed for the life of the process, so the decoded
  // metadata is cached on first use.
  static Map<String, Map<String, dynamic>>? _metadataCache;

  static Map<String, Map<String, dynamic>> _metadata() {
    final cached = _metadataCache;
    if (cached != null) return cached;
    final json = metadataJson();
    // An allocation failure is not cached; the next call retries.
    if (json.isEmpty) return const {};
    return _metadataCache = {
      for (final MapEntry(:key, :value)
          in (jsonDecode(json) as Map<String, dynamic>).entries)
        key: value as Map<String, dynamic>,
    };
  }
}

/// Read-only metadata for one registered patcher object type.
///
/// Obtain one from [PatcherRegistry.type] / [PatcherRegistry.types]. Every
/// accessor reads live from the engine registry; the strings returned are
/// copied out of engine-owned storage (never freed by the caller).
class PatcherObjectType {
  /// The type identifier (matches one of the [Obj] constants).
  final String name;

  PatcherObjectType._(this.name);

  /// Short human-readable summary of the object.
  ///
  /// Since libYSE 3.0.1 this is a tooltip-length summary (at most 300
  /// characters, usually one or two sentences), suited to a palette or a
  /// hover; the longer notes live in upstream's object reference.
  String get description => using((arena) {
    final namePtr = name.toNativeUtf8(allocator: arena);
    return _ownedString(bindings.patcher_get_type_description(namePtr.cast()));
  });

  /// Documentation category the object is filed under.
  PCategory get category => using((arena) {
    final namePtr = name.toNativeUtf8(allocator: arena);
    return PCategory.fromNative(
      bindings.patcher_get_type_category(namePtr.cast()),
    );
  });

  /// Whether this is a DSP / audio-rate object (the `~` prefix convention).
  bool get isDsp => using((arena) {
    final namePtr = name.toNativeUtf8(allocator: arena);
    return bindings.patcher_get_type_is_dsp(namePtr.cast()) != 0;
  });

  /// Whether this object holds a MIDI port (`.midiin`, `.midiout`,
  /// `.notein`, ...).
  ///
  /// Such objects exist only in engine builds with MIDI device support
  /// (not macOS / Android), so a palette or a saved patch can mark them
  /// non-portable. Read from the registry's metadata JSON
  /// (`requires_midi_device`); the engine has no dedicated getter.
  bool get requiresMidiDevice =>
      PatcherRegistry._metadata()[name]?['requires_midi_device'] == true;

  /// Number of inlets on this object type.
  int get inletCount => using((arena) {
    final namePtr = name.toNativeUtf8(allocator: arena);
    return bindings.patcher_get_inlet_count(namePtr.cast());
  });

  /// Number of outlets on this object type.
  int get outletCount => using((arena) {
    final namePtr = name.toNativeUtf8(allocator: arena);
    return bindings.patcher_get_outlet_count(namePtr.cast());
  });

  /// Number of creation parameters this object type documents.
  int get paramCount => using((arena) {
    final namePtr = name.toNativeUtf8(allocator: arena);
    return bindings.patcher_get_param_count(namePtr.cast());
  });

  /// Metadata for the inlet at [idx] (0-based).
  PatcherInlet inletAt(int idx) => using((arena) {
    final namePtr = name.toNativeUtf8(allocator: arena);
    final label = arena<Pointer<Char>>();
    final doc = arena<Pointer<Char>>();
    final range = arena<Pointer<Char>>();
    final accepts = arena<UnsignedInt>();
    bindings.patcher_get_inlet_info(
      namePtr.cast(),
      idx,
      label,
      doc,
      range,
      accepts,
    );
    return PatcherInlet._(
      label: _ownedString(label.value),
      doc: _ownedString(doc.value),
      range: _ownedString(range.value),
      accepts: InletAccepts.fromBitmask(accepts.value),
    );
  });

  /// Metadata for every inlet, in order.
  List<PatcherInlet> inlets() => [
    for (var i = 0; i < inletCount; i++) inletAt(i),
  ];

  /// Metadata for the outlet at [idx] (0-based).
  PatcherOutlet outletAt(int idx) => using((arena) {
    final namePtr = name.toNativeUtf8(allocator: arena);
    final label = arena<Pointer<Char>>();
    final doc = arena<Pointer<Char>>();
    final range = arena<Pointer<Char>>();
    final type = arena<UnsignedInt>();
    bindings.patcher_get_outlet_info(
      namePtr.cast(),
      idx,
      label,
      doc,
      range,
      type,
    );
    return PatcherOutlet._(
      label: _ownedString(label.value),
      doc: _ownedString(doc.value),
      range: _ownedString(range.value),
      type: OutType.fromNative(YseOutType.fromValue(type.value)),
    );
  });

  /// Metadata for every outlet, in order.
  List<PatcherOutlet> outlets() => [
    for (var i = 0; i < outletCount; i++) outletAt(i),
  ];

  /// Metadata for the creation parameter at [idx] (0-based).
  PatcherParam paramAt(int idx) => using((arena) {
    final namePtr = name.toNativeUtf8(allocator: arena);
    final pName = arena<Pointer<Char>>();
    final doc = arena<Pointer<Char>>();
    final defaultValue = arena<Pointer<Char>>();
    final range = arena<Pointer<Char>>();
    bindings.patcher_get_param_info(
      namePtr.cast(),
      idx,
      pName,
      doc,
      defaultValue,
      range,
    );
    return PatcherParam._(
      name: _ownedString(pName.value),
      doc: _ownedString(doc.value),
      defaultValue: _ownedString(defaultValue.value),
      range: _ownedString(range.value),
    );
  });

  /// Metadata for every creation parameter, in order.
  List<PatcherParam> params() => [
    for (var i = 0; i < paramCount; i++) paramAt(i),
  ];

  @override
  String toString() => 'PatcherObjectType($name)';
}

/// Documentation for one inlet of a [PatcherObjectType].
class PatcherInlet {
  /// Short inlet label (e.g. `freq`).
  final String label;

  /// Longer human-readable description.
  final String doc;

  /// Documented value range (free-form text, may be empty).
  final String range;

  /// The set of message kinds this inlet accepts.
  final Set<InletAccepts> accepts;

  PatcherInlet._({
    required this.label,
    required this.doc,
    required this.range,
    required this.accepts,
  });

  @override
  String toString() => 'PatcherInlet($label, accepts: $accepts)';
}

/// Documentation for one outlet of a [PatcherObjectType].
class PatcherOutlet {
  /// Short outlet label (e.g. `out`).
  final String label;

  /// Longer human-readable description.
  final String doc;

  /// Documented value range (free-form text, may be empty).
  final String range;

  /// The data type this outlet emits.
  final OutType type;

  PatcherOutlet._({
    required this.label,
    required this.doc,
    required this.range,
    required this.type,
  });

  @override
  String toString() => 'PatcherOutlet($label, type: $type)';
}

/// Documentation for one creation parameter of a [PatcherObjectType].
class PatcherParam {
  /// Parameter name (e.g. `frequency`).
  final String name;

  /// Longer human-readable description.
  final String doc;

  /// Documented default value (free-form text, may be empty).
  final String defaultValue;

  /// Documented value range (free-form text, may be empty).
  final String range;

  PatcherParam._({
    required this.name,
    required this.doc,
    required this.defaultValue,
    required this.range,
  });

  @override
  String toString() => 'PatcherParam($name, default: $defaultValue)';
}
