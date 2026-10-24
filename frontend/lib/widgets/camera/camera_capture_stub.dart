import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Native / non-web stub implementation using [ImagePicker].
Future<Uint8List?> openCameraCaptureImpl(BuildContext context) async {
  final picker = ImagePicker();
  final XFile? file = await picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 90,
  );
  if (file == null) return null;
  return await file.readAsBytes();
}
