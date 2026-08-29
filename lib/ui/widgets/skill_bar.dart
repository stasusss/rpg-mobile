import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_manager.dart';
import '../../data/skills_data.dart';
import '../../l10n/l10n.dart';
import '../../models/skill.dart';
import '../../providers/combat_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/skill_loadout_provider.dart';
import '../../providers/skills_provider.dart';
import '../theme.dart';

Future<void> _pickLoadout(
  BuildContext context,
  WidgetRef ref,
  int index,
  L10n l10n,
) async {
  AudioManager.instance.play(SfxKind.click);
  final unlocked = ref.read(unlockedActivesProvider);
  final choices = <SkillDef>[
    ...signatureSkills,
    for (final active in unlocked)
      if (signatureSkills.every((s) => s.id != active.def.id)) active.def,
  ];
  if (!context.mounted) return;
  final chosen = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('ui.chooseSkill'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                l10n.t('ui.skillSlot', {'n': '${index + 1}'}),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              for (final def in choices)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(def.icon, color: AppColors.gold),
                  title: Text(l10n.skillName(def.id)),
                  subtitle: Text(
                    l10n.skillDesc(def.id),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(ctx).pop(def.id),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (chosen != null) {
    ref.read(skillLoadoutProvider.notifier).setSlot(index, chosen);
  }
}

/// Three HUD slots with cooldown wedges. Tap a ready slot to fire it now.
class ActiveSkillBar extends ConsumerWidget {
  const ActiveSkillBar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(combatProvider.select((s) => s.skillSlots));
    final equipped = ref.watch(equippedActivesProvider);
    final mana = ref.watch(combatProvider.select((s) => s.playerMana));
    final l10n = ref.watch(l10nProvider);
    final resolved = slots.isNotEmpty
        ? slots
        : [
            for (final active in equipped)
              SkillHudSlot(
                skillId: active.def.id,
                cooldown: 0,
                cooldownMax: active.cooldown,
                manaCost: active.manaCost,
              ),
          ];
    if (resolved.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < resolved.length; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
            child: _SkillSlotButton(
              slot: resolved[i],
              mana: mana,
              l10n: l10n,
              onTap: () {
                AudioManager.instance.play(SfxKind.click);
                ref.read(combatProvider.notifier).castSlot(i);
              },
              onLongPress: () => _pickLoadout(context, ref, i, l10n),
            ),
          ),
      ],
    );
  }
}

class _SkillSlotButton extends StatelessWidget {
  const _SkillSlotButton({
    required this.slot,
    required this.mana,
    required this.l10n,
    required this.onTap,
    required this.onLongPress,
  });

  final SkillHudSlot slot;
  final double mana;
  final L10n l10n;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final def = trySkillById(slot.skillId);
    final starved = mana < slot.manaCost;
    final ready = slot.ready && !starved;
    return Tooltip(
      message: def == null
          ? slot.skillId
          : '${l10n.skillName(slot.skillId)}\n${l10n.skillDesc(slot.skillId)}\n${l10n.t('ui.holdToSwap')}',
      child: GestureDetector(
        onTap: ready ? onTap : null,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ready ? AppColors.gold : Colors.white24,
                    width: ready ? 1.6 : 1,
                  ),
                ),
                child: Icon(
                  def?.icon ?? Icons.flash_on,
                  size: 20,
                  color: ready ? AppColors.gold : Colors.white54,
                ),
              ),
              if (!slot.ready)
                CustomPaint(
                  painter: _CooldownPainter(fraction: 1 - slot.fraction),
                ),
              if (!slot.ready)
                Center(
                  child: Text(
                    slot.cooldown.ceil().toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CooldownPainter extends CustomPainter {
  _CooldownPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(2),
      -1.5708,
      6.2832 * fraction.clamp(0.0, 1.0),
      true,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _CooldownPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

