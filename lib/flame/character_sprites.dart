import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/enemy.dart';
import '../models/item.dart';

/// Named clip the procedural spritesheet is currently playing.
enum SpritePose { idle, attack, hurt, death }

/// Base class for the two on-screen fighters.
///
/// Sprites are drawn procedurally: a small skeleton of joint positions is
/// animated by [runPhase] and [_attackT], then filled with rounded strokes.
/// This keeps the game asset-free while still supporting run cycles, weapon
/// swings, hit flashes and death animations.
abstract class ActorComponent extends PositionComponent {
  ActorComponent({required double height, super.position})
    : super(size: Vector2(height * 0.72, height), anchor: Anchor.bottomCenter);

  static const double attackDuration = 0.34;
  static const double hurtDuration = 0.18;
  static const double deathDuration = 0.55;

  /// Advances while the actor is moving, driving the leg and arm cycle.
  double runPhase = 0;

  /// Set by the game each frame from the combat phase.
  bool isRunning = false;

  double _attackT = -1;
  double _hurtT = 0;
  double _deathT = -1;
  double _idlePhase = 0;
  bool _heavyHit = false;

  SpritePose get pose {
    if (_deathT >= 0) return SpritePose.death;
    if (_attackT >= 0) return SpritePose.attack;
    if (_hurtT > 0) return SpritePose.hurt;
    return SpritePose.idle;
  }

  /// 0..1 health, drawn as a bar above the head. Null hides the bar.
  double? healthFraction;

  /// Knocked out but not removed, used for the player's recovery window.
  bool downed = false;

  bool get isDying => _deathT >= 0;
  double get attackProgress => _attackT < 0 ? -1 : _attackT / attackDuration;

  void attack() {
    if (isDying) return;
    _attackT = 0;
  }

  void takeHit({bool heavy = false}) {
    if (isDying) return;
    _hurtT = heavy ? hurtDuration * 1.6 : hurtDuration;
    _heavyHit = heavy;
  }

