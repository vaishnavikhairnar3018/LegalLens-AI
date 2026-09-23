/// Web camera permission requester using HTML5 getUserMedia to trigger native browser prompt.
library;

import 'dart:html' as html;

Future<bool> requestWebCameraPermission() async {
  try {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices != null) {
      html.MediaStream? stream;
      try {
        stream = await mediaDevices.getUserMedia({
          'video': {
            'facingMode': {'ideal': 'environment'}
          }
        });
      } catch (_) {
        // Fallback for devices that reject facingMode constraint
        stream = await mediaDevices.getUserMedia({'video': true});
      }
      if (stream != null) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        return true;
      }
    }
  } catch (e) {
    // Permission denied or dismissed
    return false;
  }
  return false;
}
