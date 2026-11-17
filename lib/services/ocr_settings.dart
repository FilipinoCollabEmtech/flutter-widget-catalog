import 'package:flutter/foundation.dart';

/// Which OCR backend the scanner uses.
///
/// Switched from Admin → "OCR engine" so a docTR model can be A/B tested
/// against ML Kit on real signs without rebuilding the app.
enum OcrEngine {
  mlkit('ML Kit · text v2'),
  doctr('docTR · ViPTR-tiny');

  const OcrEngine(this.label);

  /// Shown in the scanner badge and in the admin toggle.
  final String label;
}

class OcrSettings {
  OcrSettings._();

  /// Global because the scanner is opened from two places (home tab and admin
  /// tab) and the toggle lives in admin only.
  static final ValueNotifier<OcrEngine> engine =
      ValueNotifier<OcrEngine>(OcrEngine.mlkit);

  static bool get useDoctr => engine.value == OcrEngine.doctr;
}