  /// Starts the death animation; the component removes itself when it ends.
  void die() {
    if (isDying) return;
    _deathT = 0;
    _attackT = -1;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_deathT >= 0) {
      _deathT += dt;
      if (_deathT >= deathDuration) removeFromParent();
      return;
    }
    if (isRunning && !downed) {
      runPhase += dt * 9.5;
    } else if (!downed) {
      _idlePhase += dt * 1.8;
    }
    if (_attackT >= 0) {
      _attackT += dt;
      if (_attackT >= attackDuration) _attackT = -1;
    }
    if (_hurtT > 0) _hurtT = max(0, _hurtT - dt);
  }

  /// True while the actor faces right (the player). Enemies mirror.
  bool get facesRight;

  /// Where the drawn body starts, as a fraction of [size] from the top.
  ///
  /// Body plans do not all fill their box -- a slime only occupies the bottom
  /// three quarters -- so the health bar and damage numbers use this to sit
  /// just above the silhouette instead of floating in empty space.
  double get bodyTopFraction => 0;

  /// World-space y of the top of the silhouette.
  double get visibleTop => position.y - size.y * (1 - bodyTopFraction);

  /// Draws the body in a space where x grows forward and y grows downward,
  /// with the feet at `size.y` and the centre line at `size.x / 2`.
  void paintBody(Canvas canvas);

  @override
  void render(Canvas canvas) {
    final dying = _deathT >= 0;
    final deathT = dying ? (_deathT / deathDuration).clamp(0.0, 1.0) : 0.0;

    canvas.save();
    if (dying) {
      // Topple forward and fade out.
      canvas.translate(size.x / 2, size.y);
      canvas.rotate((facesRight ? 1 : -1) * deathT * 1.4);
      canvas.translate(-size.x / 2, -size.y);
    } else if (downed) {
      canvas.translate(size.x / 2, size.y);
      canvas.rotate((facesRight ? 1 : -1) * 1.45);
      canvas.translate(-size.x / 2, -size.y);
    }
    if (!facesRight) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    final bob = dying || downed
        ? 0.0
        : isRunning
        ? -sin(runPhase).abs() * size.y * 0.018
        : -sin(_idlePhase) * size.y * 0.008;
    canvas.translate(0, bob);

    if (dying) {
      canvas.saveLayer(
        Rect.fromLTWH(-size.x, -size.y, size.x * 3, size.y * 3),
        Paint()
          ..color = Colors.white.withValues(
            alpha: (1 - deathT).clamp(0.0, 1.0),
          ),
      );
      paintBody(canvas);
      canvas.restore();
    } else {
      paintBody(canvas);
      if (_hurtT > 0) {
        canvas.saveLayer(
          Rect.fromLTWH(-size.x, -size.y, size.x * 3, size.y * 3),
          Paint()..blendMode = BlendMode.srcATop,
        );
        paintBody(canvas);
        canvas.drawRect(
          Rect.fromLTWH(-size.x, -size.y, size.x * 3, size.y * 3),
          Paint()
            ..color = (_heavyHit ? const Color(0xFFFFF3C4) : Colors.white)
                .withValues(
                  alpha: (_heavyHit ? 0.95 : 0.75) * (_hurtT / hurtDuration),
                )
            ..blendMode = BlendMode.srcATop,
        );
        canvas.restore();
      }
    }

    canvas.restore();

    if (!dying && !downed) _paintHealthBar(canvas);
  }

  void _paintHealthBar(Canvas canvas) {
    final fraction = healthFraction;
    if (fraction == null) return;
    final f = fraction.clamp(0.0, 1.0);

    final width = size.x * 0.74;
    final height = (size.y * 0.028).clamp(3.0, 6.0);
    final left = (size.x - width) / 2;
    final top = size.y * bodyTopFraction - size.y * 0.075;
    final rect = Rect.fromLTWH(left, top, width, height);
    final radius = BorderRadius.circular(height / 2);

    canvas.drawRRect(
      radius.toRRect(rect.inflate(1.2)),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawRRect(
      radius.toRRect(rect),
      Paint()..color = const Color(0xFF241014),
    );
    if (f > 0) {
      canvas.drawRRect(
        radius.toRRect(Rect.fromLTWH(left, top, width * f, height)),
        Paint()..color = healthColor(f),
      );
    }
  }

  /// Three flat bands rather than a red-to-green lerp, which muddies to khaki.
  static Color healthColor(double fraction) {
    if (fraction > 0.6) return const Color(0xFF5FD16A);
    if (fraction > 0.3) return const Color(0xFFFFB300);
    return const Color(0xFFE53935);
  }

  // ------------------------------------------------------- drawing utilities

  /// A limb or torso segment drawn as a thick rounded line.
  static void limb(
    Canvas canvas,
    Offset from,
    Offset to,
    double width,
    Color color,
  ) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Resting angle of the weapon arm. Slightly forward of straight down, so
  /// the grip -- and therefore the weapon -- reads in front of the body.
  static const double restSwing = 0.08;

  /// Swing angle in radians for the weapon arm, mapped from [attackProgress].
  static double swingAngle(double progress) {
    if (progress < 0) return restSwing;
    if (progress < 0.32) {
      // Wind up and back.
      return restSwing - (progress / 0.32) * 1.38;
    }
    if (progress < 0.55) {
      final t = (progress - 0.32) / 0.23;
      return -1.3 + t * 2.5;
    }
    final t = (progress - 0.55) / 0.45;
    return 1.2 - t * (1.2 - restSwing);
  }
}

/// Equipment-driven appearance of the hero.
@immutable
class PlayerLook {
  const PlayerLook({
    this.weapon,
    this.weaponColor = const Color(0xFFB0BEC5),
    this.hasShield = false,
    this.shieldColor = const Color(0xFF8D6E63),
    this.hasHelmet = false,
    this.helmetColor = const Color(0xFF90A4AE),
    this.armorColor = const Color(0xFF3F6FA8),
    this.bootColor = const Color(0xFF5D4037),
    this.glowRarity,
  });

  final WeaponLook? weapon;
  final Color weaponColor;
  final bool hasShield;
  final Color shieldColor;
  final bool hasHelmet;
  final Color helmetColor;
  final Color armorColor;
  final Color bootColor;

  /// Highest worn rarity, used for the paper-doll glow on epic+ kit.
  final ItemRarity? glowRarity;
}

