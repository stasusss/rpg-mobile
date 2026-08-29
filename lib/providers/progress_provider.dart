import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/enemies_data.dart';
import '../data/locations_data.dart';
import '../models/location.dart';
import 'locale_provider.dart';
import 'player_provider.dart';
import 'save_provider.dart';

/// Kill counters and discovery flags. Drives map unlocks and the bestiary.
@immutable
class ProgressState {
  const ProgressState({
    this.currentLocationId = startingLocationId,
    this.killsByLocation = const {},
    this.killsByEnemy = const {},
    this.discoveredItems = const {},
  });

  final String currentLocationId;
  final Map<String, int> killsByLocation;
  final Map<String, int> killsByEnemy;

  /// Item ids the player has ever picked up, for bestiary loot reveals.
  final Set<String> discoveredItems;

  LocationDef get currentLocation => locationById(currentLocationId);
  int killsIn(String locationId) => killsByLocation[locationId] ?? 0;
  int killsOf(String enemyId) => killsByEnemy[enemyId] ?? 0;
  bool hasSeen(String enemyId) => killsOf(enemyId) > 0;

  ProgressState copyWith({
    String? currentLocationId,
    Map<String, int>? killsByLocation,
    Map<String, int>? killsByEnemy,
    Set<String>? discoveredItems,
  }) => ProgressState(
    currentLocationId: currentLocationId ?? this.currentLocationId,
    killsByLocation: killsByLocation ?? this.killsByLocation,
    killsByEnemy: killsByEnemy ?? this.killsByEnemy,
    discoveredItems: discoveredItems ?? this.discoveredItems,
  );

  Map<String, dynamic> toJson() => {
    'currentLocationId': currentLocationId,
    'killsByLocation': killsByLocation,
    'killsByEnemy': killsByEnemy,
    'discoveredItems': discoveredItems.toList(),
  };

  static ProgressState fromJson(Map<String, dynamic> json) {
    Map<String, int> intMap(Object? raw) {
      if (raw is! Map) return const {};
      return {
        for (final e in raw.entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toInt(),
      };
    }

    final id = json['currentLocationId'] as String?;
    return ProgressState(
      currentLocationId: locationCatalog.containsKey(id)
          ? id!
          : startingLocationId,
      killsByLocation: intMap(json['killsByLocation']),
      killsByEnemy: intMap(json['killsByEnemy']),
      discoveredItems: {
        for (final v in (json['discoveredItems'] as List<dynamic>? ?? const []))
          if (v is String) v,
      },
    );
  }
}

class ProgressNotifier extends Notifier<ProgressState> {
  @override
  ProgressState build() {
    final saved = savedSection(ref, 'progress');
    return saved == null
        ? const ProgressState()
        : ProgressState.fromJson(saved);
  }

  /// Records one kill against both the location and the bestiary counters.
  void recordKill(String enemyId) {
    final locId = state.currentLocationId;
    state = state.copyWith(
      killsByLocation: {
        ...state.killsByLocation,
        locId: state.killsIn(locId) + 1,
      },
      killsByEnemy: {
        ...state.killsByEnemy,
        enemyId: state.killsOf(enemyId) + 1,
      },
    );
  }

  void discoverItems(Iterable<String> itemIds) {
    final missing = itemIds.where((id) => !state.discoveredItems.contains(id));
    if (missing.isEmpty) return;
    state = state.copyWith(
      discoveredItems: {...state.discoveredItems, ...missing},
    );
  }

  /// Returns to the grove. Bestiary discoveries survive the fire.
  void resetForAscension() {
    state = ProgressState(discoveredItems: state.discoveredItems);
  }

  /// Switches farming target. Returns false when the node is still locked.
  bool travelTo(String locationId) {
    if (locationId == state.currentLocationId) return true;
    if (!isUnlocked(locationId)) return false;
    state = state.copyWith(currentLocationId: locationId);
    return true;
  }

  bool isUnlocked(String locationId) {
    final def = locationCatalog[locationId];
    if (def == null) return false;
    if (ref.read(playerProvider).level < def.unlockLevel) return false;
    return def.requires.every((id) => state.killsIn(id) >= def.unlockKills);
  }

  /// Human readable gate description, or null when already unlocked.
  String? lockReason(String locationId) {
    final def = locationCatalog[locationId];
    if (def == null) return 'Unknown location';
    final l10n = ref.read(l10nProvider);
    final level = ref.read(playerProvider).level;
    if (level < def.unlockLevel) {
      return l10n.t('ui.reachLevel', {'n': '${def.unlockLevel}'});
    }
    for (final id in def.requires) {
      final have = state.killsIn(id);
      if (have < def.unlockKills) {
        return l10n.t('ui.killsIn', {
          'have': '$have',
          'need': '${def.unlockKills}',
          'location': l10n.locationName(id),
        });
      }
    }
    return null;
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(
  ProgressNotifier.new,
);

/// Current location, watched by the top bar and the renderer.
final currentLocationProvider = Provider<LocationDef>(
  (ref) => ref.watch(progressProvider).currentLocation,
);

/// Unlock state of every map node, recomputed when level or kills change.
final locationUnlocksProvider = Provider<Map<String, String?>>((ref) {
  final progress = ref.watch(progressProvider);
  final level = ref.watch(playerProvider).level;
  final l10n = ref.watch(l10nProvider);
  final out = <String, String?>{};
  for (final def in allLocations) {
    String? reason;
    if (level < def.unlockLevel) {
      reason = l10n.t('ui.reachLevel', {'n': '${def.unlockLevel}'});
    } else {
      for (final id in def.requires) {
        final have = progress.killsIn(id);
        if (have < def.unlockKills) {
          reason = l10n.t('ui.killsIn', {
            'have': '$have',
            'need': '${def.unlockKills}',
            'location': l10n.locationName(id),
          });
          break;
        }
      }
    }
    out[def.id] = reason;
  }
  return out;
});

/// Bestiary completion, used for the tab badge.
final bestiaryProgressProvider = Provider<({int seen, int total})>((ref) {
  final progress = ref.watch(progressProvider);
  final total = enemyCatalog.length;
  final seen = enemyCatalog.keys.where(progress.hasSeen).length;
  return (seen: seen, total: total);
});

/// Item the player is currently farming for, set from the crafting screen.
class LootTargetNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setTarget(String? itemId) => state = itemId;
  void clear() => state = null;
}

final lootTargetProvider = NotifierProvider<LootTargetNotifier, String?>(
  LootTargetNotifier.new,
);
