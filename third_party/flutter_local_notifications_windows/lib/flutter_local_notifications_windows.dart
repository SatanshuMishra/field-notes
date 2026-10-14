export 'src/details.dart';
export 'src/msix/stub.dart' if (dart.library.ffi) 'src/msix/ffi.dart';
export 'src/plugin/ffi.dart'
    if (dart.library.js_interop) 'src/plugin/stub.dart';
