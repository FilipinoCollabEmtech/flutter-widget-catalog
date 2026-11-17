import 'dart:typed_data';

import 'package:camera/camera.dart';

/// An upright RGB crop of a camera frame, ready for an OCR model.
class RoiFrame {
  const RoiFrame(this.rgb, this.width, this.height);

  /// Tightly packed RGB888, `width * height * 3` bytes.
  final Uint8List rgb;
  final int width;
  final int height;
}

/// Extracts a centred strip of the frame and rotates it upright.
///
/// The scanner's reticle sits in the middle of the preview, so sampling that
/// same region means what the user frames is what the model reads — no text
/// detector needed. [rotationDegrees] is the clockwise rotation that makes the
/// raw sensor frame upright (the same value handed to ML Kit).
RoiFrame? extractUprightRoi(
  CameraImage image, {
  required int rotationDegrees,
  double widthFraction = 0.86,
  double heightFraction = 0.30,
  int maxWidth = 192,
}) {
  final planes = image.planes;
  if (planes.length < 3) return null;

  final rawW = image.width;
  final rawH = image.height;
  final swap = rotationDegrees == 90 || rotationDegrees == 270;
  final uprightW = swap ? rawH : rawW;
  final uprightH = swap ? rawW : rawH;

  var outW = (uprightW * widthFraction).round();
  var outH = (uprightH * heightFraction).round();
  if (outW <= 0 || outH <= 0) return null;
  if (outW > maxWidth) {
    outH = (outH * maxWidth / outW).round().clamp(1, 4096);
    outW = maxWidth;
  }

  final roiW = uprightW * widthFraction;
  final roiH = uprightH * heightFraction;
  final roiLeft = (uprightW - roiW) / 2;
  final roiTop = (uprightH - roiH) / 2;

  final y = planes[0];
  final u = planes[1];
  final v = planes[2];
  final yStride = y.bytesPerRow;
  final yPix = y.bytesPerPixel ?? 1;
  final uStride = u.bytesPerRow;
  final uPix = u.bytesPerPixel ?? 1;
  final vStride = v.bytesPerRow;
  final vPix = v.bytesPerPixel ?? 1;

  final out = Uint8List(outW * outH * 3);
  var o = 0;
  for (var dy = 0; dy < outH; dy++) {
    final uy = roiTop + (dy + 0.5) * roiH / outH;
    for (var dx = 0; dx < outW; dx++) {
      final ux = roiLeft + (dx + 0.5) * roiW / outW;

      int rx;
      int ry;
      switch (rotationDegrees) {
        case 90:
          rx = uy.toInt();
          ry = rawH - 1 - ux.toInt();
        case 180:
          rx = rawW - 1 - ux.toInt();
          ry = rawH - 1 - uy.toInt();
        case 270:
          rx = rawW - 1 - uy.toInt();
          ry = ux.toInt();
        default:
          rx = ux.toInt();
          ry = uy.toInt();
      }

      if (rx < 0 || ry < 0 || rx >= rawW || ry >= rawH) {
        out[o++] = 0;
        out[o++] = 0;
        out[o++] = 0;
        continue;
      }

      final yi = ry * yStride + rx * yPix;
      final ci = (ry >> 1) * uStride + (rx >> 1) * uPix;
      final vi = (ry >> 1) * vStride + (rx >> 1) * vPix;

      final yv = yi < y.bytes.length ? y.bytes[yi] : 16;
      final uv = ci < u.bytes.length ? u.bytes[ci] : 128;
      final vv = vi < v.bytes.length ? v.bytes[vi] : 128;

      // YUV_420_888 is limited range (16-235); convert to full-range sRGB,
      // which is what the recognition model was trained on.
      final c = (yv - 16).clamp(0, 255).toDouble();
      final d = (uv - 128).toDouble();
      final e = (vv - 128).toDouble();
      final r = (298 * c + 409 * e + 128) / 256;
      final g = (298 * c - 100 * d - 208 * e + 128) / 256;
      final b = (298 * c + 516 * d + 128) / 256;

      out[o++] = r.clamp(0, 255).toInt();
      out[o++] = g.clamp(0, 255).toInt();
      out[o++] = b.clamp(0, 255).toInt();
    }
  }

  return RoiFrame(out, outW, outH);
}
