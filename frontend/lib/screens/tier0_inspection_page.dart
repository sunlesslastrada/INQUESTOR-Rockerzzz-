import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../landing_page.dart';
import '../models/tier0_models.dart';
import '../services/tier0_service.dart';
import '../widgets/camera/camera_capture.dart';

/// Tier 0 Intake & Visual Anomaly Inspection Page.
/// Connects to the live FastAPI backend via multipart HTTP uploads,
/// provides real-time state machine feedback, handles error states gracefully,
/// and includes interactive demo presets.
class Tier0InspectionPage extends StatefulWidget {
  final Tier0Service? serviceOverride;

  const Tier0InspectionPage({super.key, this.serviceOverride});

  @override
  State<Tier0InspectionPage> createState() => Tier0InspectionPageState();
}

class Tier0InspectionPageState extends State<Tier0InspectionPage> {
  final ImagePicker _picker = ImagePicker();
  late final Tier0Service _service;

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isAnalyzing = false;
  String? _errorMessage;
  Tier0Response? _inspectionResult;

  Timer? _autoTransitionTimer;
  Timer? _progressTicker;
  double _transitionProgress = 0.0;

  @visibleForTesting
  Future<void> triggerInspectionForTesting(Uint8List bytes, String filename) async {
    _cancelTimers();
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName = filename;
      _isAnalyzing = true;
      _errorMessage = null;
      _inspectionResult = null;
    });

    try {
      final result = await _service.inspectImage(
        imageBytes: bytes,
        filename: filename,
      );
      if (!mounted) return;
      _handleInspectionResult(result);
    } catch (e) {
      if (mounted) {
        _cancelTimers();
        setState(() {
          _isAnalyzing = false;
          _errorMessage = e.toString();
          _inspectionResult = null;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _service = widget.serviceOverride ?? Tier0Service();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    _autoTransitionTimer?.cancel();
    _progressTicker?.cancel();
    _autoTransitionTimer = null;
    _progressTicker = null;
  }

  // --------------------------------------------------------------------------
  // Reactive State Machine Transitions
  // --------------------------------------------------------------------------

  void _handleInspectionResult(Tier0Response result) {
    _cancelTimers();

    setState(() {
      _isAnalyzing = false;
      _errorMessage = null;
      _inspectionResult = result;
      _transitionProgress = 0.0;
    });
  }

  void _navigateToPage2(Tier0Response response, {required bool isBypassed}) {
    _cancelTimers();
    Navigator.of(context).pushNamed(
      '/page2',
      arguments: {
        'detected_brand': response.detectedBrand,
        'detected_category': response.detectedCategory,
        'is_logo_valid': response.isLogoValid,
        'bypassed': isBypassed,
      },
    );
  }

  void _resetIntake() {
    _cancelTimers();
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _isAnalyzing = false;
      _errorMessage = null;
      _inspectionResult = null;
      _transitionProgress = 0.0;
    });
  }

  // --------------------------------------------------------------------------
  // Image Capture & Upload Handlers (Real HTTP Integration)
  // --------------------------------------------------------------------------

  Future<void> _takePhoto() async {
    if (_isAnalyzing) return;
    _cancelTimers();

    try {
      final Uint8List? bytes = await openCameraCapture(context);
      if (bytes == null || !mounted) return;

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = 'optical_capture.jpg';
        _isAnalyzing = true;
        _errorMessage = null;
        _inspectionResult = null;
      });

      final result = await _service.inspectImage(
        imageBytes: bytes,
        filename: 'optical_capture.jpg',
      );

      if (!mounted) return;
      _handleInspectionResult(result);
    } catch (e) {
      if (mounted) {
        _cancelTimers();
        setState(() {
          _isAnalyzing = false;
          _errorMessage = e.toString();
          _inspectionResult = null;
        });
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_isAnalyzing) return;
    _cancelTimers();

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
        _isAnalyzing = true;
        _errorMessage = null;
        _inspectionResult = null;
      });

      final result = await _service.inspectImage(
        imageBytes: bytes,
        filename: file.name,
      );

      if (!mounted) return;
      _handleInspectionResult(result);
    } catch (e) {
      if (mounted) {
        _cancelTimers();
        setState(() {
          _isAnalyzing = false;
          _errorMessage = e.toString();
          _inspectionResult = null;
        });
      }
    }
  }

  Future<void> _retryInspection() async {
    if (_selectedImageBytes == null || _selectedImageName == null || _isAnalyzing) return;
    _cancelTimers();

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _inspectionResult = null;
    });

    try {
      final result = await _service.inspectImage(
        imageBytes: _selectedImageBytes!,
        filename: _selectedImageName!,
      );

      if (!mounted) return;
      _handleInspectionResult(result);
    } catch (e) {
      if (mounted) {
        _cancelTimers();
        setState(() {
          _isAnalyzing = false;
          _errorMessage = e.toString();
          _inspectionResult = null;
        });
      }
    }
  }

  // --------------------------------------------------------------------------
  // Demo Preset Simulators
  // --------------------------------------------------------------------------

  void _loadPreset(Tier0Response preset) {
    if (_isAnalyzing) return;
    _cancelTimers();

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _inspectionResult = null;
      _selectedImageBytes = null;
      _selectedImageName = 'demo_sample.png';
      _transitionProgress = 0.0;
    });

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      _handleInspectionResult(preset);
    });
  }

  // --------------------------------------------------------------------------
  // Main UI Tree
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InquestorColors.porcelain,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            _buildTopAppBar(context),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. One-tap Demo Presets Bar
                          _buildPresetChipsBar(),

                          const SizedBox(height: 18),

                          // 2. Viewfinder & Image Capture Surface
                          _buildViewfinder(),

                          const SizedBox(height: 18),

                          // 3. Conditional State Machine Output Card
                          if (_isAnalyzing)
                            _buildAnalyzingCard()
                          else if (_errorMessage != null)
                            _buildErrorCard(_errorMessage!)
                          else if (_inspectionResult != null)
                            _buildStateCard(_inspectionResult!),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Sticky Bottom CTAs (when result is present or state machine requires action)
            if (_inspectionResult != null && !_isAnalyzing)
              _buildStickyBottomBar(_inspectionResult!),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Top App Bar
  // --------------------------------------------------------------------------

  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: InquestorColors.porcelain,
        border: Border(
          bottom: BorderSide(
            color: InquestorColors.hairlineBorder,
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InquestorBrandHeader(
              onTap: () {
                _cancelTimers();
                Navigator.of(context).pushReplacementNamed('/');
              },
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _cancelTimers();
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 13,
                    color: InquestorColors.graphite,
                  ),
                  label: const Text(
                    'Landing Page',
                    style: TextStyle(
                      color: InquestorColors.graphite,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: InquestorColors.hairlineBorder,
                      width: 1.0,
                    ),
                    backgroundColor: InquestorColors.pureWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: InquestorColors.pureWhite,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: InquestorColors.hairlineBorder,
                      width: 1.0,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TIER 0',
                        style: TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(width: 5),
                      Text(
                        '· Intake',
                        style: TextStyle(
                          color: InquestorColors.softSlate,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Preset Chips Bar
  // --------------------------------------------------------------------------

  Widget _buildPresetChipsBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'DEMO PRESET TESTBENCH',
              style: TextStyle(
                color: InquestorColors.softSlate,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            OutlinedButton.icon(
              onPressed: (_selectedImageBytes != null ||
                      _inspectionResult != null ||
                      _errorMessage != null) &&
                      !_isAnalyzing
                  ? _resetIntake
                  : null,
              icon: const Icon(
                Icons.restart_alt_rounded,
                size: 14,
              ),
              label: const Text('Reset Scanner'),
              style: OutlinedButton.styleFrom(
                foregroundColor: InquestorColors.graphite,
                disabledForegroundColor: InquestorColors.softSlate.withValues(alpha: 0.4),
                backgroundColor: (_selectedImageBytes != null ||
                        _inspectionResult != null ||
                        _errorMessage != null)
                    ? InquestorColors.pureWhite
                    : InquestorColors.porcelain,
                side: BorderSide(
                  color: (_selectedImageBytes != null ||
                          _inspectionResult != null ||
                          _errorMessage != null)
                      ? InquestorColors.graphite
                      : InquestorColors.hairlineBorder,
                  width: 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPresetChip(
              label: '✓ HP Laptop (Authentic)',
              color: InquestorColors.forestGreen,
              onTap: () => _loadPreset(Tier0Response.presetAuthentic),
            ),
            _buildPresetChip(
              label: '✗ "Abibas" (Spoofed Logo)',
              color: InquestorColors.coralRed,
              onTap: () => _loadPreset(Tier0Response.presetCounterfeit),
            ),
            _buildPresetChip(
              label: '⊘ Nike Sneaker (Out of Scope)',
              color: InquestorColors.amber,
              onTap: () => _loadPreset(Tier0Response.presetOutOfScope),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isAnalyzing ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: InquestorColors.pureWhite,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: InquestorColors.hairlineBorder,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: _isAnalyzing
                    ? InquestorColors.softSlate
                    : InquestorColors.graphite,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Viewfinder & Image Capture Component
  // --------------------------------------------------------------------------

  Widget _buildViewfinder() {
    return Container(
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: InquestorColors.hairlineBorder,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Viewfinder Surface
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Background / Image Preview
                  if (_selectedImageBytes != null)
                    Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: InquestorColors.porcelain,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 32,
                            color: InquestorColors.softSlate,
                          ),
                        );
                      },
                    )
                  else if (_selectedImageName != null)
                    Container(
                      color: InquestorColors.porcelain,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const InquestorBrandMark(height: 38),
                            const SizedBox(height: 10),
                            Text(
                              _selectedImageName!,
                              style: const TextStyle(
                                color: InquestorColors.softSlate,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFFF9F9F8),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: InquestorColors.porcelain,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: InquestorColors.hairlineBorder,
                                  width: 1.0,
                                ),
                              ),
                              child: const Icon(
                                Icons.crop_free,
                                size: 22,
                                color: InquestorColors.softSlate,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Visual Anomaly Viewfinder',
                              style: TextStyle(
                                color: InquestorColors.graphite,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Center product emblem or trademark logo',
                              style: TextStyle(
                                color: InquestorColors.softSlate,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. Forensic Viewfinder Corner Reticles
                  const _ViewfinderReticleOverlay(),

                  // 3. Analyzing Scanning Overlay
                  if (_isAnalyzing)
                    Container(
                      color: InquestorColors.graphite.withValues(alpha: 0.08),
                    ),
                ],
              ),
            ),

            // Dual Action Triggers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: InquestorColors.hairlineBorder,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isAnalyzing ? null : _takePhoto,
                      icon: const Icon(Icons.photo_camera_outlined, size: 16),
                      label: const Text('Take Photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: InquestorColors.graphite,
                        disabledForegroundColor:
                            InquestorColors.softSlate.withValues(alpha: 0.4),
                        side: const BorderSide(
                          color: InquestorColors.hairlineBorder,
                          width: 1.0,
                        ),
                        backgroundColor: InquestorColors.porcelain,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isAnalyzing ? null : _uploadImage,
                      icon: const Icon(Icons.file_upload_outlined, size: 16),
                      label: const Text('Upload Image'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: InquestorColors.graphite,
                        disabledForegroundColor:
                            InquestorColors.softSlate.withValues(alpha: 0.4),
                        side: const BorderSide(
                          color: InquestorColors.hairlineBorder,
                          width: 1.0,
                        ),
                        backgroundColor: InquestorColors.porcelain,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Analyzing State Card
  // --------------------------------------------------------------------------

  Widget _buildAnalyzingCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: InquestorColors.hairlineBorder,
          width: 1.0,
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: InquestorColors.graphite,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Analyzing logo geometry, typography, and category scope...',
              style: TextStyle(
                color: InquestorColors.softSlate,
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // In-Place Error Card
  // --------------------------------------------------------------------------

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: InquestorColors.coralRed,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: InquestorColors.coralRed.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: InquestorColors.coralRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  size: 16,
                  color: InquestorColors.coralRed,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'BACKEND INSPECTION FAILED',
                  style: TextStyle(
                    color: InquestorColors.coralRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            error,
            style: const TextStyle(
              color: InquestorColors.graphite,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Target: ${_service.baseUrl}/api/v1/tier0/inspect',
            style: const TextStyle(
              color: InquestorColors.softSlate,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_selectedImageBytes != null) ...[
                ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _retryInspection,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('RETRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InquestorColors.graphite,
                    foregroundColor: InquestorColors.pureWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              OutlinedButton(
                onPressed: _resetIntake,
                style: OutlinedButton.styleFrom(
                  foregroundColor: InquestorColors.graphite,
                  side: const BorderSide(
                    color: InquestorColors.hairlineBorder,
                    width: 1.0,
                  ),
                  backgroundColor: InquestorColors.pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('DISMISS / RESET'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // State Machine Cards (State A, B, C)
  // --------------------------------------------------------------------------

  Widget _buildStateCard(Tier0Response response) {
    if (response.isLogoValid && response.canProceed) {
      return _buildStateACard(response);
    } else if (!response.isLogoValid && response.canProceed) {
      return _buildStateBCard(response);
    } else {
      return _buildStateCCard(response);
    }
  }

  /// State A: Verified Authentic
  Widget _buildStateACard(Tier0Response response) {
    final confidencePct = (response.confidence * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: InquestorColors.forestGreen,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: InquestorColors.forestGreen.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: InquestorColors.forestGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: InquestorColors.forestGreen,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'VERIFIED · ${response.detectedBrand.toUpperCase()}',
                          style: const TextStyle(
                            color: InquestorColors.forestGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$confidencePct% Confidence',
                style: const TextStyle(
                  color: InquestorColors.softSlate,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Trademark Geometry Validated',
            style: TextStyle(
              color: InquestorColors.graphite,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            response.reasoning,
            style: const TextStyle(
              color: InquestorColors.softSlate,
              fontSize: 13,
              height: 1.55,
            ),
          ),

          const SizedBox(height: 18),

          // Status Guidance Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: InquestorColors.porcelain,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: InquestorColors.hairlineBorder,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: InquestorColors.forestGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Visual inspection cleared. Review findings above and click below to proceed to packaging OCR and deterministic rules.',
                    style: TextStyle(
                      color: InquestorColors.graphite.withValues(alpha: 0.9),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// State B: Counterfeit / Visual Anomaly Detected
  Widget _buildStateBCard(Tier0Response response) {
    final confidencePct = (response.confidence * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: InquestorColors.coralRed,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: InquestorColors.coralRed.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: InquestorColors.coralRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: InquestorColors.coralRed,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'TIER 0: COUNTERFEIT ANOMALY DETECTED',
                          style: TextStyle(
                            color: InquestorColors.coralRed,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$confidencePct% Confidence',
                style: const TextStyle(
                  color: InquestorColors.softSlate,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            response.detectedBrand,
            style: const TextStyle(
              color: InquestorColors.graphite,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Target Scope: ${response.detectedCategory.toUpperCase()}',
            style: const TextStyle(
              color: InquestorColors.softSlate,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // Bulleted anomalies list
          if (response.anomaliesDetected.isNotEmpty) ...[
            const Text(
              'FORENSIC ANOMALY BREAKDOWN',
              style: TextStyle(
                color: InquestorColors.softSlate,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: response.anomaliesDetected.map((anomaly) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: InquestorColors.coralRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          anomaly,
                          style: const TextStyle(
                            color: InquestorColors.graphite,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Reasoning paragraph
          const Text(
            'FORENSIC REASONING',
            style: TextStyle(
              color: InquestorColors.softSlate,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            response.reasoning,
            style: const TextStyle(
              color: InquestorColors.softSlate,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  /// State C: Category Out of Scope Caution
  Widget _buildStateCCard(Tier0Response response) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: InquestorColors.amber,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: InquestorColors.amber.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: InquestorColors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block_outlined,
                        size: 14,
                        color: InquestorColors.amber,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'CATEGORY OUT OF SCOPE',
                          style: TextStyle(
                            color: InquestorColors.amber,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Category: ${response.detectedCategory}',
                style: const TextStyle(
                  color: InquestorColors.softSlate,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'Detected Brand: ${response.detectedBrand}',
            style: const TextStyle(
              color: InquestorColors.graphite,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            response.reasoning,
            style: const TextStyle(
              color: InquestorColors.softSlate,
              fontSize: 13,
              height: 1.55,
            ),
          ),

          if (response.anomaliesDetected.isNotEmpty) ...[
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: response.anomaliesDetected.map((anomaly) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, right: 8),
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: InquestorColors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          anomaly,
                          style: const TextStyle(
                            color: InquestorColors.softSlate,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Sticky Bottom Bar CTAs
  // --------------------------------------------------------------------------

  Widget _buildStickyBottomBar(Tier0Response response) {
    final bool isStateA = response.isLogoValid && response.canProceed;
    final bool isStateB = !response.isLogoValid && response.canProceed;
    final bool isStateC = !response.canProceed;

    return Container(
      decoration: const BoxDecoration(
        color: InquestorColors.pureWhite,
        border: Border(
          top: BorderSide(
            color: InquestorColors.hairlineBorder,
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isStateB) ...[
              // Requirement 2: Counterfeit / Anomaly Detected
              // Primary (Solid Graphite #292C2F): "MANUAL BYPASS & PROCEED →"
              ElevatedButton(
                onPressed: () => _navigateToPage2(response, isBypassed: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: InquestorColors.graphite,
                  foregroundColor: InquestorColors.pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text(
                  'MANUAL BYPASS & PROCEED →',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Secondary (Outline #E5E5E2): "RETAKE / UPLOAD NEW IMAGE"
              OutlinedButton(
                onPressed: _resetIntake,
                style: OutlinedButton.styleFrom(
                  foregroundColor: InquestorColors.graphite,
                  side: const BorderSide(
                    color: InquestorColors.hairlineBorder,
                    width: 1.0,
                  ),
                  backgroundColor: InquestorColors.pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text(
                  'RETAKE / UPLOAD NEW IMAGE',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else if (isStateC) ...[
              // Requirement 3: Out of Scope / Unsupported Item
              // Primary (Solid Graphite): "EXIT / RETURN HOME"
              ElevatedButton(
                onPressed: () {
                  _cancelTimers();
                  Navigator.of(context).pushReplacementNamed('/');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: InquestorColors.graphite,
                  foregroundColor: InquestorColors.pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text(
                  'EXIT / RETURN HOME',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Secondary (Outline): "SCAN DIFFERENT PRODUCT"
              OutlinedButton(
                onPressed: _resetIntake,
                style: OutlinedButton.styleFrom(
                  foregroundColor: InquestorColors.graphite,
                  side: const BorderSide(
                    color: InquestorColors.hairlineBorder,
                    width: 1.0,
                  ),
                  backgroundColor: InquestorColors.pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text(
                  'SCAN DIFFERENT PRODUCT',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else if (isStateA) ...[
              // Requirement 1: Authentic Result
              ElevatedButton(
                onPressed: () => _navigateToPage2(response, isBypassed: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: InquestorColors.graphite,
                  foregroundColor: InquestorColors.pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text(
                  'PROCEED TO NEXT STAGE →',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _resetIntake,
                style: OutlinedButton.styleFrom(
                  foregroundColor: InquestorColors.graphite,
                  side: const BorderSide(
                    color: InquestorColors.hairlineBorder,
                    width: 1.0,
                  ),
                  backgroundColor: InquestorColors.pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text(
                  'RETAKE / SCAN ANOTHER',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Forensic Viewfinder Reticle Overlay
// ----------------------------------------------------------------------------

class _ViewfinderReticleOverlay extends StatelessWidget {
  const _ViewfinderReticleOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            // Top-Left Corner
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: InquestorColors.graphite, width: 2.0),
                    left: BorderSide(color: InquestorColors.graphite, width: 2.0),
                  ),
                ),
              ),
            ),
            // Top-Right Corner
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: InquestorColors.graphite, width: 2.0),
                    right: BorderSide(color: InquestorColors.graphite, width: 2.0),
                  ),
                ),
              ),
            ),
            // Bottom-Left Corner
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: InquestorColors.graphite, width: 2.0),
                    left: BorderSide(color: InquestorColors.graphite, width: 2.0),
                  ),
                ),
              ),
            ),
            // Bottom-Right Corner
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: InquestorColors.graphite, width: 2.0),
                    right: BorderSide(color: InquestorColors.graphite, width: 2.0),
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
