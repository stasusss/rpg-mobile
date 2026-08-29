import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/providers/combat_provider.dart';
import 'package:idle_rpg/providers/inventory_provider.dart';
import 'package:idle_rpg/providers/player_provider.dart';
import 'package:idle_rpg/providers/settings_provider.dart';
import 'package:idle_rpg/providers/shop_provider.dart';
import 'package:idle_rpg/providers/stats_provider.dart';
import 'package:idle_rpg/providers/time_controller.dart';

import 'helpers.dart';

void runFor(FakeAsync async, ProviderContainer container, double seconds) {
  container.read(combatProvider);
  async.elapse(Duration(milliseconds: (seconds * 1000).round()));
}

void main() {
  group('time skip', () {
    test('one hour of meadow farm grants XP, gold and kills', () {
      final container = createContainer();
      final before = container.read(playerProvider);

      final summary = container
          .read(timeControllerProvider.notifier)
          .skipHours(1);

      expect(summary.hours, 1);
      expect(summary.kills, greaterThan(0));
      expect(summary.xp, greaterThan(0));
      expect(summary.gold, greaterThan(0));
      expect(
        container.read(playerProvider).totalKills,
        before.totalKills + summary.kills,
      );
      expect(container.read(playerProvider).gold, greaterThan(before.gold));
    });

    test('XP elixir raises the combat XP multiplier', () {
      final container = createContainer();
      final base = container.read(combatStatsProvider).xpGain;

      container.read(timeControllerProvider.notifier).activateXpElixir();

      expect(
        container.read(combatStatsProvider).xpGain,
        closeTo(base * xpElixirMultiplier, 0.001),
      );
      expect(container.read(timeControllerProvider).xpElixirActive, isTrue);
    });
  });

  group('combat speed', () {
    test('5× finishes the approach faster than 1×', () {
      fakeAsync((async) {
        final slow = createContainer();
        runFor(async, slow, 0.3);
        expect(slow.read(combatProvider).phase, CombatPhase.traveling);

        final fast = createContainer();
        fast.read(timeControllerProvider.notifier).setSpeed(5);
        runFor(async, fast, 0.3);
        expect(fast.read(combatProvider).phase, CombatPhase.fighting);
      });
    });
  });

  group('shop purchases', () {
    test('iron pack spends gold and adds ore', () {
      final container = createContainer();
      final goldBefore = container.read(playerProvider).gold;
      final oreBefore = container.read(inventoryProvider).countOf('iron_ore');

      final result = container
          .read(shopControllerProvider)
          .buy('pack_iron_ore');

      expect(result.success, isTrue);
      expect(container.read(playerProvider).gold, goldBefore - 20);
      expect(
        container.read(inventoryProvider).countOf('iron_ore'),
        oreBefore + 20,
      );
    });

    test('time scroll fails without gems', () {
      final container = createContainer();
      final result = container.read(shopControllerProvider).buy('time_1h');
      expect(result.success, isFalse);
      expect(result.messageKey, 'ui.notEnoughGems');
    });

    test('developer free mode skips the price', () {
      final container = createContainer();
      container.read(settingsProvider.notifier).toggleDeveloperFreeMode();
      final goldBefore = container.read(playerProvider).gold;
      final gemsBefore = container.read(playerProvider).gems;

      final result = container.read(shopControllerProvider).buy('pack_gems');

      expect(result.success, isTrue);
      expect(container.read(playerProvider).gold, goldBefore);
      expect(container.read(playerProvider).gems, gemsBefore + 10);
    });

    test('speed and elixir persist through a save blob', () {
      final first = createContainer();
      first.read(timeControllerProvider.notifier).setSpeed(5);
      first.read(timeControllerProvider.notifier).activateXpElixir();
      final blob = {'time': first.read(timeControllerProvider).toJson()};

      final restored = createContainer(save: blob);
      expect(restored.read(timeControllerProvider).speedMultiplier, 5);
      expect(restored.read(timeControllerProvider).xpElixirActive, isTrue);
    });
  });
}
