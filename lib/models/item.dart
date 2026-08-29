import 'package:flutter/material.dart';

import 'item_set.dart';
import 'stats.dart';

/// Equipment slots on the character doll.
enum EquipSlot {
  weapon,
  shield,
  helmet,
  armor,
  boots,
  ring,
  amulet;

  String get label => switch (this) {
    EquipSlot.weapon => 'Weapon',
    EquipSlot.shield => 'Shield',
    EquipSlot.helmet => 'Helmet',
    EquipSlot.armor => 'Armor',
    EquipSlot.boots => 'Boots',
    EquipSlot.ring => 'Ring',
    EquipSlot.amulet => 'Amulet',
  };

  IconData get icon => switch (this) {
    EquipSlot.weapon => Icons.colorize,
    EquipSlot.shield => Icons.shield_outlined,
    EquipSlot.helmet => Icons.sports_motorsports_outlined,
    EquipSlot.armor => Icons.security,
    EquipSlot.boots => Icons.roller_skating_outlined,
    EquipSlot.ring => Icons.circle_outlined,
    EquipSlot.amulet => Icons.diamond_outlined,
  };
}

enum ItemKind { equipment, material, consumable }

enum ItemRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary;

  String get label => switch (this) {
    ItemRarity.common => 'Common',
    ItemRarity.uncommon => 'Uncommon',
    ItemRarity.rare => 'Rare',
    ItemRarity.epic => 'Epic',
    ItemRarity.legendary => 'Legendary',
  };

  Color get color => switch (this) {
    ItemRarity.common => const Color(0xFF9CA3AF),
    ItemRarity.uncommon => const Color(0xFF4ADE80),
    ItemRarity.rare => const Color(0xFF60A5FA),
    ItemRarity.epic => const Color(0xFFC084FC),
    ItemRarity.legendary => const Color(0xFFFBBF24),
  };

  /// Multiplier applied to an item's authored base stats.
  double get statMultiplier => switch (this) {
    ItemRarity.common => 1.0,
    ItemRarity.uncommon => 1.12,
    ItemRarity.rare => 1.28,
    ItemRarity.epic => 1.48,
    ItemRarity.legendary => 1.75,
  };
}

/// How the equipped weapon is drawn on the character in the viewport.
enum WeaponLook { sword, axe, mace, dagger, staff, spear }

/// Immutable catalogue entry. Instances the player owns are [InventoryEntry].
@immutable
class ItemDef {
  const ItemDef({
    required this.id,
    required this.name,
    required this.kind,
    required this.rarity,
    required this.icon,
    this.description = '',
    this.slot,
    this.levelReq = 1,
    this.bonuses = StatBundle.empty,
    this.sellValue = 1,
    this.maxStack = 1,
    this.weaponLook,
    this.healAmount = 0,
    this.buffId = '',
    this.setId,
  });

  final String id;
  final String name;
  final String description;
  final ItemKind kind;
  final ItemRarity rarity;
  final IconData icon;

  /// Set for [ItemKind.equipment] only.
  final EquipSlot? slot;
  final int levelReq;
  final StatBundle bonuses;
  final int sellValue;
  final int maxStack;
  final WeaponLook? weaponLook;

  /// Fraction of max HP restored, for [ItemKind.consumable].
  final double healAmount;

  /// Timed combat tonic id (`berserk` or `ward`), for [ItemKind.consumable].
  final String buffId;

  /// RPG set this piece belongs to, if any.
  final ItemSetId? setId;

  /// Authored [bonuses] scaled by [ItemRarity.statMultiplier].
  StatBundle get effectiveBonuses => bonuses * rarity.statMultiplier;

  bool get isEquipment => kind == ItemKind.equipment && slot != null;
  bool get stackable => maxStack > 1;
  Color get color => rarity.color;
}

/// One stack (or one unique piece of gear) the player owns.
@immutable
class InventoryEntry {
  const InventoryEntry({
    required this.uid,
    required this.itemId,
    this.quantity = 1,
  });

  /// Unique per stack so the grid can key widgets and gear can be moved.
  final String uid;
  final String itemId;
  final int quantity;

  InventoryEntry copyWith({int? quantity}) => InventoryEntry(
    uid: uid,
    itemId: itemId,
    quantity: quantity ?? this.quantity,
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'itemId': itemId,
    'quantity': quantity,
  };

  static InventoryEntry fromJson(Map<String, dynamic> json) => InventoryEntry(
    uid: json['uid'] as String,
    itemId: json['itemId'] as String,
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );
}

/// A resolved item drop, used for the loot feed and pickup toasts.
@immutable
class LootResult {
  const LootResult({required this.itemId, required this.quantity});

  final String itemId;
  final int quantity;
}
