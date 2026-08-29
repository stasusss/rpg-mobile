import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../data/achievements_data.dart';
import '../models/achievement.dart';
import 'prestige_provider.dart';
import 'save_provider.dart';

/// Lifetime chronicle. Survives Altar of Rebirth; wiped only by a full reset.
class AchievementsNotifier extends Notifier<AchievementState> {
  @override
  AchievementState build() {
    final saved = savedSection(ref, 'achievements');
    if (saved != null) return AchievementState.fromJson(saved);
    // Existing mid-run saves start with this life's kills already counted.
    final player = savedSection(ref, 'player');
    final kills = (player?['totalKills'] as num?)?.toInt() ?? 0;
    return AchievementState(lifetimeKills: kills);
  }

  void recordKill({required bool isBoss}) {
    state = state.copyWith(
      lifetimeKills: state.lifetimeKills + 1,
      lifetimeBosses: state.lifetimeBosses + (isBoss ? 1 : 0),
    );
    _unlockNew();
  }

  void recordGold(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(lifetimeGold: state.lifetimeGold + amount);
    _unlockNew();
  }

  void recordPrestige() {
    state = state.copyWith(lifetimePrestiges: state.lifetimePrestiges + 1);
    _unlockNew();
  }

  /// Moves queued milestone souls onto the caller (usually [PrestigeNotifier]).
  int takePendingSouls() {
    final pending = state.pendingAshSouls;
    if (pending <= 0) return 0;
    state = state.copyWith(pendingAshSouls: 0);
    return pending;
  }

  void _unlockNew() {
    var souls = 0;
    final unlocked = {...state.unlocked};
    for (final def in achievementCatalog) {
      if (unlocked.contains(def.id)) continue;
      if (!def.isMet(state)) continue;
      unlocked.add(def.id);
      souls += def.soulReward;
    }
    if (souls == 0 && unlocked.length == state.unlocked.length) return;
    state = state.copyWith(
      unlocked: unlocked,
      pendingAshSouls: state.pendingAshSouls + souls,
    );
    Future.microtask(() {
      if (!ref.mounted) return;
      ref.read(prestigeProvider.notifier).collectAchievementSouls();
    });
  }
}

final achievementsProvider =
    NotifierProvider<AchievementsNotifier, AchievementState>(
      AchievementsNotifier.new,
    );
