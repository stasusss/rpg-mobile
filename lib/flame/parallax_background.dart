import 'package:flame/components.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';

import '../models/location.dart';
import 'procedural_art.dart';

/// Five-layer scrolling backdrop that creates the endless-running illusion.
///
/// Layer velocities are multiples of a single base velocity, so stopping the
/// run (during a fight) is one assignment away and every layer decelerates in
/// proportion.
class ParallaxBackground extends ParallaxComponent {
  ParallaxBackground({required this.initialLocation}) : super(priority: -100);

  /// Relative scroll rates, back to front. The sky stays put.
  static const List<double> _velocities = [0.0, 0.12, 0.32, 0.7, 1.0];

  /// Pixels per second the ground layer moves while the player runs.
  static const double runSpeed = 150;

  final LocationDef initialLocation;

  String? _loadedLocationId;
  double _targetSpeed = 0;
  double _speed = 0;

  /// Set to false during fights so the world holds still.
  set running(bool value) => _targetSpeed = value ? runSpeed : 0;

  @override
  Future<void> onLoad() async {
    await applyLocation(initialLocation);
  }

  /// Swaps in the layers for [location], generating them on first visit.
  Future<void> applyLocation(LocationDef location) async {
    if (_loadedLocationId == location.id) return;
    _loadedLocationId = location.id;

    final art = await biomeArtFor(location.id, location.palette);
    // A later call may have superseded this one while art was rasterising.
    if (_loadedLocationId != location.id) return;

    final images = [art.sky, art.far, art.mid, art.near, art.ground];
    parallax = Parallax([
      for (var i = 0; i < images.length; i++)
        ParallaxLayer(
          ParallaxImage(
            images[i],
            repeat: ImageRepeat.repeatX,
            alignment: Alignment.bottomLeft,
            fill: LayerFill.height,
          ),
          velocityMultiplier: Vector2(_velocities[i], 0),
        ),
    ], baseVelocity: Vector2(_speed, 0));
  }

  @override
  void update(double dt) {
    // Exponential approach, so starting and stopping read as acceleration.
    _speed += (_targetSpeed - _speed) * (dt * 5).clamp(0.0, 1.0);
    parallax?.baseVelocity.x = _speed;
    super.update(dt);
  }
}

/// Flat colour wash on top of the world, for cave gloom and volcanic haze.
class FogOverlay extends PositionComponent {
  FogOverlay({required this.color}) {
    priority = 50;
  }

  Color color;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
  }

  @override
  void render(Canvas canvas) {
    if (color.a == 0) return;
    canvas.drawRect(size.toRect(), Paint()..color = color);
  }
}

/// Subtle vignette that keeps the UI edges readable over bright biomes.
class Vignette extends PositionComponent {
  Vignette() {
    priority = 60;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.28),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.35),
          ],
          stops: const [0, 0.22, 0.7, 1],
        ).createShader(rect),
    );
  }
}
