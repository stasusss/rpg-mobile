import 'package:flutter/material.dart';

/// How a shop row is paid for.
enum ShopCurrency { gems, gold }

/// What buying an offer does.
enum ShopEffect { timeSkip, xpElixir, doubleLoot, itemPack, goldPack, gemPack }

/// A static storefront row. IDs are stable for tests and save-agnostic.
@immutable
class ShopOffer {
  const ShopOffer({
    required this.id,
    required this.titleKey,
    required this.hintKey,
    required this.cost,
    required this.currency,
    required this.effect,
    required this.icon,
    this.hours = 0,
    this.itemId,
    this.quantity = 0,
    this.grantGold = 0,
    this.grantGems = 0,
  });

  final String id;
  final String titleKey;
  final String hintKey;
  final int cost;
  final ShopCurrency currency;
  final ShopEffect effect;
  final IconData icon;
  final int hours;
  final String? itemId;
  final int quantity;
  final int grantGold;
  final int grantGems;
}

const List<ShopOffer> shopBoosters = [
  ShopOffer(
    id: 'time_1h',
    titleKey: 'shop.time1h',
    hintKey: 'shop.time1hHint',
    cost: 10,
    currency: ShopCurrency.gems,
    effect: ShopEffect.timeSkip,
    icon: Icons.fast_forward,
    hours: 1,
  ),
  ShopOffer(
    id: 'time_6h',
    titleKey: 'shop.time6h',
    hintKey: 'shop.time6hHint',
    cost: 40,
    currency: ShopCurrency.gems,
    effect: ShopEffect.timeSkip,
    icon: Icons.fast_forward,
    hours: 6,
  ),
  ShopOffer(
    id: 'time_24h',
    titleKey: 'shop.time24h',
    hintKey: 'shop.time24hHint',
    cost: 120,
    currency: ShopCurrency.gems,
    effect: ShopEffect.timeSkip,
    icon: Icons.fast_forward,
    hours: 24,
  ),
  ShopOffer(
    id: 'xp_elixir',
    titleKey: 'shop.xpElixir',
    hintKey: 'shop.xpElixirHint',
    cost: 18,
    currency: ShopCurrency.gems,
    effect: ShopEffect.xpElixir,
    icon: Icons.science,
  ),
  ShopOffer(
    id: 'double_loot',
    titleKey: 'shop.doubleLoot',
    hintKey: 'shop.doubleLootHint',
    cost: 22,
    currency: ShopCurrency.gems,
    effect: ShopEffect.doubleLoot,
    icon: Icons.inventory_2,
  ),
];

const List<ShopOffer> shopPacks = [
  ShopOffer(
    id: 'pack_iron_ore',
    titleKey: 'shop.ironPack',
    hintKey: 'shop.ironPackHint',
    cost: 20,
    currency: ShopCurrency.gold,
    effect: ShopEffect.itemPack,
    icon: Icons.terrain,
    itemId: 'iron_ore',
    quantity: 20,
  ),
  ShopOffer(
    id: 'pack_charred_pelt',
    titleKey: 'shop.peltPack',
    hintKey: 'shop.peltPackHint',
    cost: 25,
    currency: ShopCurrency.gold,
    effect: ShopEffect.itemPack,
    icon: Icons.pets,
    itemId: 'charred_pelt',
    quantity: 10,
  ),
  ShopOffer(
    id: 'pack_gold',
    titleKey: 'shop.goldPack',
    hintKey: 'shop.goldPackHint',
    cost: 10,
    currency: ShopCurrency.gems,
    effect: ShopEffect.goldPack,
    icon: Icons.monetization_on,
    grantGold: 500,
  ),
  ShopOffer(
    id: 'pack_gems',
    titleKey: 'shop.gemPack',
    hintKey: 'shop.gemPackHint',
    cost: 250,
    currency: ShopCurrency.gold,
    effect: ShopEffect.gemPack,
    icon: Icons.diamond,
    grantGems: 10,
  ),
];

final Map<String, ShopOffer> shopCatalog = {
  for (final offer in [...shopBoosters, ...shopPacks]) offer.id: offer,
};
