import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/locale_provider.dart';
import '../tabs/loadout_tab.dart';
import '../tabs/perks_tab.dart';
import '../tabs/skills_tab.dart';
import '../widgets/hub_pager.dart';

/// Skill tree, active loadout, and learned passives.
class GrowthHub extends ConsumerWidget {
  const GrowthHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return HubPager(
      labels: [
        l10n.t('tab.skills'),
        l10n.t('tab.loadout'),
        l10n.t('tab.perks'),
      ],
      pages: const [
        SkillTreeTab(),
        SkillLoadoutView(),
        PassivePerksView(),
      ],
    );
  }
}
