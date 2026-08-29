import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/location.dart';

/// Generates the parallax layer images for a biome at runtime.
///
/// The game ships no bitmaps: every layer is recorded into a [ui.Picture] and
/// rasterised once per location, then cached. Layers are authored at a fixed
/// size and tile horizontally, which is what lets Flame's [ParallaxLayer]
/// scroll them forever.
const int layerWidth = 512;
const int layerHeight = 256;

/// The five scroll layers of a location, back to front.
class BiomeArt {
  BiomeArt({
    required this.sky,
    required this.far,
    required this.mid,
    required this.near,
    required this.ground,
  });

  final ui.Image sky;
  final ui.Image far;
  final ui.Image mid;
  final ui.Image near;
  final ui.Image ground;

  void dispose() {
    sky.dispose();
    far.dispose();
    mid.dispose();
    near.dispose();
    ground.dispose();
  }
}

final Map<String, BiomeArt> _cache = {};

/// Returns cached art for [locationId], generating it on first use.
Future<BiomeArt> biomeArtFor(String locationId, BiomePalette palette) async {
  final cached = _cache[locationId];
  if (cached != null) return cached;

  // A stable seed keeps a location's skyline identical between visits.
  final seed = locationId.hashCode;
  final art = BiomeArt(
    sky: await _record((c) => _paintSky(c, palette, Random(seed))),
    far: await _record((c) => _paintFar(c, palette, Random(seed + 1))),
    mid: await _record((c) => _paintMid(c, palette, Random(seed + 2))),
    near: await _record((c) => _paintNear(c, palette, Random(seed + 3))),
    ground: await _record((c) => _paintGround(c, palette, Random(seed + 4))),
  );
  _cache[locationId] = art;
  return art;
}

Future<ui.Image> _record(void Function(Canvas canvas) draw) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    const Rect.fromLTWH(0, 0, layerWidth * 1.0, layerHeight * 1.0),
  );
  draw(canvas);
  return recorder.endRecording().toImage(layerWidth, layerHeight);
}

// ---------------------------------------------------------------------- sky

void _paintSky(Canvas canvas, BiomePalette palette, Random rng) {
  const rect = Rect.fromLTWH(0, 0, layerWidth * 1.0, layerHeight * 1.0);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
        palette.skyTop,
        palette.skyBottom,
      ]),
  );

  final night =
      palette.mood == BiomeMood.night || palette.mood == BiomeMood.underground;
  final ash = palette.mood == BiomeMood.ash;

  if (ash) {
    _drawOrb(
      canvas,
      Offset(layerWidth * 0.78, layerHeight * 0.22),
      22,
      const Color(0xFFFF8A50),
    );
    final smoke = Paint()
      ..color = const Color(0xFF3E2723).withValues(alpha: 0.18);
    for (var i = 0; i < 8; i++) {
      final y = 16 + rng.nextDouble() * layerHeight * 0.45;
      final w = 80 + rng.nextDouble() * 160;
      final x = rng.nextDouble() * layerWidth;
      _tiled(canvas, x, w, (dx) {
        canvas.drawOval(Rect.fromLTWH(dx, y, w, 18), smoke);
      });
    }
    final ember = Paint();
    for (var i = 0; i < 70; i++) {
      final x = rng.nextDouble() * layerWidth;
      final y = rng.nextDouble() * layerHeight * 0.72;
      ember.color = Color.lerp(
        const Color(0xFFFF6D00),
        const Color(0xFFFFD54F),
        rng.nextDouble(),
      )!.withValues(alpha: 0.25 + rng.nextDouble() * 0.65);
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 1.6 + 0.4, ember);
    }
  } else if (night) {
    final star = Paint()..color = Colors.white;
    for (var i = 0; i < 90; i++) {
      final x = rng.nextDouble() * layerWidth;
      final y = rng.nextDouble() * layerHeight * 0.62;
      star.color = Colors.white.withValues(
        alpha: 0.15 + rng.nextDouble() * 0.65,
      );
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 1.3 + 0.4, star);
    }
    if (palette.mood == BiomeMood.night) {
      _drawOrb(
        canvas,
        const Offset(layerWidth * 0.76, layerHeight * 0.2),
        18,
        const Color(0xFFE8EAF6),
      );
    }
  } else {
    _drawOrb(
      canvas,
      Offset(layerWidth * 0.72, layerHeight * (night ? 0.2 : 0.24)),
      palette.mood == BiomeMood.dusk ? 26 : 20,
      palette.mood == BiomeMood.dusk
          ? const Color(0xFFFFB74D)
          : const Color(0xFFFFF9C4),
    );
    // Soft cloud bands.
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (var i = 0; i < 6; i++) {
      final y = 20 + rng.nextDouble() * layerHeight * 0.4;
      final w = 60 + rng.nextDouble() * 140;
      final x = rng.nextDouble() * layerWidth;
      _tiled(canvas, x, w, (dx) {
        canvas.drawOval(Rect.fromLTWH(dx, y, w, 14), cloud);
      });
    }
  }
}

