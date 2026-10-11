import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';
import 'library.dart';

/// Feeds sound files into the engine from in-memory byte buffers.
///
/// Register raw bytes under string IDs, then load sounds by passing
/// those IDs where a file path would normally go
/// ([Sound.fromFile] with the ID as the filename). Typical use is
/// bundling audio assets inside a game-engine resource pack or an
/// Android APK where the regular file system isn't accessible.
///
/// **Important**: by default ([storeCopy] = false) the engine retains
/// a pointer to the caller's bytes; the Dart wrapper allocates a
/// permanent native copy when you [addAsset] so the GC-managed
/// [Uint8List] you pass in doesn't have to outlive the registration.
/// If you want zero-copy behaviour, call the C ABI directly.
class BufferIO implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.buffer_io_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseBufferIO> _handle;
  final List<Pointer<Char>> _ownedBuffers = [];

  BufferIO._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Construct a BufferIO layer.
  ///
  /// [storeCopy] tells the *engine* whether to copy when it adds a
  /// buffer. The Dart wrapper always allocates a permanent native
  /// copy of the bytes in [addAsset], so the engine's storeCopy flag
  /// is mostly cosmetic — leave at false unless you know why you'd
  /// want both layers copying.
  factory BufferIO({bool storeCopy = false}) {
    final b = bindings;
    final h = b.buffer_io_create(storeCopy ? 1 : 0);
    if (h.address == 0) {
      throw YseException('yse_buffer_io_create returned null');
    }
    return BufferIO._(b, h);
  }

  /// Whether this layer is currently servicing sound-load requests.
  bool get active => _b.buffer_io_get_active(_handle) != 0;
  set active(bool value) => _b.buffer_io_set_active(_handle, value ? 1 : 0);

  /// Whether an asset is registered under [id].
  bool exists(String id) => using((arena) {
    final cstr = id.toNativeUtf8(allocator: arena);
    return _b.buffer_io_name_exists(_handle, cstr.cast()) != 0;
  });

  /// Register [bytes] under [id]. Sounds can then be created by passing
  /// [id] where a filename would normally go.
  ///
  /// The wrapper allocates a permanent native copy of [bytes] and
  /// retains it until [removeAsset] is called or this BufferIO is
  /// disposed — the [bytes] argument may be a transient buffer.
  bool addAsset(String id, Uint8List bytes) {
    final native = calloc.allocate<Char>(bytes.length);
    final byteView = native.cast<Uint8>().asTypedList(bytes.length);
    byteView.setAll(0, bytes);
    final added = using((arena) {
      final idPtr = id.toNativeUtf8(allocator: arena);
      return _b.buffer_io_add(_handle, idPtr.cast(), native, bytes.length) != 0;
    });
    if (added) {
      _ownedBuffers.add(native);
    } else {
      calloc.free(native);
    }
    return added;
  }

  /// Unregister the asset at [id]. Returns true if it was registered.
  bool removeAsset(String id) => using((arena) {
    final cstr = id.toNativeUtf8(allocator: arena);
    return _b.buffer_io_remove_by_name(_handle, cstr.cast()) != 0;
  });

  // Intentionally NOT wrapped (#68): `yse_buffer_io_exists` /
  // `yse_buffer_io_remove` (libYSE #909, `BufferIO::BufferExists` /
  // `RemoveBuffer`) look a registration up by the *address* the host passed
  // to `yse_buffer_io_add`, not by its ID.
  //
  //  * A Dart caller never holds that address. [addAsset] copies the bytes
  //    into a native block it allocates itself (a `Uint8List`'s storage can
  //    move under the GC, so it can't be registered directly), and that
  //    pointer never leaves this class.
  //  * With `storeCopy = true` the engine registers its own copy instead, so
  //    the host address never matches and both calls always return 0.
  //  * Exposing an `id -> pointer` lookup to drive them would only re-spell
  //    what [exists] and [removeAsset] already do by ID.
  //
  // Revisit only if a zero-copy `addAsset` that registers caller-owned
  // native memory is ever added; then the caller would hold the address.

  /// Destroy the underlying native layer, detach the finalizer, and
  /// free every wrapper-owned asset buffer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.buffer_io_destroy(_handle);
    for (final ptr in _ownedBuffers) {
      calloc.free(ptr);
    }
    _ownedBuffers.clear();
    _handle = nullptr;
  }
}
