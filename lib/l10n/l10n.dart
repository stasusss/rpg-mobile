import '../data/enemies_data.dart';
import '../data/items_data.dart';
import '../data/locations_data.dart';
import '../data/skills_data.dart';
import '../models/combat_event.dart';
import '../models/item.dart';
import '../models/item_set.dart';
import '../models/skill.dart';
import '../models/stats.dart';
import '../models/status_effect.dart';
import 'app_locale.dart';
import 'strings_catalog.dart';
import 'strings_ui.dart';

/// Looks up UI chrome, catalogue copy and combat lines for one [locale].
///
/// English names on the data models are the fallback so a missing key never
/// blanks the HUD. Ukrainian entries live in the dictionary maps.
class L10n {
  const L10n(this.locale);

  final AppLocale locale;

  static const L10n english = L10n(AppLocale.en);

  Map<String, String> get _ui =>
      locale == AppLocale.uk ? ukUiStrings : enUiStrings;

  Map<String, (String, String)> get _items =>
      locale == AppLocale.uk ? ukItems : enItems;

  Map<String, (String, String)> get _enemies =>
      locale == AppLocale.uk ? ukEnemies : enEnemies;

  Map<String, (String, String, String)> get _locations =>
      locale == AppLocale.uk ? ukLocations : enLocations;

  Map<String, (String, String)> get _skills =>
      locale == AppLocale.uk ? ukSkills : enSkills;

  /// Interpolates `{name}` placeholders from [args].
  String t(String key, [Map<String, String>? args]) {
    var value = _ui[key] ?? enUiStrings[key] ?? key;
    if (args != null) {
      for (final e in args.entries) {
        value = value.replaceAll('{${e.key}}', e.value);
      }
    }
    return value;
  }

  String itemName(String id) =>
      _items[id]?.$1 ?? enItems[id]?.$1 ?? tryItemById(id)?.name ?? id;

  String itemDesc(String id) =>
      _items[id]?.$2 ?? enItems[id]?.$2 ?? tryItemById(id)?.description ?? '';

  String enemyName(String id) =>
      _enemies[id]?.$1 ?? enEnemies[id]?.$1 ?? enemyCatalog[id]?.name ?? id;

  String enemyDesc(String id) =>
      _enemies[id]?.$2 ??
      enEnemies[id]?.$2 ??
      enemyCatalog[id]?.description ??
      '';

  String locationName(String id) =>
      _locations[id]?.$1 ??
      enLocations[id]?.$1 ??
      locationCatalog[id]?.name ??
      id;

  String locationRegion(String id) =>
      _locations[id]?.$2 ??
      enLocations[id]?.$2 ??
      locationCatalog[id]?.region ??
      '';

  String locationDesc(String id) =>
      _locations[id]?.$3 ??
      enLocations[id]?.$3 ??
      locationCatalog[id]?.description ??
      '';

  String skillName(String id) =>
      _skills[id]?.$1 ??
      enSkills[id]?.$1 ??
      trySkillById(id)?.name ??
      id;

  String skillDesc(String id) =>
      _skills[id]?.$2 ??
      enSkills[id]?.$2 ??
      trySkillById(id)?.description ??
      '';

  String statusName(StatusId id) => t('status.${id.name}');

  String statusDesc(StatusId id) => t('status.${id.name}Desc');

  String slot(EquipSlot slot) => t('slot.${slot.name}');

  String rarity(ItemRarity rarity) => t('rarity.${rarity.name}');

  String kind(ItemKind kind) => t('kind.${kind.name}');

  String attribute(Attribute attr) => t('attr.${attr.name}');

  String attributeShort(Attribute attr) => t('attr.${attr.name}.short');

  String attributeBlurb(Attribute attr) => t('attr.${attr.name}.blurb');

  String stat(StatKey key) => t('stat.${key.name}');

  String branch(SkillBranch branch) => t('branch.${branch.name}');

  String skillKind(SkillNodeKind kind) => t('skillKind.${kind.name}');

  String itemSet(ItemSetId id) => t('set.${id.name}');

  String itemSetBonus(ItemSetId id, int pieces) => t('set.${id.name}.$pieces');

  String region(String regionName) => switch (regionName) {
    'The Ash Pilgrim' => t('region.ash_pilgrim'),
    'The Greenway' => t('region.greenway'),
    'Ashen Frontier' => t('region.ashen'),
    'Undervault' => t('region.undervault'),
    'Drowned Halls' => t('region.drowned'),
    'The Caldera' => t('region.caldera'),
    _ => regionName,
  };

  /// Rebuilds a stored activity line in the current language.
  String activity(ActivityEntry entry) {
    final resolved = <String, String>{};
    for (final e in entry.args.entries) {
      resolved[e.key] = switch (e.key) {
        'item' => itemName(e.value),
        'enemy' => enemyName(e.value),
        'location' => locationName(e.value),
        'skill' => skillName(e.value),
        _ => e.value,
      };
    }
    return t(entry.key, resolved);
  }

  List<String> describeBundle(StatBundle bundle) {
    final lines = <String>[];
    for (final key in StatKey.values) {
      final f = bundle.flat[key];
      if (f != null && f != 0) {
        lines.add('${_sign(f)}${_fmtFlat(key, f)}');
      }
      final p = bundle.pct[key];
      if (p != null && p != 0) {
        lines.add('${_sign(p)}${(p * 100).toStringAsFixed(0)}% ${stat(key)}');
      }
    }
    return lines;
  }

  String _sign(double v) => v < 0 ? '-' : '+';

  String _fmtFlat(StatKey key, double v) {
    final a = v.abs();
    if (key.fractional) {
      return '${_trim(a * 100)}% ${stat(key)}';
    }
    return '${_trim(a)} ${stat(key)}';
  }

  static String _trim(double v) {
    if ((v - v.roundToDouble()).abs() < 0.005) return v.round().toString();
    return v.toStringAsFixed(2);
  }
}

/// Labels the Flame viewport uses for one-shot floating text.
class CombatFxLabels {
  const CombatFxLabels({
    required this.miss,
    required this.dodge,
    required this.levelUp,
    required this.defeated,
    required this.skill,
  });

  factory CombatFxLabels.from(L10n l10n) => CombatFxLabels(
    miss: l10n.t('fx.miss'),
    dodge: l10n.t('fx.dodge'),
    levelUp: l10n.t('fx.levelUp'),
    defeated: l10n.t('fx.defeated'),
    skill: l10n.t('fx.skill'),
  );

  final String miss;
  final String dodge;
  final String levelUp;
  final String defeated;
  final String skill;
}
