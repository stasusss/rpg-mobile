import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/items_data.dart';
import '../../flame/battle_game.dart';
import '../../flame/character_sprites.dart';
import '../../models/item.dart';
import '../../models/status_effect.dart';
import '../../l10n/l10n.dart';
import '../../providers/combat_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/stats_provider.dart';
import '../theme.dart';
import 'common.dart';

/// The 45%-height battle stage: a Flame canvas plus HUD overlays.
///
/// State flows one way. This widget listens to the simulation and forwards a
/// [BattleSnapshot] into the game; the game never reads providers.
class GameViewport extends ConsumerStatefulWidget {
  const GameViewport({super.key});

  @override
  ConsumerState<GameViewport> createState() => _GameViewportState();
}

class _GameViewportState extends ConsumerState<GameViewport> {
  late final BattleGame _game;

  @override
  void initState() {
    super.initState();
    _game = BattleGame(
      initialLocation: ref.read(currentLocationProvider),
      snapshot: _snapshot(),
      eventBus: ref.read(combatEventBusProvider),
    );
  }

  BattleSnapshot _snapshot() {
    final combat = ref.read(combatProvider);
    final maxHp = ref.read(combatStatsProvider).maxHp;
    return BattleSnapshot(
      phase: combat.phase,
      location: ref.read(currentLocationProvider),
      enemy: combat.enemy,
      approach: combat.approach,
      playerHpFraction: (combat.playerHp / maxHp).clamp(0.0, 1.0),
      playerLook: _lookFrom(ref.read(inventoryProvider)),
      showDamageNumbers: ref.read(settingsProvider).showDamageNumbers,
      labels: CombatFxLabels.from(ref.read(l10nProvider)),
    );
  }

  /// Maps equipped gear onto the procedural hero's appearance.
  PlayerLook _lookFrom(InventoryState inventory) {
    ItemDef? worn(EquipSlot slot) {
      final entry = inventory.equipped[slot];
      return entry == null ? null : tryItemById(entry.itemId);
    }

    final weapon = worn(EquipSlot.weapon);
    final shield = worn(EquipSlot.shield);
    final helmet = worn(EquipSlot.helmet);
    final armor = worn(EquipSlot.armor);
    final boots = worn(EquipSlot.boots);

    ItemRarity? glow;
    for (final item in [weapon, shield, helmet, armor, boots]) {
      if (item == null) continue;
      if (glow == null || item.rarity.index > glow.index) glow = item.rarity;
    }

    return PlayerLook(
      weapon: weapon?.weaponLook ?? (weapon != null ? WeaponLook.sword : null),
      weaponColor: weapon?.rarity.color ?? const Color(0xFFB0BEC5),
      hasShield: shield != null,
      shieldColor: shield?.rarity.color ?? const Color(0xFF8D6E63),
      hasHelmet: helmet != null,
      helmetColor: helmet?.rarity.color ?? const Color(0xFF90A4AE),
      armorColor: armor == null
          ? const Color(0xFF44506B)
          : Color.lerp(const Color(0xFF3F6FA8), armor.rarity.color, 0.55)!,
      bootColor:
          boots?.rarity.color.withValues(alpha: 1) ?? const Color(0xFF5D4037),
      glowRarity: glow,
    );
  }

  void _push() {
    if (!mounted) return;
    _game.applySnapshot(_snapshot());
  }

  @override
  Widget build(BuildContext context) {
    // Any of these changing means the renderer needs a fresh snapshot.
    ref.listen(combatProvider, (_, _) => _push());
    ref.listen(combatStatsProvider, (_, _) => _push());
    ref.listen(inventoryProvider, (_, _) => _push());
    ref.listen(settingsProvider, (_, _) => _push());
    ref.listen(currentLocationProvider, (_, _) => _push());
    ref.listen(l10nProvider, (_, _) => _push());

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: _game),
          const _ViewportHud(),
        ],
      ),
    );
  }
}

class _ViewportHud extends ConsumerWidget {
  const _ViewportHud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(combatProvider.select((s) => s.phase));

    // The HUD sits on a fixed-height stage, so it opts out of text scaling to
    // keep the plates from swallowing the battle.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            const Align(alignment: Alignment.topLeft, child: _LocationTag()),
            const Align(alignment: Alignment.topRight, child: _EnemyPlate()),
            const Align(alignment: Alignment.bottomLeft, child: _PlayerPlate()),
            const Align(
              alignment: Alignment.bottomRight,
              child: _KillCounter(),
            ),
            if (phase == CombatPhase.playerDown)
              const Align(alignment: Alignment.center, child: _DownedBanner()),
          ],
        ),
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }
}

