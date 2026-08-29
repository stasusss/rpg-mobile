import 'package:flutter/foundation.dart';

/// Action-based mastery. Counters come from combat; levels feed the sheet.
@immutable
class ActionMastery {
  const ActionMastery({
    required this.hitsDealt,
    required this.damageTaken,
    required this.enemiesKilled,
  });

  final int hitsDealt;
  final int damageTaken;
  final int enemiesKilled;

  int get weaponMastery => masteryLevel(hitsDealt, hitsForNextWeapon);
  int get armorMastery => masteryLevel(damageTaken, damageForNextArmor);
  int get characterRank => masteryLevel(enemiesKilled, killsForNextRank);

  int get hitsIntoLevel => progressInto(hitsDealt, hitsForNextWeapon);
  int get hitsNeeded => hitsForNextWeapon(weaponMastery + 1);

  int get damageIntoLevel => progressInto(damageTaken, damageForNextArmor);
  int get damageNeeded => damageForNextArmor(armorMastery + 1);

  int get killsIntoLevel => progressInto(enemiesKilled, killsForNextRank);
  int get killsNeeded => killsForNextRank(characterRank + 1);

  /// Hits to go from [level]-1 to [level].
  static int hitsForNextWeapon(int level) => 50 + level * 25;

  /// Rounded incoming damage to go from [level]-1 to [level].
  static int damageForNextArmor(int level) => 80 + level * 40;

  /// Kills to go from [level]-1 to [level].
  static int killsForNextRank(int level) => 8 + level * 6;

  static int masteryLevel(int total, int Function(int) costFor) {
    var remaining = total;
    var level = 0;
    while (level < 200) {
      final need = costFor(level + 1);
      if (remaining < need) return level;
      remaining -= need;
      level++;
    }
    return level;
  }

  static int progressInto(int total, int Function(int) costFor) {
    var remaining = total;
    var level = 0;
    while (level < 200) {
      final need = costFor(level + 1);
      if (remaining < need) return remaining;
      remaining -= need;
      level++;
    }
    return remaining;
  }

  /// Total actions required to *reach* [level] from zero.
  static int cumulative(int level, int Function(int) costFor) {
    var sum = 0;
    for (var i = 1; i <= level; i++) {
      sum += costFor(i);
    }
    return sum;
  }
}
