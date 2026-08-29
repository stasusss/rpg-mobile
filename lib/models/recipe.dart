import 'package:flutter/foundation.dart';

/// A crafting recipe turning farmed materials into gear or consumables.
@immutable
class CraftRecipe {
  const CraftRecipe({
    required this.id,
    required this.outputItemId,
    required this.inputs,
    this.outputQuantity = 1,
    this.goldCost = 0,
    this.requiredLevel = 1,
  });

  final String id;
  final String outputItemId;
  final int outputQuantity;

  /// Material item id to required quantity.
  final Map<String, int> inputs;
  final int goldCost;
  final int requiredLevel;
}
