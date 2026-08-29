import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_manager.dart';
import '../../data/achievements_data.dart';
import '../../data/locations_data.dart';
import '../../models/achievement.dart';
import '../../models/prestige.dart';
import '../../providers/achievements_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/prestige_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/save_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

const Color _ember = Color(0xFFFF8A4C);

/// Opens the Altar of Rebirth: yield, confirmation, meta shop, chronicles.
Future<void> openAltarSheet({required BuildContext context}) {
  AudioManager.instance.play(SfxKind.click);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.82;
      return SizedBox(
        height: height,
        child: const Material(color: AppColors.background, child: AltarView()),
      );
    },
  );
}

/// Compact trigger used on the Hero sheet and the Growth perks page.
class AltarEntryCard extends ConsumerWidget {
  const AltarEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final souls = ref.watch(prestigeProvider.select((p) => p.ashSouls));
    final player = ref.watch(playerProvider);
    final progress = ref.watch(progressProvider);
    final yield_ = calculatePrestigeYield(
      highestLocationIndex: highestLocationIndexReached(progress),
      totalKills: player.totalKills,
      itemsCrafted: player.itemsCrafted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.t('ui.altarTitle'), icon: Icons.local_fire_department),
        Panel(
          key: const Key('altar-open'),
          onTap: () => openAltarSheet(context: context),
          borderColor: _ember.withValues(alpha: 0.45),
          child: Row(
            children: [
              const Icon(Icons.whatshot, color: _ember, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('ui.altarOpen'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('ui.altarCardHint', {
                        'souls': formatCount(souls),
                        'yield': formatCount(yield_.total),
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textFaint),
            ],
          ),
        ),
      ],
    );
  }
}

class AltarView extends ConsumerWidget {
  const AltarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final prestige = ref.watch(prestigeProvider);
    final player = ref.watch(playerProvider);
    final progress = ref.watch(progressProvider);
    final chronicle = ref.watch(achievementsProvider);
    final yield_ = calculatePrestigeYield(
      highestLocationIndex: highestLocationIndexReached(progress),
      totalKills: player.totalKills,
      itemsCrafted: player.itemsCrafted,
    );
    final locId = allLocations[yield_.locationIndex].id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        SectionTitle(l10n.t('ui.altarTitle'), icon: Icons.local_fire_department),
        Panel(
          borderColor: _ember.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('ui.altarBlurb'),
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              StatLine(
                label: l10n.t('ui.ashSouls'),
                value: formatCount(prestige.ashSouls),
                valueColor: _ember,
                icon: Icons.auto_awesome,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionTitle(l10n.t('ui.ascendProgress'), icon: Icons.hiking),
        Panel(
          child: Column(
            children: [
              StatLine(
                label: l10n.t('ui.ascendLevel', {'n': '${player.level}'}),
                value: l10n.locationName(locId),
              ),
              StatLine(
                label: l10n.t('ui.ascendKills'),
                value: formatCount(player.totalKills),
              ),
              StatLine(
                label: l10n.t('ui.ascendCrafts'),
                value: formatCount(player.itemsCrafted),
              ),
              const SizedBox(height: 8),
              StatLine(
                label: l10n.t('ui.ascendFromLocation'),
                value: '+${yield_.fromLocation}',
              ),
              StatLine(
                label: l10n.t('ui.ascendFromKills'),
                value: '+${yield_.fromKills}',
              ),
              StatLine(
                label: l10n.t('ui.ascendFromCrafts'),
                value: '+${yield_.fromCrafts}',
              ),
              StatLine(
                label: l10n.t('ui.ascendYield'),
                value: formatCount(yield_.total),
                valueColor: _ember,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('altar-ascend'),
                  onPressed: yield_.canAscend
                      ? () => _confirmAscend(context, ref)
                      : null,
                  icon: const Icon(Icons.whatshot, size: 18),
                  label: Text(l10n.t('ui.ascend')),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ember,
                    foregroundColor: const Color(0xFF2A1208),
                    disabledBackgroundColor: AppColors.surfaceHigh,
                  ),
                ),
              ),
              if (!yield_.canAscend) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.t('ui.ascendNone'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionTitle(l10n.t('ui.metaShop'), icon: Icons.storefront),
        for (final perk in MetaPerk.values) ...[
          _PerkTile(perk: perk, owned: prestige.has(perk), souls: prestige.ashSouls),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        SectionTitle(l10n.t('ui.achievements'), icon: Icons.emoji_events),
        Panel(
          child: Column(
            children: [
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
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final def in achievementCatalog)
          _AchievementTile(
            def: def,
            unlocked: chronicle.isUnlocked(def.id),
          ),
      ],
    );
  }

  Future<void> _confirmAscend(BuildContext context, WidgetRef ref) async {
    final l10n = ref.read(l10nProvider);
    final player = ref.read(playerProvider);
    final yield_ = ref.read(prestigeProvider.notifier).estimatedYield();
    final locId = allLocations[yield_.locationIndex].id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('ui.ascendConfirmTitle')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.t('ui.ascendConfirmLead', {
                  'level': '${player.level}',
                  'location': l10n.locationName(locId),
                  'kills': '${player.totalKills}',
                  'crafts': '${player.itemsCrafted}',
                }),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t('ui.ascendConfirmYield', {
                  'n': '${yield_.total}',
                }),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _ember,
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.t('ui.ascendConfirmBody')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('ui.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _ember,
              foregroundColor: const Color(0xFF2A1208),
            ),
            child: Text(l10n.t('ui.ascend')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(prestigeProvider.notifier).executeAscension();
    await ref.read(saveControllerProvider).flushNow();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.t('ui.ascendDone') : l10n.t('ui.ascendNone'),
        ),
      ),
    );
  }
}

class _PerkTile extends ConsumerWidget {
  const _PerkTile({
    required this.perk,
    required this.owned,
    required this.souls,
  });

  final MetaPerk perk;
  final bool owned;
  final int souls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final canBuy = !owned && souls >= perk.cost;
    return Panel(
      borderColor: owned ? _ember.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t(perk.nameKey),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                owned ? l10n.t('ui.metaOwned') : '${perk.cost}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: owned ? _ember : AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t(perk.descKey),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (!owned) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: canBuy
                    ? () => ref.read(prestigeProvider.notifier).buyPerk(perk)
                    : null,
                child: Text(
                  canBuy
                      ? l10n.t('ui.metaBuy', {'n': '${perk.cost}'})
                      : l10n.t('ui.metaNeedSouls', {'n': '${perk.cost}'}),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementTile extends ConsumerWidget {
  const _AchievementTile({required this.def, required this.unlocked});

  final AchievementDef def;
  final bool unlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        color: unlocked ? AppColors.surfaceAlt : AppColors.surface,
        child: Row(
          children: [
            Icon(
              unlocked ? Icons.emoji_events : Icons.lock_outline,
              color: unlocked ? AppColors.gold : AppColors.textFaint,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unlocked
                        ? l10n.t(def.titleKey)
                        : l10n.t('ui.achieveLocked'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: unlocked ? AppColors.text : AppColors.textMuted,
                    ),
                  ),
                  Text(
                    l10n.t(def.descKey),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '+${def.soulReward}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _ember,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
