import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'camera_capture_stub.dart'
    if (dart.library.html) 'camera_capture_web.dart' as impl;

/// Opens an interactive camera capture session.
/// On Flutter Web: Opens a live in-browser webcam viewfinder modal with a shutter trigger.
/// On Mobile/Native: Launches native OS camera capture.
Future<Uint8List?> openCameraCapture(BuildContext context) {
  return impl.openCameraCaptureImpl(context);
}
