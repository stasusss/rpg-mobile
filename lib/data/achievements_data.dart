import '../models/achievement.dart';

/// Global milestones. Thresholds are lifetime totals across every pilgrimage.
const List<AchievementDef> achievementCatalog = [
  AchievementDef(
    id: 'kills_100',
    stat: AchievementStat.kills,
    threshold: 100,
    soulReward: 2,
  ),
  AchievementDef(
    id: 'kills_1000',
    stat: AchievementStat.kills,
    threshold: 1000,
    soulReward: 6,
  ),
  AchievementDef(
    id: 'kills_5000',
    stat: AchievementStat.kills,
    threshold: 5000,
    soulReward: 15,
  ),
  AchievementDef(
    id: 'gold_1000',
    stat: AchievementStat.gold,
    threshold: 1000,
    soulReward: 2,
  ),
  AchievementDef(
    id: 'gold_25000',
    stat: AchievementStat.gold,
    threshold: 25000,
    soulReward: 6,
  ),
  AchievementDef(
    id: 'gold_100000',
    stat: AchievementStat.gold,
    threshold: 100000,
    soulReward: 15,
  ),
  AchievementDef(
    id: 'prestiges_1',
    stat: AchievementStat.prestiges,
    threshold: 1,
    soulReward: 3,
  ),
  AchievementDef(
    id: 'prestiges_3',
    stat: AchievementStat.prestiges,
    threshold: 3,
    soulReward: 8,
  ),
  AchievementDef(
    id: 'prestiges_10',
    stat: AchievementStat.prestiges,
    threshold: 10,
    soulReward: 20,
  ),
  AchievementDef(
    id: 'bosses_1',
    stat: AchievementStat.bosses,
    threshold: 1,
    soulReward: 3,
  ),
  AchievementDef(
    id: 'bosses_10',
    stat: AchievementStat.bosses,
    threshold: 10,
    soulReward: 8,
  ),
  AchievementDef(
    id: 'bosses_25',
    stat: AchievementStat.bosses,
    threshold: 25,
    soulReward: 18,
  ),
];

AchievementDef? achievementById(String id) {
  for (final def in achievementCatalog) {
    if (def.id == id) return def;
  }
  return null;
}