void _drawOrb(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawCircle(
    center,
    radius * 2.6,
    Paint()
      ..shader = ui.Gradient.radial(center, radius * 2.6, [
        color.withValues(alpha: 0.35),
        color.withValues(alpha: 0.0),
      ]),
  );
  canvas.drawCircle(center, radius, Paint()..color = color);
}

// ----------------------------------------------------------- distant ridges

void _paintFar(Canvas canvas, BiomePalette palette, Random rng) {
  canvas.drawPath(
    _ridgePath(
      rng,
      minY: layerHeight * 0.34,
      maxY: layerHeight * 0.58,
      steps: 9,
    ),
    Paint()..color = palette.far,
  );
  canvas.drawPath(
    _ridgePath(
      rng,
      minY: layerHeight * 0.48,
      maxY: layerHeight * 0.68,
      steps: 13,
    ),
    Paint()
      ..color = Color.alphaBlend(
        Colors.black.withValues(alpha: 0.18),
        palette.far,
      ),
  );
}

/// A closed silhouette whose first and last vertex share a Y, so it tiles.
Path _ridgePath(
  Random rng, {
  required double minY,
  required double maxY,
  required int steps,
}) {
  final path = Path();
  final dx = layerWidth / steps;
  final firstY = minY + rng.nextDouble() * (maxY - minY);
  path.moveTo(0, firstY);
  for (var i = 1; i < steps; i++) {
    final y = minY + rng.nextDouble() * (maxY - minY);
    path.lineTo(i * dx, y);
  }
  path.lineTo(layerWidth * 1.0, firstY);
  path.lineTo(layerWidth * 1.0, layerHeight * 1.0);
  path.lineTo(0, layerHeight * 1.0);
  path.close();
  return path;
}

// -------------------------------------------------------------- mid details

void _paintMid(Canvas canvas, BiomePalette palette, Random rng) {
  final paint = Paint()..color = palette.mid;
  final baseY = layerHeight * 0.86;

  switch (palette.mood) {
    case BiomeMood.day:
    case BiomeMood.dusk:
      for (var i = 0; i < 16; i++) {
        final x = rng.nextDouble() * layerWidth;
        final h = 50 + rng.nextDouble() * 60;
        _tiled(canvas, x, h, (dx) => _conifer(canvas, dx, baseY, h, paint));
      }
    case BiomeMood.ash:
      for (var i = 0; i < 14; i++) {
        final x = rng.nextDouble() * layerWidth;
        final h = 55 + rng.nextDouble() * 70;
        _tiled(
          canvas,
          x,
          h * 0.35,
          (dx) => _burntTree(canvas, dx, baseY, h, paint),
        );
      }
    case BiomeMood.night:
      for (var i = 0; i < 12; i++) {
        final x = rng.nextDouble() * layerWidth;
        final w = 14 + rng.nextDouble() * 12;
        final h = 45 + rng.nextDouble() * 70;
        _tiled(canvas, x, w, (dx) {
          canvas.drawRect(Rect.fromLTWH(dx, baseY - h, w, h), paint);
          canvas.drawRect(
            Rect.fromLTWH(dx - 3, baseY - h - 5, w + 6, 6),
            paint,
          );
        });
      }
    case BiomeMood.underground:
      for (var i = 0; i < 18; i++) {
        final x = rng.nextDouble() * layerWidth;
        final w = 12 + rng.nextDouble() * 18;
        final h = 40 + rng.nextDouble() * 60;
        final fromTop = rng.nextBool();
        _tiled(canvas, x, w, (dx) {
          final path = Path();
          if (fromTop) {
            path.moveTo(dx, 0);
            path.lineTo(dx + w, 0);
            path.lineTo(dx + w / 2, h);
          } else {
            path.moveTo(dx, baseY);
            path.lineTo(dx + w, baseY);
            path.lineTo(dx + w / 2, baseY - h);
          }
          path.close();
          canvas.drawPath(path, paint);
        });
      }
  }
}