/// The hero. Always faces right and runs on the left of the viewport.
class PlayerComponent extends ActorComponent {
  PlayerComponent({required super.height, super.position});

  static const Color _skin = Color(0xFFE8B08A);

  PlayerLook look = const PlayerLook();

  @override
  bool get facesRight => true;

  @override
  void paintBody(Canvas canvas) {
    final h = size.y;
    final cx = size.x / 2;
    // Idle keeps a fighting stance rather than snapping both legs together.
    final s = isRunning ? sin(runPhase) : 0.42;
    final swing = ActorComponent.swingAngle(attackProgress);

    final hipY = h * 0.53;
    final shoulder = Offset(cx, h * 0.275);
    final glow = look.glowRarity;
    if (glow != null && glow.index >= ItemRarity.epic.index) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, h * 0.46),
          width: h * (glow == ItemRarity.legendary ? 0.62 : 0.52),
          height: h * 0.78,
        ),
        Paint()
          ..color = glow.color.withValues(
            alpha: glow == ItemRarity.legendary ? 0.28 : 0.18,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    final sleeve = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.12),
      look.armorColor,
    );

    // Back limbs first so the front pair reads on top.
    _leg(canvas, h, Offset(cx - h * 0.03, hipY), -s, back: true);
    _arm(canvas, h, shoulder, 0.52 - swing * 0.3, sleeve, back: true);

    _torso(canvas, h, cx, hipY, shoulder.dy);
    _head(canvas, h, cx);

    _leg(canvas, h, Offset(cx + h * 0.03, hipY), s, back: false);

    // Weapon arm and its blade sit above everything else.
    final grip = _arm(canvas, h, shoulder, swing, sleeve, back: false);
    if (look.weapon != null) {
      _weapon(canvas, grip, h, swing, look.weapon!, look.weaponColor);
    }
    if (look.hasShield) {
      _shield(canvas, h, shoulder, 0.52 - swing * 0.3);
    }
  }

  static Offset _dir(double angle) => Offset(sin(angle), cos(angle));

  void _torso(Canvas canvas, double h, double cx, double hipY, double topY) {
    final shoulderW = h * 0.205;
    final hipW = h * 0.165;
    final path = Path()
      ..moveTo(cx - shoulderW / 2, topY)
      ..lineTo(cx + shoulderW / 2, topY)
      ..lineTo(cx + hipW / 2, hipY)
      ..lineTo(cx - hipW / 2, hipY)
      ..close();
    canvas.drawPath(path, Paint()..color = look.armorColor);
    // Belt.
    canvas.drawRect(
      Rect.fromLTWH(cx - hipW * 0.60, hipY - h * 0.035, hipW * 1.20, h * 0.035),
      Paint()
        ..color = Color.alphaBlend(
          Colors.black.withValues(alpha: 0.35),
          look.armorColor,
        ),
    );
  }

  void _head(Canvas canvas, double h, double cx) {
    final center = Offset(cx + h * 0.012, h * 0.155);
    final r = h * 0.092;

    // Neck.
    canvas.drawRect(
      Rect.fromLTWH(cx - h * 0.026, h * 0.215, h * 0.052, h * 0.045),
      Paint()
        ..color = Color.alphaBlend(Colors.black.withValues(alpha: 0.15), _skin),
    );
    canvas.drawCircle(center, r, Paint()..color = _skin);
    // Nose nub, which is what sells the side-on profile.
    canvas.drawCircle(
      center + Offset(r * 0.92, r * 0.16),
      r * 0.20,
      Paint()..color = _skin,
    );

    if (look.hasHelmet) {
      _helmet(canvas, center, r);
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 1.06),
        pi * 0.88,
        pi * 1.02,
        true,
        Paint()..color = const Color(0xFF6D4C41),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(r * 0.42, 0),
        width: r * 0.20,
        height: r * 0.30,
      ),
      Paint()..color = const Color(0xFF263238),
    );
  }

  void _leg(
    Canvas canvas,
    double h,
    Offset hip,
    double phase, {
    required bool back,
  }) {
    final shade = back ? 0.22 : 0.0;
    final pants = Color.alphaBlend(
      Colors.black.withValues(alpha: shade),
      look.armorColor,
    );
    final boots = Color.alphaBlend(
      Colors.black.withValues(alpha: shade),
      look.bootColor,
    );

    final lift = max(0.0, phase) * h * 0.06;
    final foot = Offset(hip.dx + phase * h * 0.115, h - lift);
    final knee = Offset(
      (hip.dx + foot.dx) / 2 + phase * h * 0.018,
      (hip.dy + foot.dy) / 2,
    );
    ActorComponent.limb(canvas, hip, knee, h * 0.062, pants);
    ActorComponent.limb(canvas, knee, foot, h * 0.052, boots);
    ActorComponent.limb(
      canvas,
      foot,
      foot + Offset(h * 0.042, 0),
      h * 0.038,
      boots,
    );
  }

  /// Draws a two-segment arm and returns the hand position.
  Offset _arm(
    Canvas canvas,
    double h,
    Offset shoulder,
    double angle,
    Color sleeve, {
    required bool back,
  }) {
    final elbow = shoulder + _dir(angle) * (h * 0.135);
    final hand = elbow + _dir(angle + 0.5) * (h * 0.125);
    final shade = back ? 0.22 : 0.0;
    ActorComponent.limb(
      canvas,
      shoulder,
      elbow,
      h * 0.048,
      Color.alphaBlend(Colors.black.withValues(alpha: shade), sleeve),
    );
    ActorComponent.limb(
      canvas,
      elbow,
      hand,
      h * 0.040,
      Color.alphaBlend(Colors.black.withValues(alpha: shade), _skin),
    );
    return hand;
  }

  void _helmet(Canvas canvas, Offset center, double r) {
    final paint = Paint()..color = look.helmetColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 1.18),
      pi,
      pi,
      true,
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - r * 1.18,
        center.dy - r * 0.1,
        r * 2.0,
        r * 0.2,
      ),
      paint,
    );
  }

  void _shield(Canvas canvas, double h, Offset shoulder, double angle) {
    final elbow = shoulder + _dir(angle) * (h * 0.135);
    final hand = elbow + _dir(angle + 0.5) * (h * 0.125);
    final rect = Rect.fromCenter(
      center: hand + Offset(h * 0.025, -h * 0.01),
      width: h * 0.135,
      height: h * 0.20,
    );
    canvas.drawRRect(
      BorderRadius.circular(h * 0.045).toRRect(rect),
      Paint()..color = look.shieldColor,
    );
    canvas.drawRRect(
      BorderRadius.circular(h * 0.035).toRRect(rect.deflate(h * 0.020)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.010,
    );
  }

  void _weapon(
    Canvas canvas,
    Offset hand,
    double h,
    double angle,
    WeaponLook look,
    Color color,
  ) {
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    // Blades are modelled pointing along -y, so the rest pose needs a forward
    // tilt: the arm angle alone lays the weapon flat backwards, and too small
    // an offset stands it upright through the hero's head.
    canvas.rotate(angle * 1.15 + 0.62);

    final metal = Paint()..color = color;
    final wood = Paint()..color = const Color(0xFF6D4C41);
    final dark = Paint()
      ..color = Color.alphaBlend(Colors.black.withValues(alpha: 0.35), color);

    switch (look) {
      case WeaponLook.sword:
        canvas.drawRect(
          Rect.fromLTWH(-h * 0.017, -h * 0.075, h * 0.034, h * 0.095),
          dark,
        );
        canvas.drawRect(
          Rect.fromLTWH(-h * 0.056, -h * 0.088, h * 0.112, h * 0.022),
          metal,
        );
        final blade = Path()
          ..moveTo(-h * 0.024, -h * 0.088)
          ..lineTo(h * 0.024, -h * 0.088)
          ..lineTo(h * 0.016, -h * 0.415)
          ..lineTo(0, -h * 0.465)
          ..lineTo(-h * 0.016, -h * 0.415)
          ..close();
        canvas.drawPath(blade, metal);
      case WeaponLook.dagger:
        canvas.drawRect(
          Rect.fromLTWH(-h * 0.014, -h * 0.060, h * 0.028, h * 0.080),
          dark,
        );
        canvas.drawRect(
          Rect.fromLTWH(-h * 0.040, -h * 0.070, h * 0.080, h * 0.018),
          metal,
        );
        final blade = Path()
          ..moveTo(-h * 0.019, -h * 0.070)
          ..lineTo(h * 0.019, -h * 0.070)
          ..lineTo(0, -h * 0.250)
          ..close();
        canvas.drawPath(blade, metal);
      case WeaponLook.axe:
        canvas.drawRect(
          Rect.fromLTWH(-h * 0.016, -h * 0.375, h * 0.032, h * 0.455),
          wood,
        );
        final head = Path()
          ..moveTo(0, -h * 0.375)
          ..quadraticBezierTo(h * 0.150, -h * 0.330, h * 0.098, -h * 0.215)
          ..lineTo(0, -h * 0.245)
          ..close();
        canvas.drawPath(head, metal);
        final back = Path()
          ..moveTo(0, -h * 0.375)
          ..quadraticBezierTo(-h * 0.098, -h * 0.340, -h * 0.068, -h * 0.245)
          ..lineTo(0, -h * 0.260)
          ..close();
        canvas.drawPath(back, dark);
      case WeaponLook.mace:
        canvas.drawRect(
          Rect.fromLTWH(-h * 0.018, -h * 0.320, h * 0.036, h * 0.400),
          wood,
        );
        canvas.drawCircle(Offset(0, -h * 0.365), h * 0.062, metal);
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3;
          canvas.drawCircle(
            Offset(cos(a) * h * 0.070, -h * 0.365 + sin(a) * h * 0.070),
            h * 0.017,
            dark,
          );
        }
      case WeaponLook.staff:
        canvas.drawRect(
          Rect.fromLTWH(-h * 0.014, -h * 0.450, h * 0.028, h * 0.530),
          wood,
        );
        canvas.drawCircle(Offset(0, -h * 0.478), h * 0.042, metal);
        canvas.drawCircle(
          Offset(0, -h * 0.478),
          h * 0.070,
          Paint()..color = color.withValues(alpha: 0.28),
        );
      case WeaponLook.spear:
        canvas.drawRect(
          Rect.fromLTWH(-h * 0.012, -h * 0.500, h * 0.024, h * 0.580),
          wood,
        );
        final tip = Path()
          ..moveTo(-h * 0.028, -h * 0.488)
          ..lineTo(h * 0.028, -h * 0.488)
          ..lineTo(0, -h * 0.610)
          ..close();
        canvas.drawPath(tip, metal);
    }
    canvas.restore();
  }
}

