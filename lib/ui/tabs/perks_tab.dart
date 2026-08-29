import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/skills_data.dart';
import '../../models/skill.dart';
import '../../providers/locale_provider.dart';
import '../../providers/skills_provider.dart';
import '../hubs/altar_sheet.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Learned passive boosters and perk nodes.
class PassivePerksView extends ConsumerWidget {
  const PassivePerksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranks = ref.watch(skillsProvider);
    final l10n = ref.watch(l10nProvider);
    final learned = [
      for (final skill in allSkills)
        if ((ranks[skill.id] ?? 0) > 0 &&
            (skill.kind == SkillNodeKind.perk ||
                skill.kind == SkillNodeKind.booster))
          (skill, ranks[skill.id]!),
    ];

    if (learned.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          const AltarEntryCard(),
          const SizedBox(height: 14),
          Panel(
            child: EmptyHint(
              message: l10n.t('ui.perkNone'),
              icon: Icons.auto_awesome,
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
      children: [
        const AltarEntryCard(),
        const SizedBox(height: 14),
        SectionTitle(l10n.t('tab.perks'), icon: Icons.auto_awesome),
        for (final entry in learned)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              child: Row(
                children: [
                  Icon(entry.$1.icon, color: entry.$1.branch.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.skillName(entry.$1.id),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.skillDesc(entry.$1.id),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${entry.$2}/${entry.$1.maxRank}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
