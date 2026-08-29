import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recipes_data.dart';
import '../audio/audio_manager.dart';
import '../l10n/l10n.dart';
import '../models/combat_event.dart';
import '../models/recipe.dart';
import 'combat_provider.dart';
import 'inventory_provider.dart';
import 'locale_provider.dart';
import 'player_provider.dart';
import 'save_controller.dart';

/// Why a recipe cannot be crafted, or null when it can.
enum CraftBlock { levelTooLow, missingMaterials, notEnoughGold, bagFull }

extension CraftBlockLabel on CraftBlock {
  String label(CraftRecipe recipe, L10n l10n) => switch (this) {
    CraftBlock.levelTooLow => l10n.t('craft.level', {
      'n': '${recipe.requiredLevel}',
    }),
    CraftBlock.missingMaterials => l10n.t('craft.missingMaterials'),
    CraftBlock.notEnoughGold => l10n.t('craft.notEnoughGold'),
    CraftBlock.bagFull => l10n.t('craft.bagFull'),
  };
}

/// Outcome of a one-click craft attempt.
@immutable
class CraftResult {
  const CraftResult({
    required this.success,
    required this.message,
    this.itemId,
  });

  final bool success;
  final String message;
  final String? itemId;
}

/// Snapshot of one recipe's craftability, rebuilt when the bag or level change.
@immutable
class RecipeStatus {
  const RecipeStatus({
    required this.recipe,
    required this.block,
    required this.owned,
  });

  final CraftRecipe recipe;
  final CraftBlock? block;

  /// Quantity held for each input, parallel to `recipe.inputs`.
  final Map<String, int> owned;

  bool get canCraft => block == null;

  /// 0..1 completion across all inputs, used for the progress bar.
  double get materialProgress {
    if (recipe.inputs.isEmpty) return 1;
    var sum = 0.0;
    for (final e in recipe.inputs.entries) {
      sum += ((owned[e.key] ?? 0) / e.value).clamp(0.0, 1.0);
    }
    return sum / recipe.inputs.length;
  }
}

CraftBlock? _blockFor(
  CraftRecipe recipe,
  int level,
  int gold,
  InventoryState inventory,
) {
  if (level < recipe.requiredLevel) return CraftBlock.levelTooLow;
  final hasAll = recipe.inputs.entries.every(
    (e) => inventory.countOf(e.key) >= e.value,
  );
  if (!hasAll) return CraftBlock.missingMaterials;
  if (gold < recipe.goldCost) return CraftBlock.notEnoughGold;
  return null;
}

final recipeStatusesProvider = Provider<List<RecipeStatus>>((ref) {
  final player = ref.watch(playerProvider);
  final inventory = ref.watch(inventoryProvider);
  final bags = ref.read(inventoryProvider.notifier);

  final statuses = [
    for (final recipe in recipesForLevel(player.level))
      RecipeStatus(
        recipe: recipe,
        owned: {for (final id in recipe.inputs.keys) id: inventory.countOf(id)},
        block: () {
          final block = _blockFor(recipe, player.level, player.gold, inventory);
          if (block != null) return block;
          if (!bags.canAcceptCraftOutput(
            inputs: recipe.inputs,
            outputItemId: recipe.outputItemId,
            outputQuantity: recipe.outputQuantity,
          )) {
            return CraftBlock.bagFull;
          }
          return null;
        }(),
      ),
  ];
  statuses.sort((a, b) {
    if (a.canCraft != b.canCraft) return a.canCraft ? -1 : 1;
    final byProgress = b.materialProgress.compareTo(a.materialProgress);
    if (byProgress != 0) return byProgress;
    return a.recipe.requiredLevel.compareTo(b.recipe.requiredLevel);
  });
  return statuses;
});

/// Performs crafting. Returns a [CraftResult] so the UI can show success/fail.
class CraftingController {
  CraftingController(this._ref);

  final Ref _ref;

  CraftResult craft(String recipeId) {
    final recipe = recipeCatalog[recipeId];
    final l10n = _ref.read(l10nProvider);
    if (recipe == null) {
      return CraftResult(success: false, message: l10n.t('craft.unknown'));
    }

    final player = _ref.read(playerProvider);
    final inventory = _ref.read(inventoryProvider.notifier);
    final state = _ref.read(inventoryProvider);
    final name = l10n.itemName(recipe.outputItemId);

    final block = _blockFor(recipe, player.level, player.gold, state);
    if (block != null) {
      return CraftResult(success: false, message: block.label(recipe, l10n));
    }

    if (!inventory.canAcceptCraftOutput(
      inputs: recipe.inputs,
      outputItemId: recipe.outputItemId,
      outputQuantity: recipe.outputQuantity,
    )) {
      return CraftResult(success: false, message: l10n.t('craft.bagFull'));
    }

    final bagSnapshot = state;
    if (!_ref.read(playerProvider.notifier).spendGold(recipe.goldCost)) {
      return CraftResult(
        success: false,
        message: l10n.t('craft.notEnoughGold'),
      );
    }
    if (!inventory.consumeMaterials(recipe.inputs)) {
      _ref.read(playerProvider.notifier).gainGold(recipe.goldCost);
      return CraftResult(
        success: false,
        message: l10n.t('craft.missingMaterials'),
      );
    }
    final outcome = inventory.add(recipe.outputItemId, recipe.outputQuantity);
    if (outcome == PickupOutcome.bagFull) {
      inventory.restoreSnapshot(bagSnapshot);
      _ref.read(playerProvider.notifier).gainGold(recipe.goldCost);
      return CraftResult(success: false, message: l10n.t('craft.bagFull'));
    }

    final message = recipe.outputQuantity > 1
        ? l10n.t('craft.craftedQty', {
            'name': name,
            'n': '${recipe.outputQuantity}',
          })
        : l10n.t('craft.crafted', {'name': name});
    _ref.read(combatProvider.notifier).logActivity(
      recipe.outputQuantity > 1 ? 'feed.craftedQty' : 'feed.crafted',
      ActivityKind.craft,
      {'item': recipe.outputItemId, 'n': '${recipe.outputQuantity}'},
    );
    unawaited(AudioManager.instance.play(SfxKind.craft));
    _ref.read(playerProvider.notifier).recordCraft();
    unawaited(_ref.read(saveControllerProvider).flushNow());
    return CraftResult(
      success: true,
      message: message,
      itemId: recipe.outputItemId,
    );
  }
}

final craftingProvider = Provider<CraftingController>(
  (ref) => CraftingController(ref),
);
