import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' as pkgffi;

/// Best-effort free-space probe for the §5.1 storage pre-check.
///
/// Dart has no portable free-space API, so this uses POSIX `statvfs`
/// through FFI (Linux/Android/macOS share the LP64 `statvfs` layout used
/// here). Any failure — unsupported platform, missing symbol, non-zero
/// return — yields `null` ("unknown"), never a fabricated number; callers
/// decide how to treat an unknown result.
Future<int?> statvfsFreeSpaceBytes(Directory directory) async {
  if (Platform.isWindows) return null;
  try {
    final libraryName = Platform.isMacOS || Platform.isIOS
        ? 'libSystem.dylib'
        : Platform.isAndroid
            ? 'libc.so'
            : 'libc.so.6';
    final library = ffi.DynamicLibrary.open(libraryName);
    final statvfs =
        library.lookupFunction<_StatVfsNative, _StatVfsDart>('statvfs');
    final pathPointer = directory.absolute.path.toNativeUtf8();
    final buffer = pkgffi.calloc<_StatVfs>();
    try {
      if (statvfs(pathPointer, buffer) != 0) return null;
      final fragmentSize = buffer.ref.fFrsize;
      final availableBlocks = buffer.ref.fBavail;
      if (fragmentSize <= 0 || availableBlocks < 0) return null;
      return fragmentSize * availableBlocks;
    } finally {
      pkgffi.calloc.free(pathPointer);
      pkgffi.calloc.free(buffer);
    }
  } catch (_) {
    return null;
  }
}

final class _StatVfs extends ffi.Struct {
  @ffi.UnsignedLong()
  external int fBsize;
  @ffi.UnsignedLong()
  external int fFrsize;
  @ffi.Uint64()
  external int fBlocks;
  @ffi.Uint64()
  external int fBfree;
  @ffi.Uint64()
  external int fBavail;
  @ffi.Uint64()
  external int fFiles;
  @ffi.Uint64()
  external int fFfree;
  @ffi.Uint64()
  external int fFavail;
  @ffi.UnsignedLong()
  external int fFsid;
  @ffi.UnsignedLong()
  external int fFlag;
  @ffi.UnsignedLong()
  external int fNamemax;
  @ffi.Array.multi([6])
  external ffi.Array<ffi.Int> fSpare;
}

typedef _StatVfsNative = ffi.Int32 Function(
  ffi.Pointer<pkgffi.Utf8> path,
  ffi.Pointer<_StatVfs> buffer,
);
typedef _StatVfsDart = int Function(
  ffi.Pointer<pkgffi.Utf8> path,
  ffi.Pointer<_StatVfs> buffer,
);
