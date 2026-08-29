import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/shop_data.dart';
import '../../l10n/l10n.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/time_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Boosters, resource packs, and the combat-speed test toggle.
class ShopTab extends ConsumerWidget {
  const ShopTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: const [
        _WalletCard(),
        SizedBox(height: 14),
        _SpeedCard(),
        SizedBox(height: 14),
        _OfferSection(
          titleKey: 'shop.boosters',
          icon: Icons.bolt,
          offers: shopBoosters,
        ),
        SizedBox(height: 14),
        _OfferSection(
          titleKey: 'shop.packs',
          icon: Icons.inventory,
          offers: shopPacks,
        ),
      ],
    );
  }
}

class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = ref.watch(playerProvider.select((p) => p.gold));
    final gems = ref.watch(playerProvider.select((p) => p.gems));
    final free = ref.watch(settingsProvider.select((s) => s.developerFreeMode));
    final l10n = ref.watch(l10nProvider);
    final time = ref.watch(timeControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.t('shop.wallet'), icon: Icons.account_balance_wallet),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ResourceChip(
                    icon: Icons.monetization_on,
                    value: formatCount(gold),
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 10),
                  ResourceChip(
                    icon: Icons.diamond,
                    value: formatCount(gems),
                    color: AppColors.gem,
                  ),
                  if (free) ...[
                    const SizedBox(width: 10),
                    Text(
                      l10n.t('shop.free'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
              if (time.xpElixirActive) ...[
                const SizedBox(height: 8),
                _BoosterChip(
                  label: l10n.t('shop.xpElixir'),
                  remaining: time.xpElixirRemaining(),
                ),
              ],
              if (time.doubleLootActive) ...[
                const SizedBox(height: 6),
                _BoosterChip(
                  label: l10n.t('shop.doubleLoot'),
                  remaining: time.doubleLootRemaining(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BoosterChip extends StatelessWidget {
  const _BoosterChip({required this.label, required this.remaining});

  final String label;
  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final seconds = remaining?.inSeconds.toDouble() ?? 0;
    return Text(
      '$label · ${formatDuration(seconds)}',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.info,
      ),
    );
  }
}

class _SpeedCard extends ConsumerWidget {
  const _SpeedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(
      timeControllerProvider.select((t) => t.speedMultiplier),
    );
    final l10n = ref.watch(l10nProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.t('shop.speed'), icon: Icons.speed),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('shop.speedHint'),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textFaint,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final step in combatSpeedSteps) ...[
                    if (step != combatSpeedSteps.first)
                      const SizedBox(width: 8),
                    _SpeedChip(
                      label: l10n.t('shop.speedNx', {'n': '$step'}),
                      selected: speed == step,
                      onTap: () => ref
                          .read(timeControllerProvider.notifier)
                          .setSpeed(step),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.22)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.gold : AppColors.textFaint,
          ),
        ),
      ),
    );
  }
}

class _OfferSection extends StatelessWidget {
  const _OfferSection({
    required this.titleKey,
    required this.icon,
    required this.offers,
  });

  final String titleKey;
  final IconData icon;
  final List<ShopOffer> offers;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final l10n = ref.watch(l10nProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(l10n.t(titleKey), icon: icon),
            Panel(
              child: Column(
                children: [
                  for (var i = 0; i < offers.length; i++) ...[
                    if (i > 0) const Divider(height: 14),
                    _OfferRow(offer: offers[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OfferRow extends ConsumerWidget {
  const _OfferRow({required this.offer});

  final ShopOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final free = ref.watch(settingsProvider.select((s) => s.developerFreeMode));
    final gold = ref.watch(playerProvider.select((p) => p.gold));
    final gems = ref.watch(playerProvider.select((p) => p.gems));
    final cost = free ? 0 : offer.cost;
    final affordable =
        free ||
        (offer.currency == ShopCurrency.gems ? gems >= cost : gold >= cost);
    final gemPay = offer.currency == ShopCurrency.gems;

    return Row(
      children: [
        Icon(offer.icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t(offer.titleKey),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              Text(
                l10n.t(offer.hintKey),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 28,
          child: OutlinedButton.icon(
            onPressed: affordable ? () => _buy(context, ref, l10n) : null,
            icon: Icon(
              gemPay ? Icons.diamond : Icons.monetization_on,
              size: 12,
              color: gemPay ? AppColors.gem : AppColors.gold,
            ),
            label: Text(free ? l10n.t('shop.free') : '$cost'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
      ],
    );
  }

  void _buy(BuildContext context, WidgetRef ref, L10n l10n) {
    final result = ref.read(shopControllerProvider).buy(offer.id);
    final args = Map<String, String>.of(result.args);
    if (args.containsKey('item')) {
      args['item'] = l10n.itemName(args['item']!);
    }
    var text = l10n.t(result.messageKey, args);
    final summary = result.summary;
    if (summary != null && summary.loot.isNotEmpty) {
      final items = summary.loot.entries
          .take(4)
          .map((e) => '${l10n.itemName(e.key)} ×${e.value}')
          .join(', ');
      text = '$text · ${l10n.t('shop.skipLoot', {'items': items})}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: Duration(seconds: summary == null ? 2 : 4),
      ),
    );
  }
}
