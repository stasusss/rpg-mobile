import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_manager.dart';
import '../../data/skills_data.dart';
import '../../models/skill.dart';
import '../../providers/locale_provider.dart';
import '../../providers/skill_loadout_provider.dart';
import '../../providers/skills_provider.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Assigns the three HUD signature / tree actives.
class SkillLoadoutView extends ConsumerWidget {
  const SkillLoadoutView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadout = ref.watch(skillLoadoutProvider);
    final equipped = ref.watch(equippedActivesProvider);
    final unlocked = ref.watch(unlockedActivesProvider);
    final l10n = ref.watch(l10nProvider);
    final choices = <SkillDef>[
      ...signatureSkills,
      for (final active in unlocked)
        if (signatureSkills.every((s) => s.id != active.def.id)) active.def,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
      children: [
        Text(
          l10n.t('ui.assignSkill'),
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _LoadoutSlot(
                  index: i,
                  skillId: i < equipped.length
                      ? equipped[i].def.id
                      : loadout.slotAt(i),
                  onTap: () => _assign(context, ref, i, choices),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        SectionTitle(l10n.t('tab.loadout'), icon: Icons.flash_on),
        for (final def in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              onTap: () {
                AudioManager.instance.play(SfxKind.click);
                final slots = ref.read(skillLoadoutProvider).slots;
                final empty = slots.indexWhere(
                  (id) => id.isEmpty || trySkillById(id) == null,
                );
                final target = empty >= 0 && empty < 3
                    ? empty
                    : 0;
                ref.read(skillLoadoutProvider.notifier).setSlot(target, def.id);
              },
              child: Row(
                children: [
                  Icon(def.icon, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.skillName(def.id),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.skillDesc(def.id),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    int index,
    List<SkillDef> choices,
  ) async {
    AudioManager.instance.play(SfxKind.click);
    final l10n = ref.read(l10nProvider);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                l10n.t('ui.chooseSkill'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final def in choices)
                ListTile(
                  minTileHeight: 48,
                  leading: Icon(def.icon, color: AppColors.gold),
                  title: Text(l10n.skillName(def.id)),
                  subtitle: Text(l10n.skillDesc(def.id), maxLines: 2),
                  onTap: () => Navigator.of(ctx).pop(def.id),
                ),
            ],
          ),
        );
      },
    );
    if (chosen != null) {
      ref.read(skillLoadoutProvider.notifier).setSlot(index, chosen);
    }
  }
}

class _LoadoutSlot extends ConsumerWidget {
  const _LoadoutSlot({
    required this.index,
    required this.skillId,
    required this.onTap,
  });

  final int index;
  final String? skillId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final def = skillId == null ? null : trySkillById(skillId!);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: def == null ? AppColors.outline : AppColors.gold,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    def?.icon ?? Icons.add,
                    size: 26,
                    color: def == null ? AppColors.textFaint : AppColors.gold,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    def == null
                        ? l10n.t('ui.skillSlot', {'n': '${index + 1}'})
                        : l10n.skillName(def.id),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: def == null ? AppColors.textFaint : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
