import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeruta/services/text_lines.dart';

/// Fills a rectangle in a packed RGB888 buffer.
void rect(
  Uint8List img,
  int imgW,
  int x,
  int y,
  int w,
  int h,
  int v,
) {
  for (var yy = y; yy < y + h; yy++) {
    for (var xx = x; xx < x + w; xx++) {
      final p = (yy * imgW + xx) * 3;
      img[p] = v;
      img[p + 1] = v;
      img[p + 2] = v;
    }
  }
}

Uint8List canvas(int w, int h, int fill) =>
    Uint8List(w * h * 3)..fillRange(0, w * h * 3, fill);

/// A rough word: vertical strokes with gaps, so it has line structure.
void word(Uint8List img, int imgW, int x, int y, int letters) {
  for (var i = 0; i < letters; i++) {
    rect(img, imgW, x + i * 8, y, 4, 14, 0);
  }
}

void main() {
  test('finds two lines of dark text on a light background', () {
    final img = canvas(240, 160, 235);
    word(img, 240, 30, 30, 6);
    word(img, 240, 40, 100, 5);

    final lines = findTextLines(img, 240, 160);
    expect(lines.length, 2);
    expect(lines[0].y, lessThan(lines[1].y));
    // Neither crop is the whole frame — that is the whole point.
    expect(lines[0].height, lessThan(60));
    expect(lines[0].width, lessThan(200));
    expect(lines[0].height, greaterThanOrEqualTo(14));
  });

  test('finds light text on dark paint', () {
    final img = canvas(240, 160, 20);
    for (var i = 0; i < 6; i++) {
      rect(img, 240, 30 + i * 8, 40, 4, 14, 240);
    }
    for (var i = 0; i < 5; i++) {
      rect(img, 240, 40 + i * 8, 110, 4, 14, 240);
    }

    final lines = findTextLines(img, 240, 160);
    expect(lines.length, 2);
  });

  test('a blank crop yields nothing, so the caller can fall back', () {
    expect(findTextLines(canvas(120, 80, 240), 120, 80), isEmpty);
    expect(findTextLines(canvas(120, 80, 15), 120, 80), isEmpty);
  });

  test('a line that already fills the crop is left alone', () {
    // Taller than 75% of the height: cropping it further gains nothing, and the
    // caller's whole-ROI path is the better fallback.
    final img = canvas(200, 80, 240);
    rect(img, 200, 20, 4, 160, 72, 0);
    expect(findTextLines(img, 200, 80), isEmpty);
  });

  test('keeps the densest lines when there are too many', () {
    final img = canvas(240, 200, 235);
    word(img, 240, 30, 10, 3);
    word(img, 240, 30, 70, 3);
    word(img, 240, 30, 130, 12); // densest

    final lines = findTextLines(img, 240, 200, maxLines: 2);
    expect(lines.length, 2);
    // Kept lines are returned top-to-bottom, not in density order, so identify
    // the wide one by its width: 12 letters span ~96 px.
    expect(
      lines.any((l) => l.width > 80),
      isTrue,
      reason: 'the 12-letter line must be one of the two kept',
    );
  });

  test('cropRgb copies exactly the requested rectangle', () {
    final img = canvas(10, 10, 0);
    rect(img, 10, 2, 3, 2, 2, 255);

    final out = cropRgb(img, 10, 2, 3, 2, 2);
    expect(out.length, 2 * 2 * 3);
    expect(out.every((v) => v == 255), isTrue);

    final elsewhere = cropRgb(img, 10, 0, 0, 2, 2);
    expect(elsewhere.every((v) => v == 0), isTrue);
  });

  test('rejects buffers that do not match the stated size', () {
    expect(findTextLines(Uint8List(10), 100, 100), isEmpty);
    expect(findTextLines(canvas(4, 4, 0), 4, 4), isEmpty);
  });
}
