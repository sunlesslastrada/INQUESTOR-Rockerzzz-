// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../../theme/inquestor_theme.dart';

int _viewIdCounter = 0;

/// Web implementation launching a live interactive camera viewfinder dialog.
Future<Uint8List?> openCameraCaptureImpl(BuildContext context) async {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    barrierColor: InquestorColors.graphite.withValues(alpha: 0.65),
    builder: (dialogContext) {
      return const _WebCameraCaptureDialog();
    },
  );
}

class _WebCameraCaptureDialog extends StatefulWidget {
  const _WebCameraCaptureDialog();

  @override
  State<_WebCameraCaptureDialog> createState() => _WebCameraCaptureDialogState();
}

class _WebCameraCaptureDialogState extends State<_WebCameraCaptureDialog> {
  late final String _viewType;
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;

  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewType = 'inquestor-webcam-${_viewIdCounter++}';
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Webcam hardware or MediaDevices API is unavailable in this browser.';
        });
      }
      return;
    }

    try {
      html.MediaStream? stream;

      // First attempt to get the environment (rear) camera if available
      try {
        stream = await mediaDevices.getUserMedia({
          'video': {
            'facingMode': 'environment',
            'width': {'ideal': 1920},
            'height': {'ideal': 1080},
          },
          'audio': false,
        });
      } catch (_) {
        // Fallback to any default video device (e.g. desktop webcam)
        stream = await mediaDevices.getUserMedia({
          'video': true,
          'audio': false,
        });
      }

      _mediaStream = stream;

      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..srcObject = stream;

      // Register view factory
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => _videoElement!,
      );

      // Play video
      await _videoElement!.play();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Camera access was denied or could not be initialized.\nPlease allow camera permissions in your browser or use "Upload Image".';
        });
      }
    }
  }

  void _capturePhoto() {
    if (_videoElement == null || _mediaStream == null) return;

    try {
      final int width = _videoElement!.videoWidth > 0
          ? _videoElement!.videoWidth
          : 1280;
      final int height = _videoElement!.videoHeight > 0
          ? _videoElement!.videoHeight
          : 720;

      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;

      ctx.drawImage(_videoElement!, 0, 0);

      final String dataUrl = canvas.toDataUrl('image/jpeg', 0.92);
      final String base64Data = dataUrl.split(',').last;
      final Uint8List bytes = base64Decode(base64Data);

      _stopStream();
      Navigator.of(context).pop(bytes);
    } catch (_) {
      _stopStream();
      Navigator.of(context).pop(null);
    }
  }

  void _stopStream() {
    if (_mediaStream != null) {
      for (final track in _mediaStream!.getTracks()) {
        track.stop();
      }
      _mediaStream = null;
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: InquestorColors.pureWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: InquestorColors.hairlineBorder,
          width: 1.0,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: InquestorColors.hairlineBorder,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: InquestorColors.antiqueGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LIVE OPTICAL CAMERA FEED',
                        style: TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      _stopStream();
                      Navigator.of(context).pop(null);
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: InquestorColors.softSlate,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Camera Viewport Surface
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141618),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: InquestorColors.hairlineBorder,
                      width: 1.0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video Stream or Initializing / Error state
                      if (_isInitializing)
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: InquestorColors.pureWhite,
                                ),
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Requesting optical camera access...',
                                style: TextStyle(
                                  color: Color(0xFFCCCCCC),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_errorMessage != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.videocam_off_outlined,
                                  size: 32,
                                  color: Color(0xFFE57373),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFDDDDDD),
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        HtmlElementView(viewType: _viewType),

                      // Reticle Corners Overlay
                      if (!_isInitializing && _errorMessage == null)
                        const _CameraReticleOverlay(),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Shutter Controls
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel Button
                  TextButton(
                    onPressed: () {
                      _stopStream();
                      Navigator.of(context).pop(null);
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: InquestorColors.softSlate,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Center Shutter Button
                  ElevatedButton.icon(
                    onPressed: (!_isInitializing && _errorMessage == null)
                        ? _capturePhoto
                        : null,
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text(
                      'TAKE SNAPSHOT',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: InquestorColors.graphite,
                      foregroundColor: InquestorColors.pureWhite,
                      disabledBackgroundColor: InquestorColors.hairlineBorder,
                      disabledForegroundColor: InquestorColors.softSlate,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                  ),

                  // Balance spacing
                  const SizedBox(width: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shutter Trigger Button adhering to "Quiet Authority" precision.
class _ShutterButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;

  const _ShutterButton({
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: InquestorColors.pureWhite,
          border: Border.all(
            color: isEnabled
                ? InquestorColors.graphite
                : InquestorColors.hairlineBorder,
            width: 2.0,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: InquestorColors.graphite.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : const [],
        ),
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEnabled
                ? InquestorColors.graphite
                : InquestorColors.hairlineBorder,
          ),
          child: const Center(
            child: Icon(
              Icons.camera_alt,
              size: 20,
              color: InquestorColors.pureWhite,
            ),
          ),
        ),
      ),
    );
  }
}

/// Corner reticle overlay for the live camera viewfinder.
class _CameraReticleOverlay extends StatelessWidget {
  const _CameraReticleOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                    left: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                    right: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                    left: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                    right: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
