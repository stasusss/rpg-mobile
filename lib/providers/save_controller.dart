import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats.dart';
import 'achievements_provider.dart';
import 'combat_provider.dart';
import 'inventory_provider.dart';
import 'player_provider.dart';
import 'prestige_provider.dart';
import 'progress_provider.dart';
import 'save_provider.dart';
import 'settings_provider.dart';
import 'skill_loadout_provider.dart';
import 'skills_provider.dart';
import 'time_controller.dart';

/// Writes a debounced snapshot of every persistent slice of state.
///
/// Combat HP and the current spawn are excluded: they are transient, and
/// persisting them would write 20 times a second.
class SaveController {
  SaveController._(this._flushNow);

  final Future<void> Function() _flushNow;

  /// Writes immediately. Used after crafts and when the app backgrounds.
  Future<void> flushNow() => _flushNow();
}

bool _playerNeedsFastSave(PlayerState? previous, PlayerState next) {
  if (previous == null) return true;
  if (previous.level != next.level ||
      previous.xp != next.xp ||
      previous.gold != next.gold ||
      previous.gems != next.gems ||
      previous.attributePoints != next.attributePoints ||
      previous.skillPoints != next.skillPoints ||
      previous.totalKills != next.totalKills ||
      previous.deaths != next.deaths ||
      previous.itemsCrafted != next.itemsCrafted) {
    return true;
  }
  for (final attr in Attribute.values) {
    if ((previous.allocated[attr] ?? 0) != (next.allocated[attr] ?? 0)) {
      return true;
    }
  }
  return false;
}

/// Subscribes to gameplay providers and keeps the save blob current.
///
/// Section JSON is cached as listeners fire rather than re-read on write,
/// because Riverpod forbids touching `ref` from inside lifecycle callbacks.
///
/// `hitsDealt` / `damageTaken` / play time update the cached player slice
/// without resetting the 2-second debounce. Combat flushes those counters
/// every 15 seconds or on a kill; [flushNow] still writes the latest cache.
final saveControllerProvider = Provider<SaveController>((ref) {
  final store = ref.read(saveStoreProvider);
  final sections = <String, dynamic>{};
  Timer? debounce;
  Future<void>? inFlight;

  Future<void> flush() async {
    if (sections.isEmpty) return;
    final payload = {
      'version': 1,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      ...sections,
    };
    final write = store.save(payload);
    inFlight = write;
    await write;
    if (identical(inFlight, write)) inFlight = null;
  }

  void record(String key, Object value, {bool debounceWrite = true}) {
    sections[key] = value;
    if (!debounceWrite) return;
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () {
      unawaited(flush());
    });
  }

  ref.listen(playerProvider, (previous, next) {
    record(
      'player',
      next.toJson(),
      debounceWrite: _playerNeedsFastSave(previous, next),
    );
  }, fireImmediately: true);
  ref.listen(
    inventoryProvider,
    (_, next) => record('inventory', next.toJson()),
    fireImmediately: true,
  );
  ref.listen(
    skillsProvider,
    (_, next) => record('skills', Map<String, dynamic>.of(next)),
    fireImmediately: true,
  );
  ref.listen(
    progressProvider,
    (_, next) => record('progress', next.toJson()),
    fireImmediately: true,
  );
  ref.listen(
    settingsProvider,
    (_, next) => record('settings', next.toJson()),
    fireImmediately: true,
  );
  ref.listen(
    timeControllerProvider,
    (_, next) => record('time', next.toJson()),
    fireImmediately: true,
  );
  ref.listen(
    skillLoadoutProvider,
    (_, next) => record('loadout', next.toJson()),
    fireImmediately: true,
  );
  ref.listen(
    prestigeProvider,
    (_, next) => record('prestige', next.toJson()),
    fireImmediately: true,
  );
  ref.listen(
    achievementsProvider,
    (_, next) => record('achievements', next.toJson()),
    fireImmediately: true,
  );

  ref.onDispose(() {
    debounce?.cancel();
    unawaited(flush());
  });

  return SaveController._(() async {
    debounce?.cancel();
    await flush();
  });
});

/// Wipes the save and resets every gameplay provider.
///
/// Exposed as a provider so widgets can trigger it with a `WidgetRef`.
final resetGameProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await ref.read(saveStoreProvider).wipe();
    ref.read(savedGameProvider.notifier).clear();
    ref.read(combatEventBusProvider).clear();
    ref.invalidate(playerProvider);
    ref.invalidate(inventoryProvider);
    ref.invalidate(skillsProvider);
    ref.invalidate(progressProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(timeControllerProvider);
    ref.invalidate(skillLoadoutProvider);
    ref.invalidate(prestigeProvider);
    ref.invalidate(achievementsProvider);
    ref.invalidate(combatProvider);
  },
);
