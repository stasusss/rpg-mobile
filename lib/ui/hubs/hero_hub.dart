import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/locale_provider.dart';
import '../tabs/inventory_tab.dart';
import '../tabs/stats_tab.dart';
import '../widgets/hub_pager.dart';

/// Inventory, paper-doll, mastery, and settings.
class HeroHub extends ConsumerWidget {
  const HeroHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return HubPager(
      labels: [
        l10n.t('tab.gear'),
        l10n.t('tab.stats'),
        l10n.t('tab.settings'),
      ],
      pages: const [
        GearInventoryView(),
        StatsTab(),
        StatsTab(settingsOnly: true),
      ],
    );
  }
}