/// An enemy drawn from its [EnemyVisual] body plan.
class EnemyComponent extends ActorComponent {
  EnemyComponent({required this.visual, required super.height, super.position});

  final EnemyVisual visual;

  @override
  bool get facesRight => false;

  @override
  double get bodyTopFraction => switch (visual.plan) {
    BodyPlan.humanoid || BodyPlan.hulk => 0.02,
    BodyPlan.flyer => 0.10,
    BodyPlan.blob => 0.26,
    BodyPlan.quadruped => 0.24,
    BodyPlan.arachnid => 0.40,
  };

  @override
  void paintBody(Canvas canvas) {
    switch (visual.plan) {
      case BodyPlan.humanoid:
        _humanoid(canvas, bulk: 1.0);
      case BodyPlan.hulk:
        _humanoid(canvas, bulk: 1.5);
      case BodyPlan.quadruped:
        _quadruped(canvas);
      case BodyPlan.blob:
        _blob(canvas);
      case BodyPlan.flyer:
        _flyer(canvas);
      case BodyPlan.arachnid:
        _arachnid(canvas);
    }
  }

  Paint get _body => Paint()..color = visual.body;
  Paint get _accent => Paint()..color = visual.accent;

  void _eye(Canvas canvas, Offset at, double r) {
    canvas.drawCircle(at, r, Paint()..color = visual.eye);
    canvas.drawCircle(
      at,
      r * 2.2,
      Paint()..color = visual.eye.withValues(alpha: 0.25),
    );
  }

