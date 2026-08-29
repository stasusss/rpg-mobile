import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_locale.dart';
import '../../models/item.dart';
import '../../models/item_set.dart';
import '../../models/stats.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/achievements_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/player_stats_provider.dart';
import '../../providers/prestige_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/save_controller.dart';
import '../../providers/settings_provider.dart';
import '../../providers/skills_provider.dart';
import '../../providers/stats_provider.dart';
import '../hubs/altar_sheet.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Character sheet, action mastery, gem shop and automation settings.
class StatsTab extends ConsumerWidget {
  const StatsTab({super.key, this.settingsOnly = false});

  final bool settingsOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: settingsOnly
          ? const [
              _LanguageCard(),
              SizedBox(height: 14),
              _GemShopCard(),
              SizedBox(height: 14),
              _AutomationCard(),
              SizedBox(height: 14),
              _DangerZone(),
            ]
          : const [
              AltarEntryCard(),
              SizedBox(height: 14),
              _MasteryCard(),
              SizedBox(height: 14),
              _SetBonusCard(),
              SizedBox(height: 14),
              _DerivedStatsCard(),
              SizedBox(height: 14),
              _LifetimeCard(),
            ],
    );
  }
}

class _LanguageCard extends ConsumerWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final l10n = ref.watch(l10nProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.t('ui.language'), icon: Icons.translate),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('ui.languageHint'),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final option in AppLocale.values) ...[
                    if (option != AppLocale.values.first)
                      const SizedBox(width: 8),
                    Expanded(
                      child: _LocaleChip(
                        label: option.nativeLabel,
                        selected: locale == option,
                        onTap: () =>
                            ref.read(localeProvider.notifier).setLocale(option),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocaleChip extends StatelessWidget {
  const _LocaleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.18)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.gold : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _MasteryCard extends ConsumerWidget {
  const _MasteryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mastery = ref.watch(playerStatsProvider);
    final stats = ref.watch(combatStatsProvider);
    final l10n = ref.watch(l10nProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.t('ui.mastery'), icon: Icons.trending_up),
        Panel(
          child: Column(
            children: [
              _MasteryTrack(
                title: l10n.t('ui.weaponMastery'),
                levelLabel: l10n.t('ui.masteryLevel', {
                  'n': '${mastery.weaponMastery}',
                }),
                progressLabel: l10n.t('ui.hitsToNext', {
                  'have': '${mastery.hitsIntoLevel}',
                  'need': '${mastery.hitsNeeded}',
                }),
                fraction: mastery.hitsNeeded == 0
                    ? 1
                    : mastery.hitsIntoLevel / mastery.hitsNeeded,
                color: AppColors.gold,
              ),
              const SizedBox(height: 10),
              _MasteryTrack(
                title: l10n.t('ui.armorMastery'),
                levelLabel: l10n.t('ui.masteryLevel', {
                  'n': '${mastery.armorMastery}',
                }),
                progressLabel: l10n.t('ui.damageToNext', {
                  'have': '${mastery.damageIntoLevel}',
                  'need': '${mastery.damageNeeded}',
                }),
                fraction: mastery.damageNeeded == 0
                    ? 1
                    : mastery.damageIntoLevel / mastery.damageNeeded,
                color: AppColors.info,
              ),
              const SizedBox(height: 10),
              _MasteryTrack(
                title: l10n.t('ui.characterRank'),
                levelLabel: l10n.t('ui.masteryLevel', {
                  'n': '${mastery.characterRank}',
                }),
                progressLabel: l10n.t('ui.killsToNext', {
                  'have': '${mastery.killsIntoLevel}',
                  'need': '${mastery.killsNeeded}',
                }),
                fraction: mastery.killsNeeded == 0
                    ? 1
                    : mastery.killsIntoLevel / mastery.killsNeeded,
                color: AppColors.success,
              ),
              const Divider(height: 16),
              for (final attr in Attribute.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          l10n.attributeShort(attr),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l10n.attribute(attr),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Text(
                        '${stats.attributes[attr] ?? 0}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MasteryTrack extends StatelessWidget {
  const _MasteryTrack({
    required this.title,
    required this.levelLabel,
    required this.progressLabel,
    required this.fraction,
    required this.color,
  });

  final String title;
  final String levelLabel;
  final String progressLabel;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            Text(
              levelLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        StatBar(fraction: fraction, color: color, height: 7),
        const SizedBox(height: 3),
        Text(
          progressLabel,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _SetBonusCard extends ConsumerWidget {
  const _SetBonusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(setBonusProvider);
    final l10n = ref.watch(l10nProvider);
    final active = sets.where((s) => s.equipped > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.t('ui.setBonuses'), icon: Icons.style),
        Panel(
          child: active.isEmpty
              ? Text(
                  l10n.t('ui.noSetBonus'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textFaint,
                  ),
                )
              : Column(
                  children: [
                    for (final progress in active)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SetProgressRow(progress: progress),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SetProgressRow extends ConsumerWidget {
  const _SetProgressRow({required this.progress});

  final SetProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final color = progress.def.id.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.itemSet(progress.def.id),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            Text(
              l10n.t('ui.setPieces', {
                'have': '${progress.equipped}',
                'max': '${progress.max}',
              }),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        StatBar(
          fraction: progress.max == 0 ? 0 : progress.equipped / progress.max,
          color: color,
          height: 6,
        ),
        if (progress.hasTwo)
          Text(
            '${l10n.t('ui.setActive2')} · ${l10n.itemSetBonus(progress.def.id, 2)}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.success),
          ),
        if (progress.hasFour)
          Text(
            '${l10n.t('ui.setActive4')} · ${l10n.itemSetBonus(progress.def.id, 4)}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.gold),
          ),
      ],
    );
  }
}

class _DerivedStatsCard extends ConsumerWidget {
  const _DerivedStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(combatStatsProvider);
    final l10n = ref.watch(l10nProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.t('ui.combatSheet'), icon: Icons.shield_outlined),
        Panel(
          child: Column(
            children: [
              StatLine(
                label: l10n.t('ui.damagePerHit'),
                value:
                    '${formatStat(s.damageMin)} – ${formatStat(s.damageMax)}',
              ),
              StatLine(
                label: l10n.t('ui.magicDamage'),
                value: formatStat(s.magicDamage),
              ),
              StatLine(
                label: l10n.t('ui.fireDamage'),
                value: formatStat(s.fireDamage),
              ),
              StatLine(
                label: l10n.t('ui.aps'),
                value: formatStat(s.attackSpeed),
              ),
              StatLine(
                label: l10n.t('ui.dps'),
                value: formatCount(s.dps),
                valueColor: AppColors.gold,
              ),
              const Divider(height: 14),
              StatLine(label: l10n.t('ui.maxHp'), value: formatCount(s.maxHp)),
              StatLine(
                label: l10n.t('ui.hpRegen'),
                value: formatStat(s.hpRegen),
              ),
              StatLine(
                label: l10n.t('ui.maxMana'),
                value: formatCount(s.maxMana),
              ),
              StatLine(
                label: l10n.t('ui.manaRegen'),
                value: formatStat(s.manaRegen),
              ),
              StatLine(label: l10n.t('ui.armor'), value: formatStat(s.armor)),
              StatLine(
                label: l10n.t('ui.fireResist'),
                value: formatPercent(s.fireResist),
              ),
              StatLine(
                label: l10n.t('ui.damageTaken'),
                value: formatPercent(s.damageTaken),
              ),
              StatLine(
                label: l10n.t('ui.dodge'),
                value: formatPercent(s.dodge),
              ),
              const Divider(height: 14),
              StatLine(
                label: l10n.t('ui.critChance'),
                value: formatPercent(s.crit),
              ),
              StatLine(
                label: l10n.t('ui.critDamage'),
                value: formatPercent(s.critMultiplier, decimals: 0),
              ),
              StatLine(
                label: l10n.t('ui.lifeSteal'),
                value: formatPercent(s.lifeSteal),
              ),
              const Divider(height: 14),
              StatLine(
                label: l10n.t('ui.goldFind'),
                value: formatPercent(s.goldFind, decimals: 0),
              ),
              StatLine(
                label: l10n.t('ui.xpGain'),
                value: formatPercent(s.xpGain, decimals: 0),
              ),
              StatLine(
                label: l10n.t('ui.lootFind'),
                value: formatPercent(s.lootFind, decimals: 0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GemShopCard extends ConsumerWidget {
  const _GemShopCard();

  static const int bagCost = 25;
  static const int skillRespecCost = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gems = ref.watch(playerProvider.select((p) => p.gems));
    final capacity = ref.watch(inventoryProvider.select((i) => i.capacity));
    final free = ref.watch(settingsProvider.select((s) => s.developerFreeMode));
    final l10n = ref.watch(l10nProvider);
    final bagPrice = free ? 0 : bagCost;
    final respecPrice = free ? 0 : skillRespecCost;

    void purchase(int cost, VoidCallback effect, String message) {
      if (cost > 0 && !ref.read(playerProvider.notifier).spendGems(cost)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('ui.notEnoughGems'))));
        return;
      }
      effect();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          l10n.t('ui.gemExchange'),
          icon: Icons.diamond_outlined,
          trailing: ResourceChip(
            icon: Icons.diamond,
            value: formatCount(gems),
            color: AppColors.gem,
          ),
        ),
        Panel(
          child: Column(
            children: [
              _ShopRow(
                title: l10n.t('ui.expandBag'),
                subtitle: l10n.t('ui.bagSlots', {'n': '$capacity'}),
                cost: bagPrice,
                affordable: free || gems >= bagPrice,
                onBuy: () => purchase(
                  bagPrice,
                  () => ref.read(inventoryProvider.notifier).expandCapacity(12),
                  l10n.t('ui.bagExpanded'),
                ),
              ),
              const Divider(height: 14),
              _ShopRow(
                title: l10n.t('ui.resetSkills'),
                subtitle: l10n.t('ui.resetSkillsHint'),
                cost: respecPrice,
                affordable: free || gems >= respecPrice,
                onBuy: () => purchase(
                  respecPrice,
                  () => ref.read(skillsProvider.notifier).respec(),
                  l10n.t('ui.skillsRefunded'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.title,
    required this.subtitle,
    required this.cost,
    required this.affordable,
    required this.onBuy,
  });

  final String title;
  final String subtitle;
  final int cost;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 28,
          child: OutlinedButton.icon(
            onPressed: affordable ? onBuy : null,
            icon: const Icon(Icons.diamond, size: 12, color: AppColors.gem),
            label: Text('$cost'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _AutomationCard extends ConsumerWidget {
  const _AutomationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = ref.watch(l10nProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.t('ui.automation'), icon: Icons.settings_suggest),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              _ToggleRow(
                title: l10n.t('ui.autoEquip'),
                subtitle: l10n.t('ui.autoEquipHint'),
                value: settings.autoEquipUpgrades,
                onChanged: (_) => notifier.toggleAutoEquip(),
              ),
              _ToggleRow(
                title: l10n.t('ui.autoSell'),
                subtitle: l10n.t('ui.autoSellHint'),
                value: settings.autoSellEnabled,
                onChanged: (_) => notifier.toggleAutoSell(),
              ),
              if (settings.autoSellEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        l10n.t('ui.sellUpTo'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (final rarity in ItemRarity.values.take(4))
                              _RarityChip(
                                rarity: rarity,
                                selected: settings.autoSellRarity == rarity,
                                onTap: () => notifier.setAutoSellRarity(rarity),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              _ToggleRow(
                title: l10n.t('ui.autoPotion'),
                subtitle: l10n.t('ui.autoPotionHint'),
                value: settings.autoPotion,
                onChanged: (_) => notifier.toggleAutoPotion(),
              ),
              _ToggleRow(
                title: l10n.t('ui.damageNumbers'),
                subtitle: l10n.t('ui.damageNumbersHint'),
                value: settings.showDamageNumbers,
                onChanged: (_) => notifier.toggleDamageNumbers(),
              ),
              _VolumeRow(
                title: l10n.t('ui.sfxVolume'),
                value: settings.sfxVolume,
                onChanged: notifier.setSfxVolume,
              ),
              _VolumeRow(
                title: l10n.t('ui.bgmVolume'),
                value: settings.bgmVolume,
                onChanged: notifier.setBgmVolume,
              ),
              _ToggleRow(
                title: l10n.t('ui.devFreeMode'),
                subtitle: l10n.t('ui.devFreeModeHint'),
                value: settings.developerFreeMode,
                onChanged: (_) => notifier.toggleDeveloperFreeMode(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.gold,
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.gold,
        ),
      ],
    );
  }
}

class _RarityChip extends ConsumerWidget {
  const _RarityChip({
    required this.rarity,
    required this.selected,
    required this.onTap,
  });

  final ItemRarity rarity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(l10nProvider).rarity(rarity);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? rarity.color.withValues(alpha: 0.22)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? rarity.color : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? rarity.color : AppColors.textFaint,
          ),
        ),
      ),
    );
  }
}

class _LifetimeCard extends ConsumerWidget {
  const _LifetimeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final progress = ref.watch(progressProvider);
    final bestiary = ref.watch(bestiaryProgressProvider);
    final chronicle = ref.watch(achievementsProvider);
    final souls = ref.watch(prestigeProvider.select((p) => p.ashSouls));
    final l10n = ref.watch(l10nProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.t('ui.record'), icon: Icons.emoji_events_outlined),
        Panel(
          child: Column(
            children: [
              StatLine(
                label: l10n.t('ui.ashSouls'),
                value: formatCount(souls),
              ),
              StatLine(
                label: l10n.t('ui.lifetimeKills'),
                value: formatCount(chronicle.lifetimeKills),
              ),
              StatLine(
                label: l10n.t('ui.lifetimeGold'),
                value: formatCount(chronicle.lifetimeGold),
              ),
              StatLine(
                label: l10n.t('ui.lifetimePrestiges'),
                value: formatCount(chronicle.lifetimePrestiges),
              ),
              StatLine(
                label: l10n.t('ui.lifetimeBosses'),
                value: formatCount(chronicle.lifetimeBosses),
              ),
              StatLine(
                label: l10n.t('ui.totalKills'),
                value: formatCount(player.totalKills),
              ),
              StatLine(
                label: l10n.t('ui.deaths'),
                value: formatCount(player.deaths),
              ),
              StatLine(
                label: l10n.t('ui.bestiary'),
                value: '${bestiary.seen}/${bestiary.total}',
              ),
              StatLine(
                label: l10n.t('ui.matsFound'),
                value: '${progress.discoveredItems.length}',
              ),
              StatLine(
                label: l10n.t('ui.timePlayed'),
                value: formatDuration(player.playSeconds),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DangerZone extends ConsumerWidget {
  const _DangerZone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirm(context, ref),
        icon: const Icon(Icons.restart_alt, size: 15),
        label: Text(l10n.t('ui.resetProgress')),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.hp,
          side: BorderSide(color: AppColors.hp.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = ref.read(l10nProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('ui.resetTitle')),
        content: Text(l10n.t('ui.resetBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('ui.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.hp),
            child: Text(l10n.t('ui.reset')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(resetGameProvider)();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('ui.progressReset'))));
    }
  }
}
