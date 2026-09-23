/// Cross-platform camera permission requester.
library;

export 'camera_permission_stub.dart'
    if (dart.library.html) 'camera_permission_web.dart';
