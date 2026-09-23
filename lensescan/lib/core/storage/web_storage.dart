/// Cross-platform storage fallback.
library;

export 'web_storage_stub.dart'
    if (dart.library.html) 'web_storage_web.dart';
