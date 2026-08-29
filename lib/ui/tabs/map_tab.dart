import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/enemies_data.dart';
import '../../data/items_data.dart';
import '../../data/locations_data.dart';
import '../../models/enemy.dart';
import '../../models/item.dart';
import '../../models/location.dart';
import '../../providers/combat_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/progress_provider.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/item_sheet.dart';

/// Interactive node map plus the farm-target strip.
///
/// Tapping an unlocked node travels there: the Flame biome and spawn table
/// swap on the next combat tick, and loot from that table lands in the bag.
class MapTab extends ConsumerWidget {
  const MapTab({super.key});

  static const double _cellW = 168;
  static const double _cellH = 124;
  static const double _nodeW = 148;
  static const double _nodeH = 104;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showCards = constraints.maxHeight >= 220;
        return Column(
          children: [
            if (showCards) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: _NowFarmingBar(),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _FarmTargetCard(),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: _CompactFarmStrip(),
              ),
            Expanded(
          child: ClipRect(
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(56),
              minScale: 0.7,
              maxScale: 1.8,
              child: SizedBox(
                width: worldMapColumns * _cellW + 16,
                height: worldMapRows * _cellH + 16,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PathPainter(
                          cellW: _cellW,
                          cellH: _cellH,
                          nodeW: _nodeW,
                          nodeH: _nodeH,
                          currentId: ref.watch(currentLocationProvider).id,
                          unlocks: ref.watch(locationUnlocksProvider),
                        ),
                      ),
                    ),
                    for (final location in allLocations)
                      Positioned(
                        left:
                            location.mapCol * _cellW +
                            (_cellW - _nodeW) / 2 +
                            8,
                        top:
                            location.mapRow * _cellH +
                            (_cellH - _nodeH) / 2 +
                            8,
                        child: _MapNode(
                          location: location,
                          width: _nodeW,
                          height: _nodeH,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
          ],
        );
      },
    );
  }
}

class _CompactFarmStrip extends ConsumerWidget {
  const _CompactFarmStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(currentLocationProvider);
    final drops = materialsIn(location);
    final l10n = ref.watch(l10nProvider);
    final names = [
      l10n.locationName(location.id),
      for (final item in drops.take(3)) l10n.itemName(item.id),
    ].join(' · ');
    return SizedBox(
      height: 48,
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            names,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _NowFarmingBar extends ConsumerWidget {
  const _NowFarmingBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(currentLocationProvider);
    final kills = ref.watch(
      progressProvider.select((p) => p.killsIn(location.id)),
    );
    final session = ref.watch(combatProvider.select((s) => s.sessionKills));
    final drops = materialsIn(location);
    final l10n = ref.watch(l10nProvider);

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderColor: AppColors.gold.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(location.icon, size: 16, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.locationName(location.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ),
              Text(
                l10n.t('ui.level', {'n': '${location.recommendedLevel}'}),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${l10n.t('ui.kills', {'n': formatCount(kills)})} · '
                '${l10n.t('ui.sessionKills', {'n': '$session'})}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
          if (drops.isNotEmpty) ...[
            const SizedBox(height: 6),
            _DropRow(items: drops, compact: true),
          ],
        ],
      ),
    );
  }
}

/// Shows the material the player is hunting and where to find it.
class _FarmTargetCard extends ConsumerWidget {
  const _FarmTargetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final targetId = ref.watch(lootTargetProvider);
    if (targetId == null) {
      return Panel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.my_location, size: 15, color: AppColors.textFaint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.t('ui.farmIdle'),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final item = tryItemById(targetId);
    if (item == null) return const SizedBox.shrink();

    final owned = ref.watch(
      inventoryProvider.select((inv) => inv.countOf(targetId)),
    );
    final sources = enemiesDropping(targetId);
    final sourceIds = sources.map((e) => e.id).toSet();
    final places = locationsDropping(targetId, sourceIds);
    final currentId = ref.watch(currentLocationProvider).id;

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderColor: AppColors.gold.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ItemTile(item: item, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t('ui.farming', {
                    'name': l10n.itemName(item.id),
                    'owned': '$owned',
                  }),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => ref.read(lootTargetProvider.notifier).clear(),
                icon: const Icon(Icons.close, size: 16),
                color: AppColors.textFaint,
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final place in places)
                _TravelChip(location: place, isCurrent: place.id == currentId),
            ],
          ),
        ],
      ),
    );
  }
}

class _TravelChip extends ConsumerWidget {
  const _TravelChip({required this.location, required this.isCurrent});