void _burntTree(Canvas canvas, double x, double baseY, double h, Paint paint) {
  final trunkW = 4 + h * 0.04;
  canvas.drawRect(
    Rect.fromLTWH(x + h * 0.12 - trunkW / 2, baseY - h, trunkW, h),
    paint,
  );
  final branch = Paint()
    ..color = paint.color
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    Offset(x + h * 0.12, baseY - h * 0.72),
    Offset(x + h * 0.12 - h * 0.18, baseY - h * 0.55),
    branch,
  );
  canvas.drawLine(
    Offset(x + h * 0.12, baseY - h * 0.55),
    Offset(x + h * 0.12 + h * 0.16, baseY - h * 0.40),
    branch,
  );
}

void _conifer(Canvas canvas, double x, double baseY, double h, Paint paint) {
  final w = h * 0.42;
  canvas.drawRect(
    Rect.fromLTWH(x + w / 2 - 1.5, baseY - h * 0.22, 3, h * 0.22),
    paint,
  );
  for (var tier = 0; tier < 3; tier++) {
    final t = tier / 3;
    final tierW = w * (1 - t * 0.42);
    final top = baseY - h + h * 0.30 * tier;
    final path = Path()
      ..moveTo(x + w / 2, top)
      ..lineTo(x + w / 2 + tierW / 2, top + h * 0.34)
      ..lineTo(x + w / 2 - tierW / 2, top + h * 0.34)
      ..close();
    canvas.drawPath(path, paint);
  }
}

// ------------------------------------------------------------- near details

void _paintNear(Canvas canvas, BiomePalette palette, Random rng) {
  final paint = Paint()..color = palette.near;
  final baseY = layerHeight * 0.95;

  for (var i = 0; i < 22; i++) {
    final x = rng.nextDouble() * layerWidth;
    final w = 18 + rng.nextDouble() * 40;
    final h = 8 + rng.nextDouble() * 20;
    _tiled(canvas, x, w, (dx) {
      canvas.drawOval(Rect.fromLTWH(dx, baseY - h, w, h * 2), paint);
    });
  }

  // Grass or crystal tufts along the very bottom.
  final tuft = Paint()
    ..color = palette.groundAccent
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;
  for (var i = 0; i < 70; i++) {
    final x = rng.nextDouble() * layerWidth;
    final h = 4 + rng.nextDouble() * 9;
    canvas.drawLine(
      Offset(x, baseY + 6),
      Offset(x + (rng.nextDouble() - 0.5) * 5, baseY + 6 - h),
      tuft,
    );
  }
}

// -------------------------------------------------------------------- ground

void _paintGround(Canvas canvas, BiomePalette palette, Random rng) {
  final top = layerHeight * 0.90;
  canvas.drawRect(
    Rect.fromLTWH(0, top, layerWidth * 1.0, layerHeight - top),
    Paint()..color = palette.ground,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, top, layerWidth * 1.0, 3),
    Paint()..color = palette.groundAccent.withValues(alpha: 0.8),
  );

  final speck = Paint()..color = palette.groundAccent.withValues(alpha: 0.35);
  for (var i = 0; i < 120; i++) {
    final x = rng.nextDouble() * layerWidth;
    final y = top + 5 + rng.nextDouble() * (layerHeight - top - 6);
    canvas.drawCircle(Offset(x, y), rng.nextDouble() * 1.8 + 0.5, speck);
  }
}

/// Draws [draw] at [x] and, when the shape crosses an edge, again on the
/// opposite side so the finished image tiles seamlessly.
void _tiled(Canvas canvas, double x, double width, void Function(double) draw) {
  draw(x);
  if (x + width > layerWidth) draw(x - layerWidth);
  if (x < 0) draw(x + layerWidth);
}
