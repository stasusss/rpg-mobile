import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

/// A damage or status number that drifts upward and fades out.
class FloatingText extends PositionComponent {
  FloatingText({
    required this.text,
    required Vector2 super.position,
    required this.color,
    this.fontSize = 13,
    this.bold = false,
    this.lifetime = 0.85,
    Vector2? velocity,
  }) : velocity = velocity ?? Vector2(0, -34) {
    priority = 100;
  }

  final String text;
  final Color color;
  final double fontSize;
  final bool bold;
  final double lifetime;
  final Vector2 velocity;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= lifetime) {
      removeFromParent();
      return;
    }
    // Ease out so numbers pop up quickly then settle.
    position += velocity * dt * (1 - _elapsed / lifetime);
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / lifetime).clamp(0.0, 1.0);
    final alpha = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    final scale = bold ? 1 + 0.25 * (1 - min(1, t * 4)) : 1.0;
    final size = fontSize * scale;

    // Backgrounds range from bright sky to dark crypt, so the numbers are
    // outlined rather than shadowed to stay legible everywhere.
    TextPaint(
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.20
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black.withValues(alpha: alpha * 0.75),
      ),
    ).render(canvas, text, Vector2.zero(), anchor: Anchor.center);

    TextPaint(
      style: TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        color: color.withValues(alpha: alpha),
        height: 1,
      ),
    ).render(canvas, text, Vector2.zero(), anchor: Anchor.center);
  }
}

/// A crescent sweep drawn over the target when an attack lands.
class SlashEffect extends PositionComponent {
  SlashEffect({
    required Vector2 super.position,
    required this.radius,
    this.color = Colors.white,
    this.flip = false,
    this.lifetime = 0.22,
  }) {
    priority = 90;
  }

  final double radius;
  final Color color;

  /// Mirrors the sweep for attacks coming from the right.
  final bool flip;
  final double lifetime;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / lifetime).clamp(0.0, 1.0);
    final sweep = pi * 0.75;
    final start = (flip ? pi * 0.6 : -pi * 0.35) + t * sweep * 0.6;

    canvas.save();
    if (flip) {
      canvas.scale(-1, 1);
    }
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius * (0.7 + t * 0.5)),
      start,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: (1 - t) * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.18 * (1 - t * 0.5)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius * (0.45 + t * 0.35)),
      start + 0.2,
      sweep * 0.55,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: (1 - t) * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06 * (1 - t)
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }
}

/// Short spark spray on a landed hit.
class HitSparks extends PositionComponent {
  HitSparks({
    required Vector2 super.position,
    required this.color,
    this.count = 7,
    this.lifetime = 0.28,
    this.direction = 0,
  }) : _sparks = [
         for (var i = 0; i < count; i++)
           _Spark(
             angle:
                 direction +
                 (i / count) * pi * 1.4 -
                 0.7 +
                 Random(i + 3).nextDouble() * 0.35,
             speed: 42 + Random(i + 11).nextDouble() * 60,
             radius: 1.1 + Random(i + 19).nextDouble() * 1.8,
           ),
       ] {
    priority = 92;
  }

  final Color color;
  final int count;
  final double lifetime;
  final double direction;
  final List<_Spark> _sparks;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / lifetime).clamp(0.0, 1.0);
    final fade = 1 - t;
    final paint = Paint()..color = color.withValues(alpha: fade);
    for (final spark in _sparks) {
      final dist = spark.speed * t;
      canvas.drawCircle(
        Offset(cos(spark.angle) * dist, sin(spark.angle) * dist * 0.7),
        spark.radius * fade,
        paint,
      );
    }
  }
}

class _Spark {
  const _Spark({
    required this.angle,
    required this.speed,
    required this.radius,
  });

  final double angle;
  final double speed;
  final double radius;
}

/// Expanding ring plus shards, used for kills and level ups.
class ImpactBurst extends PositionComponent {
  ImpactBurst({
    required Vector2 super.position,
    required this.color,
    this.radius = 26,
    this.shards = 8,
    this.lifetime = 0.45,
  }) {
    priority = 95;
  }

  final Color color;
  final double radius;
  final int shards;
  final double lifetime;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / lifetime).clamp(0.0, 1.0);
    final fade = 1 - t;

    canvas.drawCircle(
      Offset.zero,
      radius * (0.2 + t * 1.1),
      Paint()
        ..color = color.withValues(alpha: fade * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * fade + 0.5,
    );

    final shardPaint = Paint()..color = color.withValues(alpha: fade);
    for (var i = 0; i < shards; i++) {
      final angle = (i / shards) * pi * 2 + t;
      final dist = radius * (0.3 + t * 1.4);
      canvas.drawCircle(
        Offset(cos(angle) * dist, sin(angle) * dist * 0.75),
        2.6 * fade + 0.4,
        shardPaint,
      );
    }
  }
}

/// Drifting cinders for the Ash Grove parallax. Recycles a small particle pool.
class EmberField extends PositionComponent {
  EmberField() {
    priority = 40;
  }

