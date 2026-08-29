import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/locale_provider.dart';
import '../tabs/bestiary_tab.dart';
import '../tabs/location_tab.dart';
import '../tabs/map_tab.dart';
import '../widgets/hub_pager.dart';

/// World map, current zone, and bestiary.
class AdventureHub extends ConsumerWidget {
  const AdventureHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return HubPager(
      labels: [
        l10n.t('tab.map'),
        l10n.t('tab.location'),
        l10n.t('tab.bestiary'),
      ],
      pages: const [
        MapTab(),
        LocationDetailView(),
        BestiaryTab(),
      ],
    );
  }
}
