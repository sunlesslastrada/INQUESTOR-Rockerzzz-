import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../landing_page.dart';
import '../models/audit_models.dart';
import '../services/api_service.dart';
import '../services/audit_service.dart';
import '../theme/inquestor_theme.dart';
import '../widgets/camera/camera_capture.dart';
import '../widgets/inquestor_background.dart';

/// Page 2: Multi-Modal Intake, Human-in-the-Loop Claim Review,
/// Tier-2 Deterministic Gatekeeper, and Tier-3 Authority Stepper.
class AuditStagingPage extends StatefulWidget {
  final AuditService? serviceOverride;

  const AuditStagingPage({
    super.key,
    this.serviceOverride,
  });

  @override
  State<AuditStagingPage> createState() => AuditStagingPageState();
}

class AuditStagingPageState extends State<AuditStagingPage>
    with SingleTickerProviderStateMixin {
  late final AuditService _auditService;
  final ImagePicker _picker = ImagePicker();

  // Tier 0 Received Context
  bool _initializedFromArgs = false;
  String _selectedCategory = InquestCategory.electronics;
  String? _t0Brand;
  bool _t0LogoValid = true;
  String? _t0Reasoning;
  bool _t0Bypassed = false;

  // Global Settings
  bool _mockMode = true; // Default true for smooth Judge/Demo testbench
  String? _activeDemoPresetId;
  String? _backendDemoPreset;

  // Phase A: Image Capture Slots
  Uint8List? _pkgImageBytes;
  String? _pkgImageName;

  Uint8List? _barcodeImageBytes;
  String? _barcodeImageName;

  Uint8List? _qrImageBytes;
  String? _qrImageName;

  bool _isExtracting = false;
  String? _extractErrorMessage;

  // Phase B: Claims Review & Deterministic Results
  bool _claimsExtracted = false;
  ExtractedProductClaims? _claims;

  // Form Controllers for Human-in-the-Loop Review
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _expiryCtrl;
  late final TextEditingController _mfgCtrl;
  late final TextEditingController _qrCtrl;

  // Phase C: Tier 3 Inquest Stepper State
  bool _isInquestRunning = false;
  int _activeStepIndex = 0; // 0 = not started, 1 = Extracted, 2 = Rules, 3 = TinyFish, 4 = Done
  String _stepperStatusMessage = 'Initializing forensic verification pipeline...';
  String? _inquestErrorMessage;

  // 1x1 PNG bytes for fast 1-tap demo preset mocking
  static final Uint8List _mockImageBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  @override
  void initState() {
    super.initState();
    _auditService = widget.serviceOverride ?? AuditService();

    _brandCtrl = TextEditingController();
    _modelCtrl = TextEditingController();
    _barcodeCtrl = TextEditingController();
    _serialCtrl = TextEditingController();
    _expiryCtrl = TextEditingController();
    _mfgCtrl = TextEditingController();
    _qrCtrl = TextEditingController();

    _brandCtrl.addListener(_onFormUpdated);
    _modelCtrl.addListener(_onFormUpdated);
    _barcodeCtrl.addListener(_onFormUpdated);
    _serialCtrl.addListener(_onFormUpdated);
    _expiryCtrl.addListener(_onFormUpdated);
    _mfgCtrl.addListener(_onFormUpdated);
    _qrCtrl.addListener(_onFormUpdated);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromArgs) {
      _initializedFromArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _t0Brand = args['detected_brand'] as String?;
        final cat = args['detected_category'] as String?;
        if (cat != null && cat.toLowerCase().contains('med')) {
          _selectedCategory = InquestCategory.medicine;
        } else {
          _selectedCategory = InquestCategory.electronics;
        }
        _t0LogoValid = args['is_logo_valid'] as bool? ?? true;
        _t0Reasoning = args['reasoning'] as String?;
        _t0Bypassed = args['bypassed'] as bool? ?? false;
      }
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _barcodeCtrl.dispose();
    _serialCtrl.dispose();
    _expiryCtrl.dispose();
    _mfgCtrl.dispose();
    _qrCtrl.dispose();
    if (widget.serviceOverride == null) {
      _auditService.dispose();
    }
    super.dispose();
  }

  void _onFormUpdated() {
    setState(() {
      _claims = (_claims ?? ExtractedProductClaims(category: _selectedCategory)).copyWith(
        category: _selectedCategory,
        brandName: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        modelOrDrugName: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
        barcodeGtin: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        serialOrBatchNumber: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        expiryDate: _expiryCtrl.text.trim().isEmpty ? null : _expiryCtrl.text.trim(),
        mfgDate: _mfgCtrl.text.trim().isEmpty ? null : _mfgCtrl.text.trim(),
        qrRedirectUrl: _qrCtrl.text.trim().isEmpty ? null : _qrCtrl.text.trim(),
        barcodeEmbeddedBatch: _claims?.barcodeEmbeddedBatch,
        barcodeEmbeddedExpiry: _claims?.barcodeEmbeddedExpiry,
      );
    });
  }

  void _applyDemoPreset(DemoPreset preset) {
    setState(() {
      _activeDemoPresetId = preset.id;
      _backendDemoPreset = preset.backendPresetId;
      _selectedCategory = preset.category;
      _mockMode = true; // Auto-activate mock mode for instant reliable demo testing

      // Populate mock image slots so user can extract or view immediately
      _pkgImageBytes = _mockImageBytes;
      _pkgImageName = '${preset.id}_pkg.png';
      _barcodeImageBytes = _mockImageBytes;
      _barcodeImageName = '${preset.id}_barcode.png';
      _qrImageBytes = _mockImageBytes;
      _qrImageName = '${preset.id}_qr.png';

      _extractErrorMessage = null;
      _inquestErrorMessage = null;

      // Load claims directly for instant judge testing
      _claims = preset.claims;
      _claimsExtracted = true;

      _brandCtrl.text = _claims?.brandName ?? '';
      _modelCtrl.text = _claims?.modelOrDrugName ?? '';
      _barcodeCtrl.text = _claims?.barcodeGtin ?? '';
      _serialCtrl.text = _claims?.serialOrBatchNumber ?? '';
      _expiryCtrl.text = _claims?.expiryDate ?? '';
      _mfgCtrl.text = _claims?.mfgDate ?? '';
      _qrCtrl.text = _claims?.qrRedirectUrl ?? '';
    });
  }

  Future<void> _pickImage(int slot, ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final Uint8List? bytes = await openCameraCapture(context);
        if (bytes == null || !mounted) return;

        setState(() {
          final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
          if (slot == 1) {
            _pkgImageBytes = bytes;
            _pkgImageName = 'packaging_camera_' + stamp + '.jpg';
          } else if (slot == 2) {
            _barcodeImageBytes = bytes;
            _barcodeImageName = 'barcode_camera_' + stamp + '.jpg';
          } else if (slot == 3) {
            _qrImageBytes = bytes;
            _qrImageName = 'qr_camera_' + stamp + '.jpg';
          }
          _activeDemoPresetId = null;
          _extractErrorMessage = null;
        });
        return;
      }

      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (slot == 1) {
          _pkgImageBytes = bytes;
          _pkgImageName = file.name;
        } else if (slot == 2) {
          _barcodeImageBytes = bytes;
          _barcodeImageName = file.name;
        } else if (slot == 3) {
          _qrImageBytes = bytes;
          _qrImageName = file.name;
        }
        _activeDemoPresetId = null;
        _extractErrorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to acquire image: $e')),
        );
      }
    }
  }

  void _clearSlot(int slot) {
    setState(() {
      if (slot == 1) {
        _pkgImageBytes = null;
        _pkgImageName = null;
      } else if (slot == 2) {
        _barcodeImageBytes = null;
        _barcodeImageName = null;
      } else if (slot == 3) {
        _qrImageBytes = null;
        _qrImageName = null;
      }
      _activeDemoPresetId = null;
    });
  }

  // --------------------------------------------------------------------------
  // Phase A: Extraction Action
  // --------------------------------------------------------------------------
  Future<void> _extractClaimsAction() async {
    if (_pkgImageBytes == null || _barcodeImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture both Packaging and Barcode images.')),
      );
      return;
    }

    setState(() {
      _isExtracting = true;
      _extractErrorMessage = null;
    });

    try {
      final ExtractedProductClaims extracted = await _auditService.extractClaims(
        category: _selectedCategory,
        packagingBytes: _pkgImageBytes!,
        packagingFilename: _pkgImageName ?? 'packaging.jpg',
        barcodeBytes: _barcodeImageBytes!,
        barcodeFilename: _barcodeImageName ?? 'barcode.jpg',
        qrBytes: _qrImageBytes,
        qrFilename: _qrImageName,
      );

      setState(() {
        _claims = extracted;
        _claimsExtracted = true;
        _isExtracting = false;

        _brandCtrl.text = _claims?.brandName ?? '';
        _modelCtrl.text = _claims?.modelOrDrugName ?? '';
        _barcodeCtrl.text = _claims?.barcodeGtin ?? '';
        _serialCtrl.text = _claims?.serialOrBatchNumber ?? '';
        _expiryCtrl.text = _claims?.expiryDate ?? '';
        _mfgCtrl.text = _claims?.mfgDate ?? '';
        _qrCtrl.text = _claims?.qrRedirectUrl ?? '';
      });
    } catch (e) {
      setState(() {
        _isExtracting = false;
        _extractErrorMessage = e.toString();
      });
    }
  }

  // --------------------------------------------------------------------------
  // Phase C: Inquest Execution Action
  // --------------------------------------------------------------------------
  Future<void> _runInquestAction() async {
    // 1. Synchronize claims from controllers, keeping embedded hidden state
    final currentClaims = (_claims ?? ExtractedProductClaims(category: _selectedCategory)).copyWith(
      category: _selectedCategory,
      brandName: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      modelOrDrugName: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      barcodeGtin: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      serialOrBatchNumber: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
      expiryDate: _expiryCtrl.text.trim().isEmpty ? null : _expiryCtrl.text.trim(),
      mfgDate: _mfgCtrl.text.trim().isEmpty ? null : _mfgCtrl.text.trim(),
      qrRedirectUrl: _qrCtrl.text.trim().isEmpty ? null : _qrCtrl.text.trim(),
      barcodeEmbeddedBatch: _claims?.barcodeEmbeddedBatch,
      barcodeEmbeddedExpiry: _claims?.barcodeEmbeddedExpiry,
    );

    setState(() {
      _claims = currentClaims;
      _isInquestRunning = true;
      _activeStepIndex = 1;
      _stepperStatusMessage = 'Information Extracted from Packaging verified.';
      _inquestErrorMessage = null;
    });

    final bool isLiveRun = !_mockMode && _backendDemoPreset == null;

    // Step 1 -> Step 2
    await Future.delayed(Duration(milliseconds: isLiveRun ? 400 : 350));
    if (!mounted) return;

    setState(() {
      _activeStepIndex = 2;
      _stepperStatusMessage = 'Deterministic Local Gatekeeper Evaluated: GS1 Modulo-10 checksum & serial syntax verified.';
    });

    // Step 2 -> Step 3
    await Future.delayed(Duration(milliseconds: isLiveRun ? 400 : 350));
    if (!mounted) return;

    final String initialT3Message = _selectedCategory == InquestCategory.medicine
        ? 'Auditing batch against CDSCO NSQ Drug Alert Table...'
        : (_claims?.qrRedirectUrl != null && _claims!.qrRedirectUrl!.isNotEmpty
            ? 'Tracing QR Redirect in Cloud Sandbox & querying OEM Registry...'
            : 'Dispatching TinyFish Agent to OEM Warranty Registry...');

    setState(() {
      _activeStepIndex = 3;
      _stepperStatusMessage = initialT3Message;
    });

    Timer? rotatingTimer;
    int tick = 0;

    if (isLiveRun) {
      final List<String> statusRotation = [
        initialT3Message,
        if (_claims?.qrRedirectUrl != null && _claims!.qrRedirectUrl!.isNotEmpty)
          'Tracing QR Redirect in Cloud Sandbox...',
        if (_selectedCategory == InquestCategory.medicine) ...[
          'Checking CDSCO monthly Not of Standard Quality (NSQ) drug alerts...',
          'Cross-referencing manufacturer licensed batch records...',
          'Synthesizing pharmaceutical regulatory findings...',
        ] else ...[
          'Dispatching TinyFish Agent to OEM Warranty Registry...',
          'Querying registered serial number and warranty entitlement records...',
          'Reconciling packaging claimed model against authoritative registry...',
        ],
        'Awaiting authoritative portal DOM response stream...',
        'Cross-examining forensic evidence...',
      ];

      rotatingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (!mounted || !_isInquestRunning) {
          timer.cancel();
          return;
        }
        tick = (tick + 1) % statusRotation.length;
        setState(() {
          _stepperStatusMessage = statusRotation[tick];
        });
      });
    }

    try {
      final request = VerificationRequest(
        claims: currentClaims,
        tier0LogoSummary: {
          'is_logo_valid': _t0LogoValid,
          'detected_brand': _t0Brand ?? currentClaims.brandName ?? 'Unknown',
          'reasoning': _t0Reasoning ?? 'Visual brand audit passed.',
        },
        forceContinue: false,
        mockMode: _mockMode,
        demoPreset: _backendDemoPreset,
      );

      final VerificationResponse response = await _auditService.verifyProduct(request);

      rotatingTimer?.cancel();
      if (!mounted) return;

      setState(() {
        _activeStepIndex = 4;
        _stepperStatusMessage = 'Forensic investigation complete. Synthesizing verdict...';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // Navigate to /report passing verification payload
      Navigator.of(context).pushNamed(
        '/report',
        arguments: {
          'verification_response': response.toJson(),
          'claims': currentClaims.toJson(),
          'tier0_summary': {
            'is_logo_valid': _t0LogoValid,
            'detected_brand': _t0Brand,
            'reasoning': _t0Reasoning,
          },
          'raw_evidence': response.rawEvidence,
        },
      );
    } catch (e) {
      rotatingTimer?.cancel();
      if (!mounted) return;

      setState(() {
        _isInquestRunning = false;
        _inquestErrorMessage = e.toString();
      });
    } finally {
      rotatingTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InquestorBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6).withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: InquestorColors.hairlineBorder,
                width: 1.0,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InquestorBrandHeader(
                  onTap: () => Navigator.of(context).pushReplacementNamed('/'),
                ),
                Row(
                  children: [
                    // Mock / Live Mode Toggle Pill
                    InkWell(
                      onTap: () {
                        setState(() {
                          _mockMode = !_mockMode;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _mockMode
                                  ? 'Demo Mock Mode ENABLED (Instant fixtures)'
                                  : 'Live Network Mode ENABLED (Connecting to ${_auditService.baseUrl})',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _mockMode
                              ? InquestorColors.antiqueGold.withValues(alpha: 0.12)
                              : InquestorColors.pureWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _mockMode
                                ? InquestorColors.antiqueGold
                                : InquestorColors.hairlineBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _mockMode ? Icons.bolt : Icons.wifi,
                              size: 13,
                              color: _mockMode ? InquestorColors.antiqueGold : InquestorColors.softSlate,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _mockMode ? 'MOCK ON' : 'LIVE API',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: _mockMode ? InquestorColors.antiqueGold : InquestorColors.graphite,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 14,
                        color: InquestorColors.graphite,
                      ),
                      label: const Text(
                        'Tier 0',
                        style: TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderBreadcrumb(),
                const SizedBox(height: 18),

                // Top Controls & Category Selector
                _buildCategorySelectorCard(),
                const SizedBox(height: 16),

                // 5 Demo Presets Bar
                _buildDemoPresetsBar(),
                const SizedBox(height: 20),

                // If Stepper is actively running
                if (_isInquestRunning) ...[
                  _buildAnimatedStepperCard(),
                  const SizedBox(height: 24),
                ] else if (!_claimsExtracted) ...[
                  // Phase A: Capture Viewfinders
                  _buildCaptureViewfindersCard(),
                ] else ...[
                  // Phase B: Claims Review & Tier 2 Display
                  _buildClaimsReviewCard(),
                  const SizedBox(height: 18),
                  _buildTier2ResultsCard(),
                  const SizedBox(height: 24),
                  _buildInquestActionButton(),
                ],

                // In-line error message container (if extraction or inquest fails)
                if (_extractErrorMessage != null || _inquestErrorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorContainer(_extractErrorMessage ?? _inquestErrorMessage!),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Header Breadcrumb
  // --------------------------------------------------------------------------
  Widget _buildHeaderBreadcrumb() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _t0LogoValid
                ? InquestorColors.forestGreen.withValues(alpha: 0.1)
                : InquestorColors.coralRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            _t0LogoValid ? 'TIER 0 VERIFIED' : (_t0Bypassed ? 'TIER 0 BYPASSED' : 'TIER 0 FLAG'),
            style: TextStyle(
              color: _t0LogoValid ? InquestorColors.forestGreen : InquestorColors.coralRed,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, size: 14, color: InquestorColors.softSlate),
        const SizedBox(width: 8),
        Text(
          'STAGE 2: INTAKE & FORENSIC GATEKEEPER',
          style: TextStyle(
            color: InquestorColors.graphite.withValues(alpha: 0.9),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Category Selector Card
  // --------------------------------------------------------------------------
  Widget _buildCategorySelectorCard() {
    final bool isElec = _selectedCategory == InquestCategory.electronics;
    final bool isMed = _selectedCategory == InquestCategory.medicine;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: InquestorColors.hairlineBorder, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRODUCT DOMAIN',
                style: TextStyle(
                  color: InquestorColors.softSlate,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _t0Brand != null ? 'Pre-filled from Tier 0 ($_t0Brand)' : 'Select Target Category',
                style: const TextStyle(
                  color: InquestorColors.graphite,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildCategoryChip(
                label: '🎧 Electronics',
                isSelected: isElec,
                onTap: () {
                  setState(() {
                    _selectedCategory = InquestCategory.electronics;
                    if (_claims != null) {
                      _claims = _claims!.copyWith(category: InquestCategory.electronics);
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildCategoryChip(
                label: '💊 Medicine',
                isSelected: isMed,
                onTap: () {
                  setState(() {
                    _selectedCategory = InquestCategory.medicine;
                    if (_claims != null) {
                      _claims = _claims!.copyWith(category: InquestCategory.medicine);
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? InquestorColors.graphite : InquestorColors.porcelain,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? InquestorColors.graphite : InquestorColors.hairlineBorder,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? InquestorColors.pureWhite : InquestorColors.graphite,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 5 Demo Presets Bar
  // --------------------------------------------------------------------------
  Widget _buildDemoPresetsBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  '1-TAP JUDGE DEMO PRESETS',
                  style: TextStyle(
                    color: InquestorColors.softSlate,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _mockMode
                        ? InquestorColors.antiqueGold.withValues(alpha: 0.12)
                        : InquestorColors.softSlate.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _mockMode ? '⚡ MOCK ACTIVE' : '🌐 LIVE MODE',
                    style: TextStyle(
                      color: _mockMode ? InquestorColors.antiqueGold : InquestorColors.softSlate,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            if (_activeDemoPresetId != null)
              InkWell(
                onTap: () {
                  setState(() {
                    _activeDemoPresetId = null;
                    _backendDemoPreset = null;
                    _claimsExtracted = false;
                    _claims = null;
                    _pkgImageBytes = null;
                    _barcodeImageBytes = null;
                    _qrImageBytes = null;
                  });
                },
                child: const Text(
                  'Reset Intake',
                  style: TextStyle(
                    color: InquestorColors.coralRed,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: DemoPreset.allPresets.map((preset) {
              final isSelected = _activeDemoPresetId == preset.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _applyDemoPreset(preset),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? InquestorColors.graphite
                          : InquestorColors.pureWhite,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? InquestorColors.graphite
                            : InquestorColors.hairlineBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(preset.emoji, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          preset.label,
                          style: TextStyle(
                            color: isSelected
                                ? InquestorColors.pureWhite
                                : InquestorColors.graphite,
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Phase A: Capture Viewfinders Card
  // --------------------------------------------------------------------------
  Widget _buildCaptureViewfindersCard() {
    final int requiredCount = (_pkgImageBytes != null ? 1 : 0) + (_barcodeImageBytes != null ? 1 : 0);
    final bool canExtract = requiredCount == 2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: InquestorColors.hairlineBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TIER 1: MULTI-MODAL EVIDENCE INTAKE',
                style: TextStyle(
                  color: InquestorColors.graphiteSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                requiredCount == 2
                    ? 'Ready for Extraction'
                    : '${2 - requiredCount} of 2 Required Slots Pending',
                style: TextStyle(
                  color: canExtract ? InquestorColors.forestGreen : InquestorColors.softSlate,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slot 1: Packaging Text
          _buildCaptureSlot(
            slot: 1,
            title: 'Slot 1: Packaging Text Label / Foil',
            subtitle: 'Model / Drug name, serial/batch, expiry & mfg dates',
            isRequired: true,
            bytes: _pkgImageBytes,
            filename: _pkgImageName,
          ),
          const SizedBox(height: 12),

          // Slot 2: Barcode / DataMatrix
          _buildCaptureSlot(
            slot: 2,
            title: 'Slot 2: Barcode / GS1 DataMatrix',
            subtitle: '1D GTIN barcode or 2D GS1 DataMatrix crop',
            isRequired: true,
            bytes: _barcodeImageBytes,
            filename: _barcodeImageName,
          ),
          const SizedBox(height: 12),

          // Slot 3: Optional QR Code
          _buildCaptureSlot(
            slot: 3,
            title: 'Slot 3: QR Verification Link',
            subtitle: 'Anti-counterfeiting QR code or warranty portal URL',
            isRequired: false,
            bytes: _qrImageBytes,
            filename: _qrImageName,
          ),
          const SizedBox(height: 20),

          // Extract Claims CTA
          ElevatedButton(
            onPressed: canExtract && !_isExtracting ? _extractClaimsAction : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: InquestorColors.graphite,
              foregroundColor: InquestorColors.pureWhite,
              disabledBackgroundColor: InquestorColors.hairlineBorder,
              disabledForegroundColor: InquestorColors.softSlate,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: _isExtracting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: InquestorColors.graphite,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Extracting barcode & packaging OCR...',
                        style: TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'EXTRACT CLAIMS →',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureSlot({
    required int slot,
    required String title,
    required String subtitle,
    required bool isRequired,
    required Uint8List? bytes,
    required String? filename,
  }) {
    final bool hasImage = bytes != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InquestorColors.porcelain,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasImage ? InquestorColors.forestGreen : InquestorColors.hairlineBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Thumbnail / Placeholder
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: InquestorColors.pureWhite,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: InquestorColors.hairlineBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_outlined,
                      size: 20,
                      color: InquestorColors.forestGreen,
                    ),
                  )
                : Icon(
                    slot == 1
                        ? Icons.description_outlined
                        : (slot == 2 ? Icons.qr_code_2_outlined : Icons.qr_code_scanner),
                    size: 20,
                    color: InquestorColors.softSlate,
                  ),
          ),
          const SizedBox(width: 12),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: InquestorColors.graphite,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isRequired
                            ? (hasImage
                                ? InquestorColors.forestGreen.withValues(alpha: 0.1)
                                : InquestorColors.graphite.withValues(alpha: 0.08))
                            : InquestorColors.softSlate.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        hasImage ? 'LOADED' : (isRequired ? 'REQUIRED' : 'OPTIONAL'),
                        style: TextStyle(
                          color: hasImage
                              ? InquestorColors.forestGreen
                              : (isRequired ? InquestorColors.graphite : InquestorColors.softSlate),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasImage ? (filename ?? 'Captured crop') : subtitle,
                  style: const TextStyle(
                    color: InquestorColors.softSlate,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Actions
          if (hasImage) ...[
            IconButton(
              onPressed: () => _clearSlot(slot),
              icon: const Icon(Icons.close, size: 16, color: InquestorColors.softSlate),
              tooltip: 'Remove',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _pickImage(slot, ImageSource.camera),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: InquestorColors.graphite,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera, size: 12, color: InquestorColors.pureWhite),
                        SizedBox(width: 4),
                        Text(
                          'Take Photo',
                          style: TextStyle(
                            color: InquestorColors.pureWhite,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _pickImage(slot, ImageSource.gallery),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: InquestorColors.pureWhite,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: InquestorColors.hairlineBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_upload_outlined, size: 12, color: InquestorColors.graphite),
                        SizedBox(width: 4),
                        Text(
                          'Upload',
                          style: TextStyle(
                            color: InquestorColors.graphite,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Phase B: Human-in-the-Loop Claim Review Form
  // --------------------------------------------------------------------------
  Widget _buildClaimsReviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: InquestorColors.hairlineBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note_outlined, size: 18, color: InquestorColors.graphite),
                  SizedBox(width: 8),
                  Text(
                    'HUMAN-IN-THE-LOOP CLAIM STAGING',
                    style: TextStyle(
                      color: InquestorColors.graphiteSubtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _claimsExtracted = false;
                  });
                },
                child: const Text(
                  'Change Crops',
                  style: TextStyle(
                    color: InquestorColors.softSlate,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Review and edit OCR claims before running deterministic rules & web agents.',
            style: TextStyle(color: InquestorColors.softSlate, fontSize: 11.5),
          ),
          const SizedBox(height: 16),

          // Field Rows
          _buildTextFormField('Brand Name', _brandCtrl, hint: 'e.g., Sony, Apple, Cipla'),
          const SizedBox(height: 10),
          _buildTextFormField('Model / Drug Name', _modelCtrl, hint: 'e.g., WH-1000XM5, Dolo-650'),
          const SizedBox(height: 10),
          _buildTextFormField('Barcode / GTIN', _barcodeCtrl, hint: 'e.g., 0027242923508'),
          const SizedBox(height: 10),
          _buildTextFormField('Serial / Batch Number', _serialCtrl, hint: 'e.g., 5281902, GT20491'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTextFormField('Expiry Date', _expiryCtrl, hint: 'YYYY-MM or YYYY-MM-DD'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField('Mfg Date', _mfgCtrl, hint: 'YYYY-MM or YYYY-MM-DD'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextFormField('QR Verification URL', _qrCtrl, hint: 'e.g., https://sony.com/verify'),
        ],
      ),
    );
  }

  Widget _buildTextFormField(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: InquestorColors.softSlate,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(
            color: InquestorColors.graphite,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0B4B8), fontSize: 12),
            filled: true,
            fillColor: InquestorColors.porcelain,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: InquestorColors.hairlineBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: InquestorColors.hairlineBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: InquestorColors.graphite, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Phase B: Immediate Tier 2 Deterministic Results Display
  // --------------------------------------------------------------------------
  Widget _buildTier2ResultsCard() {
    if (_claims == null) return const SizedBox.shrink();

    // Client-side instant evaluation
    final items = LocalDeterministicEvaluator.evaluate(_claims!);
    final int passedCount = items.where((i) => i.passed).length;
    final bool allPassed = passedCount == items.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: InquestorColors.hairlineBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: InquestorColors.graphite.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIER 2: DETERMINISTIC FAST-FAIL CHECKS',
                    style: TextStyle(
                      color: InquestorColors.graphite,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Sub-5ms Mathematical & Physical Cross-Validation',
                    style: TextStyle(
                      color: InquestorColors.softSlate,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: allPassed
                      ? InquestorColors.forestGreen.withValues(alpha: 0.1)
                      : InquestorColors.coralRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: allPassed
                        ? InquestorColors.forestGreen.withValues(alpha: 0.3)
                        : InquestorColors.coralRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  allPassed
                      ? '✓ $passedCount/${items.length} CHECKS VERIFIED'
                      : '⚠ ${items.length - passedCount} DISCREPANCY DETECTED',
                  style: TextStyle(
                    color: allPassed ? InquestorColors.forestGreen : InquestorColors.coralRed,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...items.map((item) => _buildDeterministicRow(item)),
        ],
      ),
    );
  }

  Widget _buildDeterministicRow(AuditCheckItem item) {
    final lowerDetails = item.details.toLowerCase();
    final bool isSkipped = lowerDetails.contains('skipped') ||
        lowerDetails.contains('not applicable') ||
        lowerDetails.contains('no qr') ||
        lowerDetails.contains('no barcode') ||
        lowerDetails.contains('no serial');

    final Color badgeBg;
    final Color badgeFg;
    final String badgeText;
    final IconData badgeIcon;

    if (!item.passed) {
      badgeBg = InquestorColors.coralRed;
      badgeFg = InquestorColors.pureWhite;
      badgeText = 'FAILED';
      badgeIcon = Icons.cancel;
    } else if (isSkipped) {
      badgeBg = const Color(0xFFE8E8E4);
      badgeFg = InquestorColors.softSlate;
      badgeText = 'SKIPPED';
      badgeIcon = Icons.remove_circle_outline;
    } else {
      badgeBg = InquestorColors.forestGreen;
      badgeFg = InquestorColors.pureWhite;
      badgeText = 'PASSED';
      badgeIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.passed ? const Color(0xFFEFEFEA) : InquestorColors.coralRed.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: InquestorColors.porcelain,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: InquestorColors.hairlineBorder),
                      ),
                      child: const Text(
                        'TIER 2',
                        style: TextStyle(
                          color: InquestorColors.softSlate,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Prominent Status Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeFg),
                    const SizedBox(width: 4.5),
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeFg,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: InquestorColors.pureWhite,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFE8E8E4)),
            ),
            child: Text(
              item.details,
              style: TextStyle(
                color: item.passed ? InquestorColors.graphiteSubtle : InquestorColors.coralRed,
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Phase B / C Action Button
  // --------------------------------------------------------------------------
  Widget _buildInquestActionButton() {
    return ElevatedButton(
      onPressed: !_isInquestRunning ? _runInquestAction : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: InquestorColors.graphite,
        foregroundColor: InquestorColors.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: InquestorColors.antiqueGold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            '🔍 RUN FORENSIC INQUEST',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Phase C: Animated Execution Stepper Card
  // --------------------------------------------------------------------------
  Widget _buildAnimatedStepperCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: InquestorColors.graphite, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: InquestorColors.graphite.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: InquestorColors.graphite,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'TIER 3: LIVE FORENSIC AGENT INVESTIGATION',
                  style: TextStyle(
                    color: InquestorColors.graphite,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              if (_mockMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: InquestorColors.antiqueGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'MOCK ACTIVE',
                    style: TextStyle(
                      color: InquestorColors.antiqueGold,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Stepper Items
          _buildStepRow(
            stepNumber: 1,
            title: 'Information Extracted from Packaging',
            isDone: _activeStepIndex > 1,
            isActive: _activeStepIndex == 1,
          ),
          _buildStepConnector(isDone: _activeStepIndex > 1),
          _buildStepRow(
            stepNumber: 2,
            title: 'Deterministic Local Gatekeeper Evaluated',
            isDone: _activeStepIndex > 2,
            isActive: _activeStepIndex == 2,
          ),
          _buildStepConnector(isDone: _activeStepIndex > 2),
          _buildStepRow(
            stepNumber: 3,
            title: 'Tier-3 Authority Cross-Examination Active',
            subtitle: _selectedCategory == InquestCategory.medicine
                ? 'Auditing batch against CDSCO NSQ Drug Alert Table...'
                : (_claims?.qrRedirectUrl != null && _claims!.qrRedirectUrl!.isNotEmpty
                    ? 'Dispatching TinyFish Agent to OEM Registry & Tracing QR Sandbox...'
                    : 'Dispatching TinyFish Agent to OEM Warranty Registry...'),
            isDone: _activeStepIndex > 3,
            isActive: _activeStepIndex == 3,
            isLightning: true,
          ),
          const SizedBox(height: 16),

          // Dynamic Status Message Ticker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: InquestorColors.porcelain,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: InquestorColors.hairlineBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.hub_outlined, size: 14, color: InquestorColors.softSlate),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _stepperStatusMessage,
                    style: const TextStyle(
                      color: InquestorColors.graphite,
                      fontSize: 11.5,
                      height: 1.4,
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

  Widget _buildStepRow({
    required int stepNumber,
    required String title,
    String? subtitle,
    required bool isDone,
    required bool isActive,
    bool isLightning = false,
  }) {
    final Color badgeColor = isDone
        ? InquestorColors.forestGreen
        : (isActive ? InquestorColors.graphite : InquestorColors.softSlate);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: isDone ? InquestorColors.forestGreen : InquestorColors.pureWhite,
            shape: BoxShape.circle,
            border: Border.all(color: badgeColor, width: 1.5),
          ),
          alignment: Alignment.center,
          child: isDone
              ? const Icon(Icons.check, size: 12, color: InquestorColors.pureWhite)
              : (isActive
                  ? Text(
                      isLightning ? '\u26A1' : '$stepNumber',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    )
                  : Text(
                      '$stepNumber',
                      style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold),
                    )),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDone
                      ? InquestorColors.graphite
                      : (isActive ? InquestorColors.graphite : InquestorColors.softSlate),
                  fontSize: 12,
                  fontWeight: isActive || isDone ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (subtitle != null && isActive) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: InquestorColors.softSlate,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector({required bool isDone}) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.5),
      child: Container(
        width: 1.5,
        height: 14,
        color: isDone ? InquestorColors.forestGreen : InquestorColors.hairlineBorder,
      ),
    );
  }

  Widget _buildErrorContainer(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: InquestorColors.coralRed, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 16, color: InquestorColors.coralRed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMMUNICATION ERROR',
                      style: TextStyle(
                        color: InquestorColors.coralRed,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(color: InquestorColors.graphite, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_mockMode) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _mockMode = true;
                      _inquestErrorMessage = null;
                    });
                    _runInquestAction();
                  },
                  icon: const Icon(Icons.bolt, size: 14, color: InquestorColors.antiqueGold),
                  label: const Text(
                    'SWITCH TO MOCK MODE & RUN',
                    style: TextStyle(
                      color: InquestorColors.antiqueGold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: InquestorColors.antiqueGold),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
