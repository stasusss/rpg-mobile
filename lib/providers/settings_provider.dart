import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';
import '../models/item.dart';
import 'save_provider.dart';

/// Idle-game quality of life toggles.
@immutable
class GameSettings {
  const GameSettings({
    this.autoEquipUpgrades = true,
    this.autoSellRarity = ItemRarity.common,
    this.autoSellEnabled = false,
    this.autoPotion = true,
    this.showDamageNumbers = true,
    this.developerFreeMode = false,
    this.sfxVolume = 0.75,
    this.bgmVolume = 0.4,
    this.locale = AppLocale.en,
  });

  /// Automatically equip dropped gear that scores higher than what's worn.
  final bool autoEquipUpgrades;

  /// Sell dropped equipment at or below this rarity on pickup.
  final ItemRarity autoSellRarity;
  final bool autoSellEnabled;

  /// Drink a potion automatically when HP drops below 30%.
  final bool autoPotion;
  final bool showDamageNumbers;

  /// Shop rows cost 0 gold and 0 gems. For testing drops and time-skips.
  final bool developerFreeMode;

  /// UI language. Changing it rebuilds every widget that watches [l10nProvider].
  final AppLocale locale;

  /// 0..1 mixer levels persisted with the rest of settings.
  final double sfxVolume;
  final double bgmVolume;

  GameSettings copyWith({
    bool? autoEquipUpgrades,
    ItemRarity? autoSellRarity,
    bool? autoSellEnabled,
    bool? autoPotion,
    bool? showDamageNumbers,
    bool? developerFreeMode,
    double? sfxVolume,
    double? bgmVolume,
    AppLocale? locale,
  }) => GameSettings(
    autoEquipUpgrades: autoEquipUpgrades ?? this.autoEquipUpgrades,
    autoSellRarity: autoSellRarity ?? this.autoSellRarity,
    autoSellEnabled: autoSellEnabled ?? this.autoSellEnabled,
    autoPotion: autoPotion ?? this.autoPotion,
    showDamageNumbers: showDamageNumbers ?? this.showDamageNumbers,
    developerFreeMode: developerFreeMode ?? this.developerFreeMode,
    sfxVolume: sfxVolume ?? this.sfxVolume,
    bgmVolume: bgmVolume ?? this.bgmVolume,
    locale: locale ?? this.locale,
  );

  Map<String, dynamic> toJson() => {
    'autoEquipUpgrades': autoEquipUpgrades,
    'autoSellRarity': autoSellRarity.name,
    'autoSellEnabled': autoSellEnabled,
    'autoPotion': autoPotion,
    'showDamageNumbers': showDamageNumbers,
    'developerFreeMode': developerFreeMode,
    'sfxVolume': sfxVolume,
    'bgmVolume': bgmVolume,
    'locale': locale.code,
  };

  static GameSettings fromJson(Map<String, dynamic> json) => GameSettings(
    autoEquipUpgrades: json['autoEquipUpgrades'] as bool? ?? true,
    autoSellRarity: ItemRarity.values.firstWhere(
      (r) => r.name == json['autoSellRarity'],
      orElse: () => ItemRarity.common,
    ),
    autoSellEnabled: json['autoSellEnabled'] as bool? ?? false,
    autoPotion: json['autoPotion'] as bool? ?? true,
    showDamageNumbers: json['showDamageNumbers'] as bool? ?? true,
    developerFreeMode: json['developerFreeMode'] as bool? ?? false,
    sfxVolume: ((json['sfxVolume'] as num?)?.toDouble() ?? 0.75).clamp(0.0, 1.0),
    bgmVolume: ((json['bgmVolume'] as num?)?.toDouble() ?? 0.4).clamp(0.0, 1.0),
    locale: AppLocale.fromCode(json['locale'] as String?),
  );
}

class SettingsNotifier extends Notifier<GameSettings> {
  @override
  GameSettings build() {
    final saved = savedSection(ref, 'settings');
    return saved == null ? const GameSettings() : GameSettings.fromJson(saved);
  }

  void toggleAutoEquip() =>
      state = state.copyWith(autoEquipUpgrades: !state.autoEquipUpgrades);

  void toggleAutoSell() =>
      state = state.copyWith(autoSellEnabled: !state.autoSellEnabled);

  void toggleAutoPotion() =>
      state = state.copyWith(autoPotion: !state.autoPotion);

  void toggleDamageNumbers() =>
      state = state.copyWith(showDamageNumbers: !state.showDamageNumbers);

  void toggleDeveloperFreeMode() =>
      state = state.copyWith(developerFreeMode: !state.developerFreeMode);

  void setAutoSellRarity(ItemRarity rarity) =>
      state = state.copyWith(autoSellRarity: rarity);

  void setLocale(AppLocale locale) => state = state.copyWith(locale: locale);

  void setSfxVolume(double value) =>
      state = state.copyWith(sfxVolume: value.clamp(0.0, 1.0));

  void setBgmVolume(double value) =>
      state = state.copyWith(bgmVolume: value.clamp(0.0, 1.0));
}

final settingsProvider = NotifierProvider<SettingsNotifier, GameSettings>(
  SettingsNotifier.new,
);
