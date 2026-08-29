import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/locale_provider.dart';
import '../tabs/inventory_tab.dart';
import '../tabs/shop_tab.dart';
import '../widgets/hub_pager.dart';

/// Equipment crafting, alchemy, and the booster shop.
class CraftHub extends ConsumerWidget {
  const CraftHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return HubPager(
      labels: [
        l10n.t('tab.craft'),
        l10n.t('tab.alchemy'),
        l10n.t('tab.shop'),
      ],
      pages: const [
        CraftRecipesView(),
        CraftRecipesView(alchemyOnly: true),
        ShopTab(),
      ],
    );
  }
}
