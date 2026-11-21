import 'dart:math' as math;
import 'dart:typed_data';

/// A horizontal band of ink inside a crop, in crop coordinates.
class TextLine {
  const TextLine({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.ink,
  });

  final int x;
  final int y;
  final int width;
  final int height;

  /// Ink pixels in the band — used to prefer the densest lines when a crop has
  /// more of them than the frame budget allows.
  final int ink;

  @override
  String toString() => 'TextLine($x,$y $width×$height ink=$ink)';
}

/// Finds the text lines inside a crop so the recognizer can be fed each one
/// separately.
///
/// This exists because a recognizer sees whatever rectangle it is handed and
/// rescales it to a fixed line height. Hand it the whole reticle and the real
/// characters are a few pixels tall — the model then outputs confident
/// nonsense. Cropping to the ink bands gives every line the full model height,
/// which is the difference between "reads only when the text fills the box"
/// and "reads".
///
/// Contrast is measured against a *large-window* local mean rather than a global
/// threshold, so a shadow across one side of the sign does not swallow half the
/// letters, and an inverted (light text on dark paint) crop works too.
List<TextLine> findTextLines(
  Uint8List rgb,
  int width,
  int height, {
  int maxLines = 3,
}) {
  if (width < 8 || height < 8 || rgb.length < width * height * 3) {
    return const [];
  }

  // ---- grayscale -------------------------------------------------------
  final gray = Uint8List(width * height);
  for (var i = 0, p = 0; i < gray.length; i++, p += 3) {
    gray[i] = ((rgb[p] * 299 + rgb[p + 1] * 587 + rgb[p + 2] * 114) / 1000)
        .round()
        .clamp(0, 255);
  }

  // Otsu on the raw image only decides which side is ink: whichever class is
  // the minority is the text. Dark letters on a light sign is the common case;
  // light lettering on painted panel is the other.
  final cut = _otsu(gray);
  var dark = 0;
  for (final v in gray) {
    if (v <= cut) dark++;
  }
  final inkIsDark = dark <= gray.length - dark;

  // ---- large-window background ----------------------------------------
  final integral = Float64List((width + 1) * (height + 1));
  for (var y = 0; y < height; y++) {
    var rowSum = 0;
    for (var x = 0; x < width; x++) {
      rowSum += gray[y * width + x];
      integral[(y + 1) * (width + 1) + (x + 1)] =
          integral[y * (width + 1) + (x + 1)] + rowSum;
    }
  }

  final win = math.max(15, math.min(width, height) ~/ 3) | 1;
  final half = win ~/ 2;

  // Signed contrast: positive means "this pixel looks like ink".
  final contrast = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    final y0 = math.max(0, y - half);
    final y1 = math.min(height - 1, y + half);
    for (var x = 0; x < width; x++) {
      final x0 = math.max(0, x - half);
      final x1 = math.min(width - 1, x + half);
      final a = integral[y0 * (width + 1) + x0];
      final b = integral[y0 * (width + 1) + (x1 + 1)];
      final c = integral[(y1 + 1) * (width + 1) + x0];
      final d = integral[(y1 + 1) * (width + 1) + (x1 + 1)];
      final area = (x1 - x0 + 1) * (y1 - y0 + 1);
      final bg = (d - b - c + a) / area;
      final v = gray[y * width + x];
      final diff = inkIsDark ? bg - v : v - bg;
      contrast[y * width + x] = diff.clamp(0, 255).round();
    }
  }

  // Otsu on the contrast maps, floored so a blank crop stays blank.
  final cut2 = math.max(_otsu(contrast), 8);
  final mask = Uint8List(width * height);
  for (var i = 0; i < mask.length; i++) {
    if (contrast[i] > cut2) mask[i] = 1;
  }

  // ---- row bands (with a 1-row vertical fill) --------------------------
  final rowInk = List<int>.filled(height, 0);
  for (var y = 0; y < height; y++) {
    var n = 0;
    final base = y * width;
    final above = y > 0 ? (y - 1) * width : base;
    final below = y < height - 1 ? (y + 1) * width : base;
    for (var x = 0; x < width; x++) {
      if (mask[base + x] == 1 ||
          mask[above + x] == 1 ||
          mask[below + x] == 1) {
        n++;
      }
    }
    rowInk[y] = n;
  }

  final rowThr = math.max(2, (width * 0.015).round());
  final bands = <List<int>>[];
  List<int>? open;
  var gap = 0;
  for (var y = 0; y < height; y++) {
    if (rowInk[y] >= rowThr) {
      if (open == null) {
        open = [y, y];
      } else {
        open[1] = y;
        gap = 0;
      }
    } else if (open != null) {
      // Bridge a one- or two-row dip: "i" dots and accents create it.
      gap++;
      if (gap > 2) {
        bands.add(open);
        open = null;
        gap = 0;
      }
    }
  }
  if (open != null) bands.add(open);

  // ---- tighten horizontally and score ----------------------------------
  final lines = <TextLine>[];
  for (final band in bands) {
    final top = band[0];
    final bottom = band[1];
    final h = bottom - top + 1;
    if (h < 6) continue;
    if (h > height * 0.75) continue; // one big blob, not a line

    var left = width;
    var right = -1;
    var ink = 0;
    for (var y = top; y <= bottom; y++) {
      final base = y * width;
      for (var x = 0; x < width; x++) {
        if (mask[base + x] == 0) continue;
        ink++;
        if (x < left) left = x;
        if (x > right) right = x;
      }
    }
    if (right < 0 || ink < 20) continue;

    final w = right - left + 1;
    if (w < 6) continue;
    // A line of text is wider than it is tall; a square blob is a smudge.
    if (w / h < 0.4) continue;

    final padX = math.max(2, (w * 0.04).round());
    final padY = math.max(2, (h * 0.15).round());
    final x = math.max(0, left - padX);
    final y = math.max(0, top - padY);
    final x2 = math.min(width, right + padX + 1);
    final y2 = math.min(height, bottom + padY + 1);
    lines.add(TextLine(
      x: x,
      y: y,
      width: x2 - x,
      height: y2 - y,
      ink: ink,
    ));
  }

  if (lines.isEmpty) return const [];
  lines.sort((a, b) => b.ink.compareTo(a.ink));
  return lines.take(maxLines).toList()..sort((a, b) => a.y.compareTo(b.y));
}

/// Copies a rectangle out of a tightly packed RGB888 buffer.
Uint8List cropRgb(
  Uint8List src,
  int srcWidth,
  int x,
  int y,
  int width,
  int height,
) {
  final out = Uint8List(width * height * 3);
  final srcStride = srcWidth * 3;
  final dstStride = width * 3;
  for (var row = 0; row < height; row++) {
    final s = (y + row) * srcStride + x * 3;
    final d = row * dstStride;
    out.setRange(d, d + dstStride, src, s);
  }
  return out;
}

/// Otsu's threshold for an 8-bit image.
int _otsu(List<int> values) {
  if (values.isEmpty) return 128;
  final hist = List<int>.filled(256, 0);
  for (final v in values) {
    hist[v.clamp(0, 255)]++;
  }
  final total = values.length;
  var sumAll = 0.0;
  for (var t = 0; t < 256; t++) {
    sumAll += t * hist[t];
  }

  var sumB = 0.0;
  var wB = 0;
  var best = -1.0;
  var threshold = 128;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB;
    final mF = (sumAll - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) {
      best = between;
      threshold = t;
    }
  }
  return threshold;
}