  void _humanoid(Canvas canvas, {required double bulk}) {
    final h = size.y;
    final cx = size.x / 2;
    // A wide planted stance while idle; without the spread the two legs and
    // the torso merge into one featureless column.
    final s = isRunning ? sin(runPhase) : 0.62;
    final swing = ActorComponent.swingAngle(attackProgress);

    final hipY = h * 0.56;
    final shoulder = Offset(cx, h * (0.295 - 0.015 * (bulk - 1)));
    final shade = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.28),
      visual.body,
    );

    void leg(double phase, Color color) {
      final root = Offset(cx + phase.sign * h * 0.045 * bulk, hipY);
      final lift = max(0.0, phase) * h * 0.055;
      final foot = Offset(root.dx + phase * h * 0.135, h - lift);
      final knee = Offset((root.dx + foot.dx) / 2, (hipY + h) / 2);
      ActorComponent.limb(canvas, root, knee, h * 0.058 * bulk, color);
      ActorComponent.limb(canvas, knee, foot, h * 0.048 * bulk, color);
      ActorComponent.limb(
        canvas,
        foot,
        foot + Offset(-phase.sign * h * 0.045, 0),
        h * 0.034,
        color,
      );
    }

    Offset arm(double angle, Color color) {
      final elbow = shoulder + Offset(sin(angle), cos(angle)) * (h * 0.14);
      final hand =
          elbow + Offset(sin(angle + 0.45), cos(angle + 0.45)) * (h * 0.125);
      ActorComponent.limb(canvas, shoulder, elbow, h * 0.050 * bulk, color);
      ActorComponent.limb(canvas, elbow, hand, h * 0.042 * bulk, color);
      return hand;
    }

    leg(-s, shade);
    arm(0.55, shade);

    // Tapered torso: broad shoulders narrowing to the hips.
    final shoulderW = h * 0.21 * bulk;
    final hipW = h * 0.165 * bulk;
    canvas.drawPath(
      Path()
        ..moveTo(cx - shoulderW / 2, shoulder.dy)
        ..lineTo(cx + shoulderW / 2, shoulder.dy)
        ..lineTo(cx + hipW / 2, hipY)
        ..lineTo(cx - hipW / 2, hipY)
        ..close(),
      _body,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - hipW * 0.58, hipY - h * 0.042, hipW * 1.16, h * 0.042),
      _accent,
    );

    leg(
      s,
      Color.alphaBlend(Colors.white.withValues(alpha: 0.06), visual.accent),
    );

    final headR = h * 0.105 * (bulk > 1 ? 1.12 : 1.0);
    final headCenter = Offset(cx, shoulder.dy - headR * 1.05);
    canvas.drawRect(
      Rect.fromLTWH(
        cx - h * 0.030,
        headCenter.dy,
        h * 0.060,
        shoulder.dy - headCenter.dy,
      ),
      Paint()..color = shade,
    );
    canvas.drawCircle(headCenter, headR, _body);
    if (visual.horns) {
      for (final side in [-1.0, 1.0]) {
        final path = Path()
          ..moveTo(
            headCenter.dx + side * headR * 0.80,
            headCenter.dy - headR * 0.45,
          )
          ..lineTo(
            headCenter.dx + side * headR * 1.55,
            headCenter.dy - headR * 1.45,
          )
          ..lineTo(
            headCenter.dx + side * headR * 0.62,
            headCenter.dy - headR * 0.90,
          )
          ..close();
        canvas.drawPath(path, _accent);
      }
    }
    if (visual.wings) _wings(canvas, shoulder, h, bulk);
    _eye(
      canvas,
      headCenter + Offset(-headR * 0.42, -headR * 0.1),
      headR * 0.17,
    );
    _eye(canvas, headCenter + Offset(headR * 0.42, -headR * 0.1), headR * 0.17);

    // Weapon arm on top of the torso.
    final hand = arm(swing, visual.body);
    if (visual.hasWeapon) {
      canvas.save();
      canvas.translate(hand.dx, hand.dy);
      canvas.rotate(swing * 1.15 + 0.62);
      canvas.drawRect(
        Rect.fromLTWH(-h * 0.015, -h * 0.290, h * 0.030, h * 0.365),
        Paint()..color = const Color(0xFF5D4037),
      );
      final blade = Path()
        ..moveTo(-h * 0.042, -h * 0.280)
        ..lineTo(h * 0.042, -h * 0.280)
        ..lineTo(0, -h * 0.415)
        ..close();
      canvas.drawPath(blade, Paint()..color = const Color(0xFFCFD8DC));
      canvas.restore();
    }
  }

  void _quadruped(Canvas canvas) {
    final h = size.y;
    final cx = size.x / 2;
    final s = isRunning ? sin(runPhase) : 0.0;
    final s2 = isRunning ? sin(runPhase + pi * 0.7) : 0.0;
    final backY = h * 0.58;

    for (final pair in [
      (cx - h * 0.22, s),
      (cx - h * 0.16, s2),
      (cx + h * 0.20, -s2),
      (cx + h * 0.26, -s),
    ]) {
      final top = Offset(pair.$1, backY + h * 0.10);
      final foot = Offset(
        pair.$1 + pair.$2 * h * 0.11,
        h - max(0.0, pair.$2) * h * 0.05,
      );
      ActorComponent.limb(canvas, top, foot, h * 0.065, visual.accent);
    }

    // Tail.
    ActorComponent.limb(
      canvas,
      Offset(cx + h * 0.30, backY + h * 0.06),
      Offset(cx + h * 0.46, backY - h * 0.06 + s * h * 0.05),
      h * 0.045,
      visual.accent,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + h * 0.06, backY + h * 0.10),
        width: h * 0.58,
        height: h * 0.32,
      ),
      _body,
    );

    // Head and snout.
    final headCenter = Offset(cx - h * 0.29, backY - h * 0.04);
    ActorComponent.limb(
      canvas,
      Offset(cx - h * 0.12, backY + h * 0.06),
      headCenter,
      h * 0.15,
      visual.body,
    );
    canvas.drawCircle(headCenter, h * 0.155, _body);
    final snout = Path()
      ..moveTo(headCenter.dx - h * 0.02, headCenter.dy - h * 0.03)
      ..lineTo(headCenter.dx - h * 0.26, headCenter.dy + h * 0.05)
      ..lineTo(headCenter.dx - h * 0.02, headCenter.dy + h * 0.11)
      ..close();
    canvas.drawPath(snout, _accent);
    for (final side in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(headCenter.dx + side * h * 0.04, headCenter.dy - h * 0.12)
        ..lineTo(headCenter.dx + side * h * 0.03, headCenter.dy - h * 0.27)
        ..lineTo(headCenter.dx + side * h * 0.12, headCenter.dy - h * 0.10)
        ..close();
      canvas.drawPath(ear, _accent);
    }
    if (visual.horns) {
      final tusk = Path()
        ..moveTo(headCenter.dx - h * 0.17, headCenter.dy + h * 0.08)
        ..lineTo(headCenter.dx - h * 0.24, headCenter.dy - h * 0.04)
        ..lineTo(headCenter.dx - h * 0.14, headCenter.dy + h * 0.04)
        ..close();
      canvas.drawPath(tusk, Paint()..color = const Color(0xFFECEFF1));
    }
    _eye(canvas, headCenter + Offset(-h * 0.06, -h * 0.04), h * 0.022);
  }

  void _blob(Canvas canvas) {
    final h = size.y;
    final cx = size.x / 2;
    final squash = isRunning ? sin(runPhase * 0.9) * 0.10 : 0.0;
    final w = h * (0.86 + squash);
    final bodyH = h * (0.74 - squash);

    final rect = Rect.fromCenter(
      center: Offset(cx, h - bodyH / 2),
      width: w,
      height: bodyH,
    );
    canvas.drawRRect(
      BorderRadius.vertical(
        top: Radius.circular(w * 0.5),
        bottom: Radius.circular(w * 0.18),
      ).toRRect(rect),
      _body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - w * 0.16, h - bodyH * 0.72),
        width: w * 0.26,
        height: bodyH * 0.22,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );
    _eye(canvas, Offset(cx - w * 0.16, h - bodyH * 0.52), h * 0.030);
    _eye(canvas, Offset(cx + w * 0.14, h - bodyH * 0.52), h * 0.030);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, h - bodyH * 0.34),
        width: w * 0.34,
        height: bodyH * 0.20,
      ),
      0,
      pi,
      false,
      Paint()
        ..color = visual.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.016,
    );
  }

  void _flyer(Canvas canvas) {
    final h = size.y;
    final cx = size.x / 2;
    final hover = sin(runPhase * 1.6) * h * 0.05;
    final center = Offset(cx, h * 0.46 + hover);

    // Tail first: a tapering wisp behind the body rather than a thick stump.
    final tailPaint = Paint()
      ..color = visual.accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final t0 = i / 3;
      final t1 = (i + 1) / 3;
      Offset at(double t) => Offset(
        center.dx + sin(runPhase * 1.8 + t * 2.4) * h * 0.05 * t,
        center.dy + h * (0.14 + t * 0.26),
      );
      canvas.drawLine(
        at(t0),
        at(t1),
        Paint.from(tailPaint)..strokeWidth = h * 0.038 * (1 - t0 * 0.7),
      );
    }

    _wings(canvas, center, h, 1.0);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: h * 0.40, height: h * 0.38),
      _body,
    );
    if (visual.horns) {
      for (final side in [-1.0, 1.0]) {
        final path = Path()
          ..moveTo(center.dx + side * h * 0.08, center.dy - h * 0.16)
          ..lineTo(center.dx + side * h * 0.16, center.dy - h * 0.30)
          ..lineTo(center.dx + side * h * 0.02, center.dy - h * 0.18)
          ..close();
        canvas.drawPath(path, _accent);
      }
    }
    _eye(canvas, center + Offset(-h * 0.08, -h * 0.04), h * 0.026);
    _eye(canvas, center + Offset(h * 0.08, -h * 0.04), h * 0.026);
    // Fangs.
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(center.dx + side * h * 0.05, center.dy + h * 0.10)
          ..lineTo(center.dx + side * h * 0.02, center.dy + h * 0.10)
          ..lineTo(center.dx + side * h * 0.035, center.dy + h * 0.16)
          ..close(),
        Paint()..color = const Color(0xFFECEFF1),
      );
    }
  }

  void _wings(Canvas canvas, Offset center, double h, double bulk) {
    final flap = sin(runPhase * 2.4);
    for (final side in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          center.dx + side * h * 0.34 * bulk,
          center.dy - h * (0.24 + flap * 0.10) * bulk,
          center.dx + side * h * 0.44 * bulk,
          center.dy + h * (0.06 - flap * 0.06) * bulk,
        )
        ..quadraticBezierTo(
          center.dx + side * h * 0.22 * bulk,
          center.dy + h * 0.06 * bulk,
          center.dx,
          center.dy,
        );
      canvas.drawPath(
        path,
        Paint()..color = visual.accent.withValues(alpha: 0.85),
      );
    }
  }

  void _arachnid(Canvas canvas) {
    final h = size.y;
    final cx = size.x / 2;
    final bodyY = h * 0.60;

    // Each pair fans out further and peaks lower, so the legs read as a
    // spread rather than the parallel comb a shared hinge produced.
    for (var i = 0; i < 4; i++) {
      final t = i / 3;
      final phase = isRunning ? sin(runPhase + i * 1.1) : 0.0;
      final reach = 0.19 + t * 0.13;
      final rise = 0.26 - t * 0.08;
      for (final side in [-1.0, 1.0]) {
        final knee = Offset(
          cx + side * h * reach,
          bodyY - h * rise + phase * h * 0.03,
        );
        final foot = Offset(
          cx + side * h * (reach + 0.06),
          h - max(0.0, phase) * h * 0.04,
        );
        ActorComponent.limb(
          canvas,
          Offset(cx + side * h * 0.05, bodyY),
          knee,
          h * 0.026,
          visual.accent,
        );
        ActorComponent.limb(canvas, knee, foot, h * 0.020, visual.accent);
      }
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + h * 0.13, bodyY - h * 0.03),
        width: h * 0.38,
        height: h * 0.32,
      ),
      _body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - h * 0.15, bodyY),
        width: h * 0.26,
        height: h * 0.22,
      ),
      _accent,
    );
    for (var i = 0; i < 4; i++) {
      final side = i < 2 ? -1.0 : 1.0;
      final row = i.isEven ? 0.0 : 1.0;
      _eye(
        canvas,
        Offset(
          cx - h * 0.21 + side * h * 0.035,
          bodyY - h * 0.045 + row * h * 0.045,
        ),
        h * 0.015,
      );
    }
  }
}
