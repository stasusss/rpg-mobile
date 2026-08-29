import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/l10n/app_locale.dart';
import 'package:idle_rpg/l10n/l10n.dart';
import 'package:idle_rpg/models/item_set.dart';
import 'package:idle_rpg/providers/locale_provider.dart';
import 'package:idle_rpg/providers/settings_provider.dart';

import 'helpers.dart';

void main() {
  group('L10n', () {
    test('chapter 1 copy is bilingual', () {
      const en = L10n.english;
      const uk = L10n(AppLocale.uk);

      expect(en.locationName('meadow'), 'Ash Grove');
      expect(uk.locationName('meadow'), 'Попелястий Гай');
      expect(en.locationRegion('meadow'), 'The Ash Pilgrim');
      expect(uk.locationRegion('meadow'), 'Попелястий Паломник');
      expect(en.enemyName('green_slime'), 'Cinder Mite');
      expect(uk.enemyName('green_slime'), 'Жариновий кліщ');
      expect(en.itemName('slime_jelly'), 'Cinder Jelly');
      expect(uk.itemName('slime_jelly'), 'Жаринове желе');
      expect(en.locationRegion('emberpeak'), 'The Caldera');
      expect(uk.locationRegion('emberpeak'), 'Кальдера');
      expect(en.region('The Caldera'), 'The Caldera');
      expect(uk.region('The Caldera'), 'Кальдера');
      expect(en.enemyName('ash_wolf'), 'Ash Wolf');
      expect(uk.enemyName('ash_wolf'), 'Попелястий Вовк');
      expect(en.enemyName('decayed_treant'), 'Decayed Treant');
      expect(uk.enemyName('decayed_treant'), 'Згнилий Трент');
      expect(en.itemName('charred_pelt'), 'Charred Pelt');
      expect(uk.itemName('charred_pelt'), 'Обвуглена Шкура');
      expect(en.itemName('ashen_bark'), 'Ashen Bark');
      expect(uk.itemName('ashen_bark'), 'Попеляста Кора');
      expect(en.itemName('ember_blade'), 'Ember Blade');
      expect(uk.itemName('ember_blade'), 'Клинок Жарини');
      expect(en.itemName('pilgrim_cloak'), "Pilgrim's Cloak");
      expect(uk.itemName('pilgrim_cloak'), 'Плащ Паломника');
      expect(en.itemSet(ItemSetId.ashenWarden), 'Ashen Warden Set');
      expect(uk.itemSet(ItemSetId.ashenWarden), 'Сет Попелястого Вартового');
      expect(en.itemSet(ItemSetId.shadowstalker), 'Shadowstalker Set');
      expect(uk.itemSet(ItemSetId.shadowstalker), 'Сет Тіньового Мисливця');
      expect(en.itemSet(ItemSetId.ironcladBehemoth), 'Ironclad Behemoth Set');
      expect(uk.itemSet(ItemSetId.ironcladBehemoth), 'Сет Залізного Бегемота');
      expect(en.itemSet(ItemSetId.bloodthirster), 'Bloodthirster Set');
      expect(uk.itemSet(ItemSetId.bloodthirster), 'Сет Кровопивця');
      expect(en.itemSet(ItemSetId.archmageArcana), 'Archmage Arcana Set');
      expect(uk.itemSet(ItemSetId.archmageArcana), 'Сет Архімага');
      expect(en.itemSet(ItemSetId.volcanicDrake), 'Volcanic Drake Set');
      expect(uk.itemSet(ItemSetId.volcanicDrake), 'Сет Вулканного Дракона');
      expect(en.itemName('major_potion'), 'Major Health Potion');
      expect(uk.itemName('major_potion'), 'Сильне зілля здоров\'я');
      expect(en.itemName('blood_fang'), 'Blood Fang');
      expect(uk.itemName('blood_fang'), 'Криваве ікло');
      expect(en.t('tab.shop'), 'Shop');
      expect(uk.t('tab.shop'), 'Крамниця');
      expect(en.t('ui.ashSouls'), 'Ash Souls');
      expect(uk.t('ui.ashSouls'), 'Душі Попелу');
      expect(en.t('achieve.prestiges_10.title'), 'Ashen Monarch');
      expect(uk.t('achieve.prestiges_10.title'), 'Попелястий Монарх');
      expect(en.t('shop.time1h'), 'Time Scroll (1h)');
      expect(uk.t('shop.xpElixir'), 'Еліксир досвіду');
    });

    test('combat templates interpolate localized names', () {
      const uk = L10n(AppLocale.uk);
      expect(
        uk.t('feed.slew', {
          'enemy': uk.enemyName('ash_wolf'),
          'xp': '9',
          'gold': '4',
        }),
        contains('Попелястий Вовк'),
      );
      expect(uk.t('ui.travelHere'), 'Подорожувати сюди');
      expect(uk.t('ui.respec'), 'Скинути');
      expect(uk.t('ui.undiscovered'), 'не відкрито');
      expect(uk.t('fx.miss'), 'ПРОМАХ');
      expect(uk.t('fx.levelUp'), 'РІВЕНЬ');
    });
  });

  group('LocaleNotifier', () {
    test('persists through settings and restores on a new container', () {
      final first = createContainer();
      expect(first.read(localeProvider), AppLocale.en);
      first.read(localeProvider.notifier).setLocale(AppLocale.uk);
      expect(first.read(localeProvider), AppLocale.uk);
      expect(first.read(settingsProvider).locale, AppLocale.uk);

      final blob = {'settings': first.read(settingsProvider).toJson()};
      final restored = createContainer(save: blob);
      expect(restored.read(localeProvider), AppLocale.uk);
      expect(restored.read(l10nProvider).t('tab.map'), 'Карта');
    });
  });
}