class _LocationTag extends ConsumerWidget {
  const _LocationTag();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(currentLocationProvider);
    final phase = ref.watch(combatProvider.select((s) => s.phase));
    final l10n = ref.watch(l10nProvider);

    return _Plate(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.locationName(location.id),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            phase == CombatPhase.traveling
                ? l10n.t('ui.searching')
                : l10n.t('ui.inCombat'),
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnemyPlate extends ConsumerWidget {
  const _EnemyPlate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enemy = ref.watch(combatProvider.select((s) => s.enemy));
    final l10n = ref.watch(l10nProvider);
    if (enemy == null) return const SizedBox.shrink();

    return _Plate(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (enemy.def.isBoss)
                const Padding(
                  padding: EdgeInsets.only(right: 3),
                  child: Icon(Icons.star, size: 11, color: AppColors.gold),
                ),
              Expanded(
                flex: 3,
                child: Text(
                  l10n.enemyName(enemy.def.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: enemy.def.isBoss ? AppColors.gold : Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  l10n.t('ui.level', {'n': '${enemy.def.level}'}),
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          StatBar(
            fraction: enemy.hpFraction,
            color: AppColors.hp,
            height: 7,
            background: Colors.white.withValues(alpha: 0.14),
          ),
          const SizedBox(height: 2),
          Text(
            '${formatCount(enemy.hp.ceil())} / ${formatCount(enemy.def.maxHp)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          _StatusRow(
            effects: ref.watch(combatProvider.select((s) => s.enemyEffects)),
            enraged: ref.watch(combatProvider.select((s) => s.bossEnraged)),
            phasing: ref.watch(combatProvider.select((s) => s.bossPhasing)),
          ),
        ],
      ),
    );
  }
}

class _PlayerPlate extends ConsumerWidget {
  const _PlayerPlate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hp = ref.watch(combatProvider.select((s) => s.playerHp));
    final stats = ref.watch(combatStatsProvider);
    final l10n = ref.watch(l10nProvider);
    final fraction = (hp / stats.maxHp).clamp(0.0, 1.0);

    return _Plate(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, size: 11, color: AppColors.hp),
              const SizedBox(width: 4),
              Expanded(
                flex: 3,
                child: Text(
                  '${formatCount(hp.ceil())} / ${formatCount(stats.maxHp)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  l10n.t('ui.dpsShort', {'n': formatCount(stats.dps)}),
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          StatBar(
            fraction: fraction,
            color: fraction > 0.35 ? AppColors.success : AppColors.hp,
            height: 7,
            background: Colors.white.withValues(alpha: 0.14),
          ),
          const SizedBox(height: 3),
          StatBar(
            fraction: ref.watch(playerManaFractionProvider),
            color: AppColors.mana,
            height: 5,
            background: Colors.white.withValues(alpha: 0.14),
          ),
          _StatusRow(
            effects: ref.watch(combatProvider.select((s) => s.playerEffects)),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends ConsumerWidget {
  const _StatusRow({
    required this.effects,
    this.enraged = false,
    this.phasing = false,
  });

  final List<StatusEffect> effects;
  final bool enraged;
  final bool phasing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final chips = <(Color, String, String)>[
      for (final effect in effects)
        (effect.id.color, l10n.statusName(effect.id), l10n.statusDesc(effect.id)),
      if (enraged && effects.every((e) => e.id != StatusId.enrage))
        (
          StatusId.enrage.color,
          l10n.statusName(StatusId.enrage),
          l10n.statusDesc(StatusId.enrage),
        ),
      if (phasing)
        (
          const Color(0xFF80DEEA),
          l10n.t('status.shield'),
          l10n.statusDesc(StatusId.shield),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 3,
        runSpacing: 2,
        children: [
          for (final chip in chips)
            Tooltip(
              message: '${chip.$2}\n${chip.$3}',
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: chip.$1,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KillCounter extends ConsumerWidget {
  const _KillCounter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kills = ref.watch(combatProvider.select((s) => s.sessionKills));
    return _Plate(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dangerous, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            '$kills',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownedBanner extends ConsumerWidget {
  const _DownedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(
      combatProvider.select((s) => s.recoveryRemaining),
    );
    final l10n = ref.watch(l10nProvider);

    return _Plate(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.t('fx.defeated'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: AppColors.hp,
            ),
          ),
          Text(
            l10n.t('ui.recovering', {'n': remaining.toStringAsFixed(1)}),
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 26,
            child: FilledButton(
              onPressed: () => ref.read(combatProvider.notifier).reviveNow(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(l10n.t('ui.getUp')),
            ),
          ),
        ],
      ),
    );
  }
}
