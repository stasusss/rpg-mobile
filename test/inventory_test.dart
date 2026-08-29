import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/models/item.dart';
import 'package:idle_rpg/providers/crafting_provider.dart';
import 'package:idle_rpg/providers/inventory_provider.dart';
import 'package:idle_rpg/providers/player_provider.dart';
import 'package:idle_rpg/providers/save_controller.dart';
import 'package:idle_rpg/providers/save_provider.dart';
import 'package:idle_rpg/providers/stats_provider.dart';

import 'helpers.dart';

void main() {
  group('InventoryNotifier', () {
    test('starts with the starter kit equipped', () {
      final container = createContainer();
      final inventory = container.read(inventoryProvider);

      expect(inventory.equipped[EquipSlot.weapon]?.itemId, 'ember_blade');
      expect(inventory.equipped[EquipSlot.armor]?.itemId, 'pilgrim_cloak');
      expect(inventory.bag.map((e) => e.itemId), contains('leather_cap'));
    });

    test('stackable materials merge into one entry', () {
      final container = createContainer();
      final notifier = container.read(inventoryProvider.notifier);

      notifier.add('bone', 3);
      notifier.add('bone', 4);

      final bones = container
          .read(inventoryProvider)
          .bag
          .where((e) => e.itemId == 'bone');
      expect(bones.length, 1);
      expect(bones.first.quantity, 7);
      expect(container.read(inventoryProvider).countOf('bone'), 7);
    });

    test('new equipment marks the Items tab unseen until cleared', () {
      final container = createContainer();
      expect(container.read(inventoryProvider).unseenUids, isEmpty);

      container.read(inventoryProvider.notifier).add('wooden_shield', 1);
      expect(container.read(inventoryProvider).unseenUids, isNotEmpty);

      container.read(inventoryProvider.notifier).add('bone', 3);
      expect(container.read(inventoryProvider).unseenUids.length, 1);

      container.read(inventoryProvider.notifier).markBagSeen();
      expect(container.read(inventoryProvider).unseenUids, isEmpty);
    });

    test('equipment does not stack', () {
      final container = createContainer();
      final notifier = container.read(inventoryProvider.notifier);

      notifier.add('wooden_shield', 1);
      notifier.add('wooden_shield', 1);

      final shields = container
          .read(inventoryProvider)
          .bag
          .where((e) => e.itemId == 'wooden_shield');
      expect(shields.length, 2);
    });

    test('equipping swaps the worn item back into the bag', () {
      final container = createContainer();
      final notifier = container.read(inventoryProvider.notifier);
      container.read(playerProvider.notifier).gainXp(100000);

      notifier.add('iron_sword', 1);
      final uid = container
          .read(inventoryProvider)
          .bag
          .firstWhere((e) => e.itemId == 'iron_sword')
          .uid;

      expect(notifier.equip(uid), isTrue);
      final state = container.read(inventoryProvider);
      expect(state.equipped[EquipSlot.weapon]?.itemId, 'iron_sword');
      expect(state.bag.map((e) => e.itemId), contains('ember_blade'));
    });

    test('equipping is blocked below the level requirement', () {
      final container = createContainer();
      final notifier = container.read(inventoryProvider.notifier);

      notifier.add('emberfang', 1);
      final uid = container
          .read(inventoryProvider)
          .bag
          .firstWhere((e) => e.itemId == 'emberfang')
          .uid;

      expect(notifier.equip(uid), isFalse);
      expect(
        container.read(inventoryProvider).equipped[EquipSlot.weapon]?.itemId,
        'ember_blade',
      );
    });

    test('equipped gear feeds the resolved combat sheet', () {
      final container = createContainer();
      final before = container.read(combatStatsProvider).armor;

      final notifier = container.read(inventoryProvider.notifier);
      notifier.add('wooden_shield', 1);
      final uid = container
          .read(inventoryProvider)
          .bag
          .firstWhere((e) => e.itemId == 'wooden_shield')
          .uid;
      notifier.equip(uid);

      expect(container.read(combatStatsProvider).armor, before + 6);
    });

    test('unequipping returns the item to the bag', () {
      final container = createContainer();
      final notifier = container.read(inventoryProvider.notifier);

      expect(notifier.unequip(EquipSlot.weapon), isTrue);
      final state = container.read(inventoryProvider);
      expect(state.equipped[EquipSlot.weapon], isNull);
      expect(state.bag.map((e) => e.itemId), contains('ember_blade'));
    });

    test('auto-equip only accepts a genuine upgrade', () {
      final container = createContainer();
      final notifier = container.read(inventoryProvider.notifier);
      container.read(playerProvider.notifier).gainXp(100000);

      notifier.add('iron_sword', 1);
      final betterUid = container
          .read(inventoryProvider)
          .bag
          .firstWhere((e) => e.itemId == 'iron_sword')
          .uid;
      expect(notifier.tryAutoEquip(betterUid), isTrue);

      notifier.add('rusty_sword', 1);
      final worseUid = container
          .read(inventoryProvider)
          .bag
          .firstWhere((e) => e.itemId == 'rusty_sword')
          .uid;
      expect(notifier.tryAutoEquip(worseUid), isFalse);
    });

    test('selling credits gold and shrinks the stack', () {
      final container = createContainer();
      final notifier = container.read(inventoryProvider.notifier);
      final startGold = container.read(playerProvider).gold;

      notifier.add('bone', 5);
      final uid = container
          .read(inventoryProvider)
          .bag
          .firstWhere((e) => e.itemId == 'bone')
          .uid;

      final gold = notifier.sell(uid, quantity: 2);
      expect(gold, 8);
      expect(container.read(playerProvider).gold, startGold + 8);
      expect(container.read(inventoryProvider).countOf('bone'), 3);
    });

    test('bag refuses new stacks once capacity is reached', () {
      final container = createContainer();
      final notifier = container.read(inventoryProvider.notifier);
      final capacity = container.read(inventoryProvider).capacity;

      for (var i = 0; i < capacity + 5; i++) {
        notifier.add('wooden_shield', 1);
      }

      final state = container.read(inventoryProvider);
      expect(state.bag.length, capacity);
      expect(notifier.add('wooden_shield', 1), PickupOutcome.bagFull);
    });

    test('consuming a potion removes exactly one', () {
      final container = createContainer();
      final notifier = container.read(inventoryProvider.notifier);
      notifier.add('minor_potion', 2);

      final uid = notifier.findPotionUid()!;
      expect(notifier.consumeOne(uid)?.id, 'minor_potion');
      expect(container.read(inventoryProvider).countOf('minor_potion'), 2);
    });
  });

  group('crafting', () {
    test('recipe consumes materials and gold, then yields the item', () {
      final container = createContainer();
      final inventory = container.read(inventoryProvider.notifier);
      final player = container.read(playerProvider.notifier);

      player.gainXp(100000);
      player.gainGold(1000);
      inventory.add('iron_ore', 6);

      final statuses = container.read(recipeStatusesProvider);
      final ingot = statuses.firstWhere((s) => s.recipe.id == 'r_iron_ingot');
      expect(ingot.canCraft, isTrue);

      final goldBefore = container.read(playerProvider).gold;
      final result = container.read(craftingProvider).craft('r_iron_ingot');
      expect(result.success, isTrue);
      expect(result.message, contains('Iron Ingot'));

      expect(container.read(inventoryProvider).countOf('iron_ore'), 3);
      expect(container.read(inventoryProvider).countOf('iron_ingot'), 1);
      expect(container.read(playerProvider).gold, goldBefore - 10);
    });

    test('crafting fails without enough materials', () {
      final container = createContainer();
      final player = container.read(playerProvider.notifier);
      player.gainXp(100000);
      player.gainGold(1000);

      final result = container.read(craftingProvider).craft('r_iron_ingot');
      expect(result.success, isFalse);
      expect(result.message, contains('Missing materials'));
    });

    test('material progress reports partial completion', () {
      final container = createContainer();
      container.read(playerProvider.notifier).gainXp(100000);
      container.read(inventoryProvider.notifier).add('iron_ore', 1);

      final status = container
          .read(recipeStatusesProvider)
          .firstWhere((s) => s.recipe.id == 'r_iron_ingot');
      expect(status.materialProgress, closeTo(1 / 3, 1e-9));
      expect(status.canCraft, isFalse);
    });

    test(
      'grove mats recraft Ashen Warden pieces sold from the starter kit',
      () {
        final container = createContainer();
        final inventory = container.read(inventoryProvider.notifier);
        final player = container.read(playerProvider.notifier);
        player.gainGold(50);
        inventory.add('charred_pelt', 5);
        inventory.add('ashen_bark', 5);
        inventory.add('linen_scrap', 6);

        expect(
          container
              .read(recipeStatusesProvider)
              .firstWhere((s) => s.recipe.id == 'r_leather_cap')
              .canCraft,
          isTrue,
        );
        expect(
          container
              .read(recipeStatusesProvider)
              .firstWhere((s) => s.recipe.id == 'r_worn_boots')
              .canCraft,
          isTrue,
        );
        expect(
          container
              .read(recipeStatusesProvider)
              .firstWhere((s) => s.recipe.id == 'r_pilgrim_cloak')
              .canCraft,
          isTrue,
        );

        expect(
          container.read(craftingProvider).craft('r_leather_cap').success,
          isTrue,
        );
        expect(
          container.read(craftingProvider).craft('r_worn_boots').success,
          isTrue,
        );
        expect(
          container.read(craftingProvider).craft('r_pilgrim_cloak').success,
          isTrue,
        );
        expect(container.read(inventoryProvider).countOf('leather_cap'), 2);
        expect(container.read(inventoryProvider).countOf('worn_boots'), 2);
        expect(container.read(inventoryProvider).countOf('pilgrim_cloak'), 1);
        expect(container.read(inventoryProvider).countOf('charred_pelt'), 0);
        expect(container.read(inventoryProvider).countOf('ashen_bark'), 0);
      },
    );

    test('ashen bark sinks into an alternate grove draught', () {
      final container = createContainer();
      final inventory = container.read(inventoryProvider.notifier);
      container.read(playerProvider.notifier).gainGold(20);
      inventory.add('ashen_bark', 2);
      inventory.add('slime_jelly', 2);

      final result = container.read(craftingProvider).craft('r_cinder_draught');
      expect(result.success, isTrue);
      expect(container.read(inventoryProvider).countOf('minor_potion'), 3);
      expect(container.read(inventoryProvider).countOf('ashen_bark'), 0);
    });

    test('leather armor consumes wolf pelts and iron ore from the woods', () {
      final container = createContainer();
      final inventory = container.read(inventoryProvider.notifier);
      final player = container.read(playerProvider.notifier);
      player.gainXp(100000);
      player.gainGold(1000);
      inventory.add('wolf_pelt', 5);
      inventory.add('iron_ore', 2);

      final status = container
          .read(recipeStatusesProvider)
          .firstWhere((s) => s.recipe.id == 'r_leather_armor');
      expect(status.canCraft, isTrue);
      expect(status.recipe.inputs['wolf_pelt'], 5);
      expect(status.recipe.inputs['iron_ore'], 2);

      final result = container.read(craftingProvider).craft('r_leather_armor');
      expect(result.success, isTrue);
      expect(container.read(inventoryProvider).countOf('wolf_pelt'), 0);
      expect(container.read(inventoryProvider).countOf('iron_ore'), 0);
      expect(container.read(inventoryProvider).countOf('leather_armor'), 1);
    });

    test('a failed craft does not consume gold or materials', () {
      final container = createContainer();
      final inventory = container.read(inventoryProvider.notifier);
      final player = container.read(playerProvider.notifier);
      player.gainXp(100000);
      player.gainGold(1000);
      inventory.add('iron_ore', 4);

      final capacity = container.read(inventoryProvider).capacity;
      while (container.read(inventoryProvider).bag.length < capacity) {
        inventory.add('wooden_shield', 1);
      }

      final goldBefore = container.read(playerProvider).gold;
      final oreBefore = container.read(inventoryProvider).countOf('iron_ore');
      final result = container.read(craftingProvider).craft('r_iron_ingot');

      expect(result.success, isFalse);
      expect(container.read(playerProvider).gold, goldBefore);
      expect(container.read(inventoryProvider).countOf('iron_ore'), oreBefore);
      expect(container.read(inventoryProvider).countOf('iron_ingot'), 0);
    });

    test('a successful craft flushes the local save immediately', () {
      final container = createContainer();
      container.read(saveControllerProvider);
      final player = container.read(playerProvider.notifier);
      player.gainXp(100000);
      player.gainGold(1000);
      container.read(inventoryProvider.notifier).add('iron_ore', 3);

      container.read(craftingProvider).craft('r_iron_ingot');

      final blob = container.read(saveStoreProvider).load();
      expect(blob, isNotNull);
      expect(blob!['player'], isNotNull);
      expect(blob['inventory'], isNotNull);
      expect(blob['skills'], isNotNull);
      expect(blob['progress'], isNotNull);
      final inventory = blob['inventory'] as Map<String, dynamic>;
      final bag = inventory['bag'] as List<dynamic>;
      expect(bag.any((e) => e is Map && e['itemId'] == 'iron_ingot'), isTrue);
    });
  });
}
