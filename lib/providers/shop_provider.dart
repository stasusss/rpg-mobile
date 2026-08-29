import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shop_data.dart';
import 'inventory_provider.dart';
import 'player_provider.dart';
import 'settings_provider.dart';
import 'time_controller.dart';

/// Outcome of tapping a shop row.
@immutable
class ShopPurchaseResult {
  const ShopPurchaseResult({
    required this.success,
    required this.messageKey,
    this.args = const {},
    this.summary,
  });

  final bool success;
  final String messageKey;
  final Map<String, String> args;
  final TimeSkipSummary? summary;

  static const ShopPurchaseResult unknown = ShopPurchaseResult(
    success: false,
    messageKey: 'shop.unknown',
  );
}

/// Spends gold or gems, then applies a [ShopOffer].
class ShopController {
  ShopController(this._ref);

  final Ref _ref;

  ShopPurchaseResult buy(String offerId) {
    final offer = shopCatalog[offerId];
    if (offer == null) return ShopPurchaseResult.unknown;

    final free = _ref.read(settingsProvider).developerFreeMode;
    final cost = free ? 0 : offer.cost;
    final player = _ref.read(playerProvider.notifier);

    if (cost > 0) {
      final paid = switch (offer.currency) {
        ShopCurrency.gems => player.spendGems(cost),
        ShopCurrency.gold => player.spendGold(cost),
      };
      if (!paid) {
        return ShopPurchaseResult(
          success: false,
          messageKey: offer.currency == ShopCurrency.gems
              ? 'ui.notEnoughGems'
              : 'ui.notEnoughGold',
        );
      }
    }

    final time = _ref.read(timeControllerProvider.notifier);
    switch (offer.effect) {
      case ShopEffect.timeSkip:
        final summary = time.skipHours(offer.hours);
        return ShopPurchaseResult(
          success: true,
          messageKey: 'shop.skipDone',
          args: {
            'hours': '${offer.hours}',
            'xp': '${summary.xp}',
            'gold': '${summary.gold}',
            'kills': '${summary.kills}',
          },
          summary: summary,
        );
      case ShopEffect.xpElixir:
        time.activateXpElixir();
        return const ShopPurchaseResult(
          success: true,
          messageKey: 'shop.bought',
        );
      case ShopEffect.doubleLoot:
        time.activateDoubleLoot();
        return const ShopPurchaseResult(
          success: true,
          messageKey: 'shop.bought',
        );
      case ShopEffect.itemPack:
        final itemId = offer.itemId;
        if (itemId == null || offer.quantity <= 0) {
          _refund(offer, cost);
          return ShopPurchaseResult.unknown;
        }
        final inventory = _ref.read(inventoryProvider.notifier);
        final snapshot = _ref.read(inventoryProvider);
        final outcome = inventory.add(itemId, offer.quantity);
        if (outcome == PickupOutcome.bagFull) {
          inventory.restoreSnapshot(snapshot);
          _refund(offer, cost);
          return const ShopPurchaseResult(
            success: false,
            messageKey: 'craft.bagFull',
          );
        }
        return ShopPurchaseResult(
          success: true,
          messageKey: 'shop.boughtPack',
          args: {'n': '${offer.quantity}', 'item': itemId},
        );
      case ShopEffect.goldPack:
        player.gainGold(offer.grantGold);
        return ShopPurchaseResult(
          success: true,
          messageKey: 'shop.boughtGold',
          args: {'n': '${offer.grantGold}'},
        );
      case ShopEffect.gemPack:
        player.gainGems(offer.grantGems);
        return ShopPurchaseResult(
          success: true,
          messageKey: 'shop.boughtGems',
          args: {'n': '${offer.grantGems}'},
        );
    }
  }

  void _refund(ShopOffer offer, int cost) {
    if (cost <= 0) return;
    final player = _ref.read(playerProvider.notifier);
    switch (offer.currency) {
      case ShopCurrency.gems:
        player.gainGems(cost);
      case ShopCurrency.gold:
        player.gainGold(cost);
    }
  }
}

final shopControllerProvider = Provider<ShopController>(
  (ref) => ShopController(ref),
);
