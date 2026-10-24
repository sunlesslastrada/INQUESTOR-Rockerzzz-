/// Strongly-typed data model representing the backend's Tier 0 Inspection response.
class Tier0Response {
  final bool isLogoValid;
  final String detectedBrand;
  final String detectedCategory;
  final double confidence;
  final List<String> anomaliesDetected;
  final String reasoning;
  final bool canProceed;

  const Tier0Response({
    required this.isLogoValid,
    required this.detectedBrand,
    required this.detectedCategory,
    required this.confidence,
    required this.anomaliesDetected,
    required this.reasoning,
    required this.canProceed,
  });

  factory Tier0Response.fromJson(Map<String, dynamic> json) {
    return Tier0Response(
      isLogoValid: json['is_logo_valid'] as bool? ?? false,
      detectedBrand: json['detected_brand'] as String? ?? 'Unknown',
      detectedCategory: json['detected_category'] as String? ?? 'unsupported',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      anomaliesDetected: (json['anomalies_detected'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      reasoning: json['reasoning'] as String? ?? '',
      canProceed: json['can_proceed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_logo_valid': isLogoValid,
      'detected_brand': detectedBrand,
      'detected_category': detectedCategory,
      'confidence': confidence,
      'anomalies_detected': anomaliesDetected,
      'reasoning': reasoning,
      'can_proceed': canProceed,
    };
  }

  /// Preset 1: Authentic HP Laptop
  static const Tier0Response presetAuthentic = Tier0Response(
    isLogoValid: true,
    detectedBrand: 'HP',
    detectedCategory: 'electronics',
    confidence: 0.98,
    anomaliesDetected: [],
    reasoning:
        'The emblem displays the stylized four-slash premium HP logo utilized on their high-end laptops, showing correct geometric proportions, clean lines, and proper placement.',
    canProceed: true,
  );

  /// Preset 2: Counterfeit "Abibas" Spoof
  static const Tier0Response presetCounterfeit = Tier0Response(
    isLogoValid: false,
    detectedBrand: 'Abibas (Spoof of Adidas)',
    detectedCategory: 'electronics_accessories',
    confidence: 0.94,
    anomaliesDetected: [
      "Trademark typography misspelling ('Abibas' instead of 'Adidas')",
      'Trefoil leaf kerning distortion: 14% angular offset on middle petal',
      'Uneven stroke width variance exceeding OEM tolerance by 1.8mm',
    ],
    reasoning:
        'Emblem displays phonetic spoofing and kerning anomalies. The stroke vectors and character baseline deviate severely from authentic brand vector geometry.',
    canProceed: true,
  );

  /// Preset 3: Out of Scope Nike Sneaker
  static const Tier0Response presetOutOfScope = Tier0Response(
    isLogoValid: false,
    detectedBrand: 'Nike',
    detectedCategory: 'footwear',
    confidence: 0.96,
    anomaliesDetected: [
      "Detected category 'footwear' is outside Inquestor operational domain",
      'Engine scope strictly limited to Consumer Electronics and Pharmaceuticals',
    ],
    reasoning:
        "The detected product falls into the 'footwear' category. Inquestor's forensic verification models are calibrated exclusively for regulated pharmaceuticals and consumer electronics supply chains.",
    canProceed: false,
  );
}

/// Backwards compatibility alias
typedef Tier0InspectionResponse = Tier0Response;
