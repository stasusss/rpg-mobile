import 'package:flutter/material.dart';

/// Colour scheme driving the procedural parallax layers for a location.
@immutable
class BiomePalette {
  const BiomePalette({
    required this.skyTop,
    required this.skyBottom,
    required this.far,
    required this.mid,
    required this.near,
    required this.ground,
    required this.groundAccent,
    this.fog = const Color(0x00000000),
    this.mood = BiomeMood.day,
  });

  final Color skyTop;
  final Color skyBottom;

  /// Distant silhouettes (mountains / spires).
  final Color far;

  /// Mid-ground silhouettes (trees / ruins).
  final Color mid;

  /// Foreground bushes and rocks.
  final Color near;
  final Color ground;
  final Color groundAccent;

  /// Overlay tint applied on top of everything.
  final Color fog;
  final BiomeMood mood;
}

enum BiomeMood { day, dusk, night, underground, ash }

/// A weighted spawn table row for a location.
@immutable
class EnemySpawn {
  const EnemySpawn(this.enemyId, {this.weight = 1});

  final String enemyId;
  final double weight;
}

/// A node on the world map.
@immutable
class LocationDef {
  const LocationDef({
    required this.id,
    required this.name,
    required this.region,
    required this.recommendedLevel,
    required this.spawns,
    required this.palette,
    this.description = '',
    this.requires = const [],
    this.unlockLevel = 1,
    this.unlockKills = 0,
    this.icon = Icons.forest,
    this.mapCol = 0,
    this.mapRow = 0,
  });

  final String id;
  final String name;
  final String region;
  final String description;
  final int recommendedLevel;

  /// Location ids that must have reached [unlockKills] before this unlocks.
  final List<String> requires;
  final int unlockLevel;
  final int unlockKills;
  final List<EnemySpawn> spawns;
  final BiomePalette palette;
  final IconData icon;

  /// Zigzag grid slot used by the interactive world map.
  final int mapCol;
  final int mapRow;

  Iterable<String> get enemyIds => spawns.map((s) => s.enemyId);
}