  final List<_Ember> _embers = [
    for (var i = 0; i < 28; i++) _Ember.spawn(Random(i * 17)),
  ];
  final Random _rng = Random();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final ember in _embers) {
      ember.life -= dt;
      ember.x += ember.vx * dt;
      ember.y += ember.vy * dt;
      if (ember.life <= 0 || ember.y < -8) {
        ember.reset(size, _rng);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint();
    for (final ember in _embers) {
      final t = (ember.life / ember.maxLife).clamp(0.0, 1.0);
      paint.color = Color.lerp(
        const Color(0xFFFF6D00),
        const Color(0xFFFFF176),
        ember.heat,
      )!.withValues(alpha: t * 0.85);
      canvas.drawCircle(Offset(ember.x, ember.y), ember.radius, paint);
    }
  }
}

class _Ember {
  _Ember({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.heat,
    required this.life,
    required this.maxLife,
  });

  factory _Ember.spawn(Random rng) => _Ember(
    x: rng.nextDouble() * 400,
    y: rng.nextDouble() * 240,
    vx: -8 + rng.nextDouble() * 16,
    vy: -18 - rng.nextDouble() * 28,
    radius: 0.8 + rng.nextDouble() * 1.8,
    heat: rng.nextDouble(),
    life: 0.6 + rng.nextDouble() * 2.2,
    maxLife: 2.4,
  );

  double x;
  double y;
  double vx;
  double vy;
  double radius;
  double heat;
  double life;
  double maxLife;

  void reset(Vector2 size, Random rng) {
    x = rng.nextDouble() * size.x;
    y = size.y * (0.35 + rng.nextDouble() * 0.55);
    vx = -10 + rng.nextDouble() * 20;
    vy = -16 - rng.nextDouble() * 32;
    radius = 0.8 + rng.nextDouble() * 1.8;
    heat = rng.nextDouble();
    maxLife = 1.2 + rng.nextDouble() * 2.0;
    life = maxLife;
  }
}

/// Slow drifting motes for crypts, ruins, and dusk dust.
class MoteField extends PositionComponent {
  MoteField({required this.kind}) {
    priority = 40;
  }

  final MoteKind kind;
  late final List<_Mote> _motes = [
    for (var i = 0; i < kind.count; i++) _Mote.spawn(Random(i * 31), kind),
  ];
  final Random _rng = Random();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final mote in _motes) {
      mote.life -= dt;
      mote.x += mote.vx * dt;
      mote.y += mote.vy * dt;
      if (mote.life <= 0 ||
          mote.x < -12 ||
          mote.x > size.x + 12 ||
          mote.y < -12 ||
          mote.y > size.y + 12) {
        mote.reset(size, _rng, kind);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint();
    for (final mote in _motes) {
      final t = (mote.life / mote.maxLife).clamp(0.0, 1.0);
      paint.color = Color.lerp(
        kind.cool,
        kind.warm,
        mote.heat,
      )!.withValues(alpha: t * kind.alpha);
      canvas.drawCircle(Offset(mote.x, mote.y), mote.radius, paint);
    }
  }
}

enum MoteKind {
  fog(
    count: 22,
    cool: Color(0xFFB0BEC5),
    warm: Color(0xFFE0F7FA),
    alpha: 0.28,
    vx: 8,
    vy: 5,
    radius: 2.4,
  ),
  dust(
    count: 16,
    cool: Color(0xFF8D6E63),
    warm: Color(0xFFD7CCC8),
    alpha: 0.22,
    vx: 14,
    vy: -6,
    radius: 1.6,
  );

  const MoteKind({
    required this.count,
    required this.cool,
    required this.warm,
    required this.alpha,
    required this.vx,
    required this.vy,
    required this.radius,
  });

  final int count;
  final Color cool;
  final Color warm;
  final double alpha;
  final double vx;
  final double vy;
  final double radius;
}

class _Mote {
  _Mote({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.heat,
    required this.life,
    required this.maxLife,
  });

  factory _Mote.spawn(Random rng, MoteKind kind) => _Mote(
    x: rng.nextDouble() * 400,
    y: rng.nextDouble() * 240,
    vx: -kind.vx + rng.nextDouble() * kind.vx * 2,
    vy: -kind.vy + rng.nextDouble() * kind.vy * 2,
    radius: kind.radius * (0.5 + rng.nextDouble()),
    heat: rng.nextDouble(),
    life: 1.4 + rng.nextDouble() * 3.2,
    maxLife: 3.6,
  );

  double x;
  double y;
  double vx;
  double vy;
  double radius;
  double heat;
  double life;
  double maxLife;

  void reset(Vector2 size, Random rng, MoteKind kind) {
    x = rng.nextDouble() * size.x;
    y = rng.nextDouble() * size.y;
    vx = -kind.vx + rng.nextDouble() * kind.vx * 2;
    vy = -kind.vy + rng.nextDouble() * kind.vy * 2;
    radius = kind.radius * (0.5 + rng.nextDouble());
    heat = rng.nextDouble();
    maxLife = 1.8 + rng.nextDouble() * 3.4;
    life = maxLife;
  }
}

/// Dust kicked up under a running actor.
class DustPuff extends PositionComponent {
  DustPuff({required Vector2 super.position, required this.color})
    : _radius = 3 + Random().nextDouble() * 3 {
    priority = 20;
  }

  final Color color;
  final double _radius;
  double _elapsed = 0;
  static const double lifetime = 0.4;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    position.x -= dt * 40;
    if (_elapsed >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / lifetime).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero,
      _radius * (1 + t * 1.6),
      Paint()..color = color.withValues(alpha: (1 - t) * 0.35),
    );
  }
}
