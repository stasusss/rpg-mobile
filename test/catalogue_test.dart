import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/data/enemies_data.dart';
import 'package:idle_rpg/data/items_data.dart';
import 'package:idle_rpg/data/recipes_data.dart';
import 'package:idle_rpg/data/sets_data.dart';
import 'package:idle_rpg/l10n/strings_catalog.dart';
import 'package:idle_rpg/models/combat_math.dart';
import 'package:idle_rpg/providers/combat_provider.dart';
import 'package:idle_rpg/providers/inventory_provider.dart';
import 'package:idle_rpg/providers/stats_provider.dart';
import 'package:idle_rpg/providers/time_controller.dart';

import 'helpers.dart';

void main() {
  group('catalogue pairing', () {
    test('every item has EN and UK copy', () {
      for (final id in itemCatalog.keys) {
        expect(enItems.containsKey(id), isTrue, reason: 'enItems missing $id');
        expect(ukItems.containsKey(id), isTrue, reason: 'ukItems missing $id');
      }
    });

    test('every recipe output and input exists in the item catalogue', () {
      expect(allRecipes.length, greaterThanOrEqualTo(60));
      for (final recipe in allRecipes) {
        expect(
          itemCatalog.containsKey(recipe.outputItemId),
          isTrue,
          reason: recipe.id,
        );
        for (final input in recipe.inputs.keys) {
          expect(itemCatalog.containsKey(input), isTrue, reason: input);
        }
      }
    });

    test('set pieces exist and alchemy recipes are present', () {
      for (final set in allItemSets) {
        expect(set.pieceIds, hasLength(4));
        for (final id in set.pieceIds) {
          expect(itemById(id).setId, set.id);
        }
      }
      expect(recipeCatalog.containsKey('r_major_potion'), isTrue);
      expect(recipeCatalog.containsKey('r_berserk_elixir'), isTrue);
      expect(recipeCatalog.containsKey('r_defense_brew'), isTrue);
      expect(recipeCatalog.containsKey('r_drake_cleaver'), isTrue);
    });

    test('enemy loot ids exist and new reagents drop in the world', () {
      final dropped = <String>{};
      for (final enemy in enemyCatalog.values) {
        for (final drop in enemy.loot) {
          expect(
            itemCatalog.containsKey(drop.itemId),
            isTrue,
            reason: '${enemy.id} -> ${drop.itemId}',
          );
          dropped.add(drop.itemId);
        }
      }
      expect(dropped, containsAll(['bitter_root', 'blood_ichor', 'arcane_dust']));
      expect(dropped, containsAll(['magma_heart', 'major_potion', 'berserk_elixir']));
    });
  });

  group('alchemy and fire resist', () {
    test('applyFireResist zeroes a fully resisted fire hit', () {
      expect(
        applyFireResist(40, fireHit: true, fireResist: 1),
        0,
      );
      expect(
        applyFireResist(40, fireHit: false, fireResist: 1),
        40,
      );
    });

    test('berserk elixir raises outgoing damage for three minutes', () {
      final container = createContainer();
      final before = container.read(combatStatsProvider).damageMin;
      container.read(inventoryProvider.notifier).add('berserk_elixir', 1);
      final uid = container
          .read(inventoryProvider)
          .bag
          .firstWhere((e) => e.itemId == 'berserk_elixir')
          .uid;

      expect(container.read(combatProvider.notifier).usePotion(uid), isTrue);
      expect(container.read(timeControllerProvider).berserkActive, isTrue);
      expect(container.read(combatStatsProvider).damageMin, greaterThan(before));
    });
  });
}
