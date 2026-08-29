import 'package:flutter/material.dart';

import '../models/item.dart';
import '../models/location.dart';
import 'enemies_data.dart';
import 'items_data.dart';

/// The world map, ordered from starting zone to end game. Each node also owns
/// the palette its parallax background is generated from.
const List<LocationDef> _allLocations = [
  LocationDef(
    id: 'meadow',
    name: 'Ash Grove',
    region: 'The Ash Pilgrim',
    description:
        'A burnt forest that still smoulders. Embers hang in the air like '
        'fireflies that forgot how to die.',
    recommendedLevel: 1,
    icon: Icons.local_fire_department,
    mapCol: 0,
    mapRow: 0,
    spawns: [
      EnemySpawn('green_slime', weight: 2),
      EnemySpawn('ash_wolf', weight: 3),
      EnemySpawn('decayed_treant', weight: 2),
    ],
    palette: BiomePalette(
      skyTop: Color(0xFF2A1410),
      skyBottom: Color(0xFF8A3A1C),
      far: Color(0xFF4A2A22),
      mid: Color(0xFF2C1812),
      near: Color(0xFF1A0E0A),
      ground: Color(0xFF2A1A12),
      groundAccent: Color(0xFFFF6D00),
      fog: Color(0x22FF3D00),
      mood: BiomeMood.ash,
    ),
  ),
  LocationDef(
    id: 'goblin_woods',
    name: 'Goblin Woods',
    region: 'The Greenway',
    description:
        'Crooked pines, cookfire smoke, and a great many small green problems.',
    recommendedLevel: 5,
    icon: Icons.forest,
    mapCol: 1,
    mapRow: 1,
    requires: ['meadow'],
    unlockLevel: 4,
    unlockKills: 12,
    spawns: [
      EnemySpawn('goblin_scrapper', weight: 3),
      EnemySpawn('goblin_archer', weight: 2),
      EnemySpawn('grey_wolf', weight: 2),
    ],
    palette: BiomePalette(
      skyTop: Color(0xFF3C6E8F),
      skyBottom: Color(0xFF9FC58A),
      far: Color(0xFF4A6B57),
      mid: Color(0xFF2C4A38),
      near: Color(0xFF17301F),
      ground: Color(0xFF2A4A2C),
      groundAccent: Color(0xFF1B3320),
    ),
  ),
  LocationDef(
    id: 'howling_ridge',
    name: 'Howling Ridge',
    region: 'Ashen Frontier',
    description:
        'Wind-scoured stone above the treeline. Bandits camp here because '
        'nobody sane follows them up.',
    recommendedLevel: 10,
    icon: Icons.landscape,
    mapCol: 0,
    mapRow: 2,
    requires: ['goblin_woods'],
    unlockLevel: 9,
    unlockKills: 25,
    spawns: [
      EnemySpawn('dire_wolf', weight: 3),
      EnemySpawn('bandit_cutthroat', weight: 3),
      EnemySpawn('ridge_ogre', weight: 0.4),
    ],
    palette: BiomePalette(
      skyTop: Color(0xFF9C6B7B),
      skyBottom: Color(0xFFE0A878),
      far: Color(0xFF7A6070),
      mid: Color(0xFF4E3F50),
      near: Color(0xFF2E2632),
      ground: Color(0xFF56463F),
      groundAccent: Color(0xFF3B2F2A),
      mood: BiomeMood.dusk,
    ),
  ),
  LocationDef(
    id: 'skeleton_crypt',
    name: 'Skeleton Crypt',
    region: 'Ashen Frontier',
    description:
        'Someone stacked the dead here neatly. Someone else woke them up.',
    recommendedLevel: 17,
    icon: Icons.account_balance,
    mapCol: 1,
    mapRow: 3,
    requires: ['howling_ridge'],
    unlockLevel: 15,
    unlockKills: 30,
    spawns: [
      EnemySpawn('skeleton_warrior', weight: 3),
      EnemySpawn('skeleton_archer', weight: 2.5),
      EnemySpawn('bone_mage', weight: 1.5),
      EnemySpawn('crypt_lord', weight: 0.3),
    ],
    palette: BiomePalette(
      skyTop: Color(0xFF141B2E),
      skyBottom: Color(0xFF33405C),
      far: Color(0xFF2A3450),
      mid: Color(0xFF1B2438),
      near: Color(0xFF0E1421),
      ground: Color(0xFF2B2B38),
      groundAccent: Color(0xFF1A1A24),
      fog: Color(0x1A64FFDA),
      mood: BiomeMood.night,
    ),
  ),
  LocationDef(
    id: 'spider_hollow',
    name: 'Spider Hollow',
    region: 'Undervault',
    description:
        'The webs are load-bearing. Try not to think about what that means.',
    recommendedLevel: 23,
    icon: Icons.bug_report,
    mapCol: 0,
    mapRow: 4,
    requires: ['skeleton_crypt'],
    unlockLevel: 21,
    unlockKills: 35,
    spawns: [
      EnemySpawn('cave_spider', weight: 3),
      EnemySpawn('venom_bat', weight: 2),
      EnemySpawn('broodmother', weight: 0.25),
    ],
    palette: BiomePalette(
      skyTop: Color(0xFF1B1226),
      skyBottom: Color(0xFF3B2440),
      far: Color(0xFF35213C),
      mid: Color(0xFF241528),
      near: Color(0xFF130B16),
      ground: Color(0xFF2A1D2E),
      groundAccent: Color(0xFF190F1C),
      fog: Color(0x14E040FB),
      mood: BiomeMood.underground,
    ),
  ),
  LocationDef(
    id: 'orc_warcamp',
    name: 'Orc War Camp',
    region: 'Undervault',
    description:
        'Palisades, drums, and a warband that has been waiting for a reason.',
    recommendedLevel: 31,
    icon: Icons.military_tech,
    mapCol: 1,
    mapRow: 5,
    requires: ['spider_hollow'],
    unlockLevel: 29,
    unlockKills: 40,
    spawns: [
      EnemySpawn('orc_grunt', weight: 3),
      EnemySpawn('orc_berserker', weight: 2),
      EnemySpawn('warg', weight: 2),
    ],
    palette: BiomePalette(
      skyTop: Color(0xFF43301F),
      skyBottom: Color(0xFFA5643A),
      far: Color(0xFF6B4A32),
      mid: Color(0xFF432D1E),
      near: Color(0xFF261810),
      ground: Color(0xFF4A3524),
      groundAccent: Color(0xFF302216),
      fog: Color(0x10FF6D00),
      mood: BiomeMood.dusk,
    ),
  ),
  LocationDef(
    id: 'sunken_ruins',
    name: 'Sunken Ruins',
    region: 'Drowned Halls',
    description:
        'A city that argued with the sea and lost. Its garrison never stood down.',
    recommendedLevel: 40,
    icon: Icons.water,
    mapCol: 0,
    mapRow: 6,
    requires: ['orc_warcamp'],
    unlockLevel: 37,
    unlockKills: 45,
    spawns: [
      EnemySpawn('wraith', weight: 2.5),
      EnemySpawn('stone_golem', weight: 2),
      EnemySpawn('cursed_knight', weight: 2),
    ],
    palette: BiomePalette(
      skyTop: Color(0xFF0B2230),
      skyBottom: Color(0xFF1F5468),
      far: Color(0xFF255062),
      mid: Color(0xFF15323E),
      near: Color(0xFF091A21),
      ground: Color(0xFF17333A),
      groundAccent: Color(0xFF0D2026),
      fog: Color(0x1A80D8FF),
      mood: BiomeMood.night,
    ),
  ),
  LocationDef(
    id: 'emberpeak',
    name: 'Emberpeak Caldera',
    region: 'The Caldera',
    description: 'The mountain is awake and it has opinions about visitors.',
    recommendedLevel: 50,
    icon: Icons.whatshot,
    mapCol: 1,
    mapRow: 7,
    requires: ['sunken_ruins'],
    unlockLevel: 47,
    unlockKills: 50,
    spawns: [
      EnemySpawn('ember_imp', weight: 2.5),
      EnemySpawn('magma_golem', weight: 2),
      EnemySpawn('ash_drake', weight: 0.2),
    ],
    palette: BiomePalette(
      skyTop: Color(0xFF2A0E0E),
      skyBottom: Color(0xFFB33A16),
      far: Color(0xFF7A2A18),
      mid: Color(0xFF4A170F),
      near: Color(0xFF260A08),
      ground: Color(0xFF3A1510),
      groundAccent: Color(0xFFFF6D00),
      fog: Color(0x1FFF3D00),
      mood: BiomeMood.ash,
    ),
  ),
];

