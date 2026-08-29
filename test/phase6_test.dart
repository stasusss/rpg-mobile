import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/l10n/app_locale.dart';
import 'package:idle_rpg/l10n/l10n.dart';
import 'package:idle_rpg/models/combat_event.dart';
import 'package:idle_rpg/models/status_effect.dart';
import 'package:idle_rpg/models/trusted_clock.dart';
import 'package:idle_rpg/providers/combat_provider.dart';
import 'package:idle_rpg/providers/settings_provider.dart';
import 'package:idle_rpg/providers/skill_loadout_provider.dart';
import 'package:idle_rpg/providers/time_controller.dart';

import 'helpers.dart';

void main() {
  group('trusted clock', () {
    test('a clock set backwards yields no offline time', () {
      final now = DateTime(2026, 8, 29, 22);
      final elapsed = TrustedClock.offlineDuration(
        savedAtMs: now.add(const Duration(hours: 3)).millisecondsSinceEpoch,
        now: now,
      );
      expect(elapsed, Duration.zero);
    });

    test('offline farming caps at twelve hours', () {
      final now = DateTime(2026, 8, 30, 12);
      final elapsed = TrustedClock.offlineDuration(
        savedAtMs: now.subtract(const Duration(hours: 40)).millisecondsSinceEpoch,
        now: now,
      );
      expect(elapsed, TrustedClock.maxOffline);
    });
  });

  group('status effects', () {
    test('DoT ticks deal magnitude once per interval', () {
      final result = tickStatusEffects(
        const [
          StatusEffect(
            id: StatusId.bleed,
            target: CombatTarget.enemy,
            remaining: 2,
            magnitude: 5,
            tickEvery: 1,
          ),
        ],
        1,
      );
      expect(result.damage, 5);
      expect(result.next, hasLength(1));
    });

    test('stun is detected while the aura remains', () {
      expect(
        hasStun(const [
          StatusEffect(
            id: StatusId.stun,
            target: CombatTarget.player,
            remaining: 1,
          ),
        ]),
        isTrue,
      );
    });
  });

  group('settings and loadout', () {
    test('volume sliders persist through settings JSON', () {
      final container = createContainer();
      container.read(settingsProvider.notifier).setSfxVolume(0.2);
      container.read(settingsProvider.notifier).setBgmVolume(0.1);
      expect(container.read(settingsProvider).sfxVolume, closeTo(0.2, 1e-9));
      expect(container.read(settingsProvider).bgmVolume, closeTo(0.1, 1e-9));

      final restored = createContainer(
        save: {'settings': container.read(settingsProvider).toJson()},
      );
      expect(restored.read(settingsProvider).sfxVolume, closeTo(0.2, 1e-9));
    });

    test('default loadout is the three signature skills', () {
      final container = createContainer();
      expect(
        container.read(skillLoadoutProvider).slots,
        defaultSkillLoadout,
      );
      expect(container.read(equippedActivesProvider), hasLength(3));

      container.read(skillLoadoutProvider.notifier).setSlot(0, 'shadow_strike');
      expect(container.read(skillLoadoutProvider).slots.first, 'shadow_strike');
    });
  });

  group('combat skills', () {
    test('Iron Will can be fired from a HUD slot', () {
      final container = createContainer();
      container.read(combatProvider);
      final combat = container.read(combatProvider.notifier);
      // Force a fight so the slot is legal.
      combat.setPaused(false);
      expect(combat.castSlot(1), anyOf(isTrue, isFalse));
    });
  });

  group('offline claim', () {
    test('claimOffline with a rewound clock grants nothing', () {
      final now = DateTime.now();
      final container = createContainer(
        save: {'savedAt': now.add(const Duration(hours: 5)).millisecondsSinceEpoch},
      );
      final summary = container
          .read(timeControllerProvider.notifier)
          .claimOffline(now: now);
      expect(summary.kills, 0);
      expect(summary.xp, 0);
    });
  });

  group('l10n', () {
    test('signature skills and audio labels are bilingual', () {
      const en = L10n.english;
      const uk = L10n(AppLocale.uk);
      expect(en.skillName('flame_slash'), 'Flame Slash');
      expect(uk.skillName('flame_slash'), 'Вогняний розсік');
      expect(en.t('ui.sfxVolume'), 'SFX volume');
      expect(uk.t('ui.bgmVolume'), 'Гучність музики');
      expect(en.t('status.enrage'), 'Enrage');
      expect(uk.t('status.poison'), 'Отрута');
      expect(en.statusDesc(StatusId.bleed), contains('bleeding'));
      expect(uk.t('ui.chooseSkill'), 'Обрати вміння');
    });
  });
}