  final LocationDef location;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockReason = ref.watch(locationUnlocksProvider)[location.id];
    final locked = lockReason != null;
    final l10n = ref.watch(l10nProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: locked || isCurrent
            ? null
            : () => ref.read(progressProvider.notifier).travelTo(location.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.gold.withValues(alpha: 0.16)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrent ? AppColors.gold : AppColors.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                locked ? Icons.lock : location.icon,
                size: 11,
                color: locked
                    ? AppColors.textFaint
                    : (isCurrent ? AppColors.gold : AppColors.textMuted),
              ),
              const SizedBox(width: 4),
              Text(
                l10n.locationName(location.id),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: locked
                      ? AppColors.textFaint
                      : (isCurrent ? AppColors.gold : AppColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.cellW,
    required this.cellH,
    required this.nodeW,
    required this.nodeH,
    required this.currentId,
    required this.unlocks,
  });

  final double cellW;
  final double cellH;
  final double nodeW;
  final double nodeH;
  final String currentId;
  final Map<String, String?> unlocks;

  @override
  void paint(Canvas canvas, Size size) {
    Offset centerOf(LocationDef loc) => Offset(
      loc.mapCol * cellW + cellW / 2 + 8,
      loc.mapRow * cellH + cellH / 2 + 8,
    );

    for (final location in allLocations) {
      for (final prereqId in location.requires) {
        final prereq = locationCatalog[prereqId];
        if (prereq == null) continue;
        final open = unlocks[location.id] == null;
        canvas.drawLine(
          centerOf(prereq),
          centerOf(location),
          Paint()
            ..color = open
                ? AppColors.info.withValues(alpha: 0.7)
                : AppColors.outline
            ..strokeWidth = open ? 3 : 1.6
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.currentId != currentId || old.unlocks != unlocks;
}

class _MapNode extends ConsumerWidget {
  const _MapNode({
    required this.location,
    required this.width,
    required this.height,
  });

  final LocationDef location;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockReason = ref.watch(locationUnlocksProvider)[location.id];
    final locked = lockReason != null;
    final isCurrent = ref.watch(currentLocationProvider).id == location.id;
    final drops = materialsIn(location);
    final l10n = ref.watch(l10nProvider);

    final accent = isCurrent
        ? AppColors.gold
        : (locked ? AppColors.outline : AppColors.info);

    return SizedBox(
      width: width,
      height: height,
      child: Panel(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
        borderColor: accent.withValues(alpha: isCurrent ? 0.8 : 0.4),
        color: isCurrent ? AppColors.surfaceAlt : AppColors.surface,
        onTap: () => _onTap(context, ref, locked, isCurrent),
        child: FittedBox(
          alignment: Alignment.topLeft,
          fit: BoxFit.scaleDown,
          child: Opacity(
          opacity: locked ? 0.55 : 1,
          child: SizedBox(
            width: width - 20,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    locked ? Icons.lock_outline : location.icon,
                    size: 14,
                    color: accent,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.locationName(location.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isCurrent ? AppColors.gold : AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                locked
                    ? lockReason
                    : '${l10n.t('ui.recLevel', {'n': '${location.recommendedLevel}'})}'
                          '${isCurrent ? '  ·  ${l10n.t('ui.here')}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: locked ? AppColors.hp : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              _DropRow(
                items: drops.take(3).toList(),
                compact: true,
                openSheet: false,
              ),
            ],
          ),
          ),
          ),
        ),
      ),
    );
  }

  void _onTap(
    BuildContext context,
    WidgetRef ref,
    bool locked,
    bool isCurrent,
  ) {
    if (!locked && !isCurrent) {
      ref.read(progressProvider.notifier).travelTo(location.id);
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _LocationSheet(location: location),
    );
  }
}

class _DropRow extends ConsumerWidget {
  const _DropRow({
    required this.items,
    this.compact = false,
    this.openSheet = true,
  });

  final List<ItemDef> items;
  final bool compact;
  final bool openSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final target = ref.watch(lootTargetProvider);
    final l10n = ref.watch(l10nProvider);
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: [
        for (final item in items)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                ref.read(lootTargetProvider.notifier).setTarget(item.id);
                if (openSheet) showItemSheet(context, item);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: item.id == target
                        ? AppColors.gold
                        : item.rarity.color.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: compact ? 10 : 12,
                      color: item.rarity.color,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        l10n.itemName(item.id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 10.5 : 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LocationSheet extends ConsumerWidget {
  const _LocationSheet({required this.location});

  final LocationDef location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockReason = ref.watch(locationUnlocksProvider)[location.id];
    final locked = lockReason != null;
    final isCurrent = ref.watch(currentLocationProvider).id == location.id;
    final kills = ref.watch(
      progressProvider.select((p) => p.killsIn(location.id)),
    );
    final drops = materialsIn(location);
    final l10n = ref.watch(l10nProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(location.icon, size: 22, color: AppColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.locationName(location.id),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        '${l10n.locationRegion(location.id)} · '
                        '${l10n.t('ui.recLevel', {'n': '${location.recommendedLevel}'})}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  l10n.t('ui.kills', {'n': formatCount(kills)}),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.locationDesc(location.id),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SectionTitle(
              l10n.t('ui.resourceDrops'),
              icon: Icons.science_outlined,
            ),
            _DropRow(items: drops),
            const SizedBox(height: 10),
            SectionTitle(l10n.t('ui.enemies'), icon: Icons.dangerous),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final spawn in location.spawns)
                  _EnemyChip(enemy: enemyById(spawn.enemyId)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: locked || isCurrent
                    ? null
                    : () {
                        ref
                            .read(progressProvider.notifier)
                            .travelTo(location.id);
                        Navigator.of(context).pop();
                      },
                child: Text(
                  locked
                      ? lockReason
                      : (isCurrent
                            ? l10n.t('ui.farmingHere')
                            : l10n.t('ui.travelHere')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnemyChip extends ConsumerWidget {
  const _EnemyChip({required this.enemy});

  final EnemyDef enemy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBoss = enemy.isBoss;
    final l10n = ref.watch(l10nProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBoss
              ? AppColors.gold.withValues(alpha: 0.6)
              : AppColors.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBoss) ...[
            const Icon(Icons.star, size: 10, color: AppColors.gold),
            const SizedBox(width: 3),
          ],
          Text(
            '${l10n.enemyName(enemy.id)} · ${enemy.level}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isBoss ? AppColors.gold : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