List<LocationDef> get allLocations => _allLocations;

final Map<String, LocationDef> locationCatalog = {
  for (final l in _allLocations) l.id: l,
};

LocationDef locationById(String id) {
  final l = locationCatalog[id];
  if (l == null) throw StateError('Unknown location id: $id');
  return l;
}

const String startingLocationId = 'meadow';

/// Locations grouped by region, preserving map order.
Map<String, List<LocationDef>> get locationsByRegion {
  final map = <String, List<LocationDef>>{};
  for (final l in _allLocations) {
    map.putIfAbsent(l.region, () => []).add(l);
  }
  return map;
}

/// Locations whose spawn table contains an enemy that drops [itemId].
List<LocationDef> locationsDropping(String itemId, Set<String> enemyIds) =>
    _allLocations.where((l) => l.enemyIds.any(enemyIds.contains)).toList();

/// Zones that can drop [itemId], used by recipe cards and farm routing.
List<LocationDef> zonesDroppingItem(String itemId) {
  final enemyIds = {for (final enemy in enemiesDropping(itemId)) enemy.id};
  return locationsDropping(itemId, enemyIds);
}

/// Unique crafting materials that can drop in [location], first-seen order.
List<ItemDef> materialsIn(LocationDef location) {
  final seen = <String>{};
  final out = <ItemDef>[];
  for (final spawn in location.spawns) {
    final enemy = enemyCatalog[spawn.enemyId];
    if (enemy == null) continue;
    for (final drop in enemy.loot) {
      if (!seen.add(drop.itemId)) continue;
      final item = tryItemById(drop.itemId);
      if (item == null || item.kind != ItemKind.material) continue;
      out.add(item);
    }
  }
  return out;
}

int get worldMapColumns =>
    _allLocations.map((l) => l.mapCol).reduce((a, b) => a > b ? a : b) + 1;

int get worldMapRows =>
    _allLocations.map((l) => l.mapRow).reduce((a, b) => a > b ? a : b) + 1;
