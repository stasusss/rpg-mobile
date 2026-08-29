/// Catalogue copy. Each entry is (name, description) except locations,
/// which are (name, region, description).
const Map<String, (String, String)> enItems = {
  'slime_jelly': ('Cinder Jelly', 'Cooled ash that still binds like resin.'),
  'linen_scrap': ('Linen Scrap', 'Torn cloth salvaged from the fallen.'),
  'oak_branch': ('Oak Branch', 'Sturdy hardwood for hafts and shields.'),
  'leather': ('Leather', 'Cured hide. The backbone of light armour.'),
  'wolf_pelt': ('Wolf Pelt', 'Thick winter fur, still warm.'),
  'charred_pelt': (
    'Charred Pelt',
    'Fur singed in the grove fire. Still holds a shape.',
  ),
  'ashen_bark': (
    'Ashen Bark',
    'Blackened wood that refuses to finish burning.',
  ),
  'goblin_tooth': ('Goblin Tooth', 'Yellowed and jagged. Makes a fine barb.'),
  'iron_ore': ('Iron Ore', 'Raw ore. Needs smelting before use.'),
  'iron_ingot': (
    'Iron Ingot',
    'Smelted and hammered flat. Ready for the forge.',
  ),
  'bone': ('Ancient Bone', 'Dry and dense. Carves into wicked edges.'),
  'bone_dust': ('Bone Dust', 'Ground remains humming with residual magic.'),
  'spider_silk': ('Spider Silk', 'Lighter than linen, stronger than steel.'),
  'venom_sac': ('Venom Sac', 'Handle with care. Coats blades beautifully.'),
  'orc_hide': ('Orc Hide', 'Thick, scarred, and stubborn to cut.'),
  'warg_fang': ('Warg Fang', 'A tooth longer than a dagger.'),
  'stone_core': ('Stone Core', 'The still-beating heart of a golem.'),
  'cursed_rune': ('Cursed Rune', 'It whispers. You should not listen.'),
  'ember_shard': ('Ember Shard', 'A coal that never cools.'),
  'dragon_scale': ('Dragon Scale', 'Proof you should not have won.'),
  'minor_potion': ('Minor Health Potion', 'Restores a portion of max HP.'),
  'greater_potion': (
    'Greater Health Potion',
    'Instantly restores 100% of max HP.',
  ),
  'ember_blade': (
    'Ember Blade',
    'A pilgrim\'s first steel. The edge still smells of smoke.',
  ),
  'pilgrim_cloak': (
    'Pilgrim\'s Cloak',
    'Wool lined against ash-fall. Tier 1 travelling kit.',
  ),
  'rusty_sword': ('Rusty Sword', 'More rust than steel, but it still bites.'),
  'wooden_shield': ('Wooden Shield', 'Better than an open palm.'),
  'leather_cap': ('Leather Cap', 'Keeps the rain and the claws off.'),
  'padded_vest': ('Padded Vest', 'Quilted cloth with a soldier\'s hope.'),
  'worn_boots': ('Worn Boots', 'They have already walked farther than you.'),
  'copper_ring': ('Copper Ring', 'A cheap lucky charm that sometimes is.'),
  'bone_charm': (
    'Bone Charm',
    'A knuckle on a thong. It rattles when danger is near.',
  ),
  'gnarled_staff': ('Gnarled Staff', 'More walking stick than weapon.'),
  'boar_spear': ('Boar Spear', 'A crossbar so the charge stops short.'),
  'iron_sword': ('Iron Sword', 'Honest steel, no pretence.'),
  'iron_shield': ('Iron Shield', 'Heavy enough to hide behind.'),
  'iron_helm': ('Iron Helm', 'Vision is a luxury.'),
  'leather_armor': (
    'Leather Armor',
    'Tier 1 hide plate. Five pelts and two fistfuls of ore.',
  ),
  'leather_boots': ('Leather Boots', 'Quiet enough for the woods.'),
  'silver_ring': ('Silver Ring', 'Catches moonlight and the odd curse.'),
  'fang_amulet': ('Wolf Fang Amulet', 'The pack still answers this one.'),
  'bone_blade': ('Bone Blade', 'Carved, not forged.'),
  'venom_dagger': ('Venom Dagger', 'The cut is the least of your problems.'),
  'bulwark_shield': ('Crypt Bulwark', 'A door that decided to travel.'),
  'skull_helm': ('Skull Helm', 'Someone else\'s last expression.'),
  'chain_mail': ('Chain Mail', 'A thousand rings, one purpose.'),
  'silk_boots': ('Silkstep Boots', 'You arrive before the sound does.'),
  'shadow_hood': (
    'Shadow Hood',
    'Cuts glare and gives the eyes a hunter\'s patience.',
  ),
  'shadow_wraps': ('Shadow Wraps', 'Soft leathers dyed in hollow-night ink.'),
  'ruby_ring': ('Ruby Ring', 'A coal you can wear.'),
  'cursed_pendant': ('Cursed Pendant', 'It likes you. That is the problem.'),
  'orcish_axe': ('Orcish Waraxe', 'Built to split shields and arguments.'),
  'stone_maul': ('Stone Maul', 'Architecture, applied personally.'),
  'tower_shield': ('Tower Shield', 'A portable wall.'),
  'warg_helm': ('Warg Helm', 'The jaw still works.'),
  'orcish_plate': ('Orcish Plate', 'Hammered hide over worse intentions.'),
  'golem_greaves': ('Golem Greaves', 'You will not be moved.'),
  'rune_ring': ('Runed Band', 'The script crawls when you look away.'),
  'wraith_amulet': ('Wraithbone Amulet', 'Cold even in a closed fist.'),
  'emberfang': ('Emberfang', 'The caldera\'s opinion, given an edge.'),
  'dragonscale_bulwark': (
    'Dragonscale Bulwark',
    'A scale large enough to hide a man.',
  ),
  'drake_crown': ('Drake Crown', 'It still thinks it is in charge.'),
  'dragonscale_plate': ('Dragonscale Plate', 'Proof and protection in one.'),
  'ashwalker_boots': ('Ashwalker Boots', 'The ground here never cools.'),
  'ember_ring': ('Ember Ring', 'A circle of unfinished fire.'),
  'caldera_heart': ('Caldera Heart', 'It beats. Slowly.'),
  'bitter_root': (
    'Bitter Root',
    'The grove\'s first reagent. Tastes like a dare.',
  ),
  'blood_ichor': (
    'Blood Ichor',
    'Still warm. The flask fogs from the inside.',
  ),
  'arcane_dust': (
    'Arcane Dust',
    'Ground spellwork. It sticks to the fingertips.',
  ),
  'magma_heart': ('Magma Heart', 'A core that never learned to cool.'),
  'major_potion': (
    'Major Health Potion',
    'Instantly restores 70% of max HP.',
  ),
  'berserk_elixir': (
    'Berserk Elixir',
    'For three minutes: more damage and attack speed.',
  ),
  'defense_brew': (
    'Defense Brew',
    'For three minutes: heavier armour and a thicker hide.',
  ),
  'hunter_mail': (
    'Hunter Mail',
    'Wolf hide stitched over a woodsman\'s vest.',
  ),
  'scout_helm': (
    'Scout Helm',
    'Goblin leather, recut so it actually fits.',
  ),
  'ash_circlet': (
    'Ash Circlet',
    'A ring of grove charcoal on a pilgrim thong.',
  ),
  'blood_fang': ('Blood Fang', 'It drinks first. You get what is left.'),
  'crimson_hood': (
    'Crimson Hood',
    'Dyed in something that was never wine.',
  ),
  'sanguine_mail': ('Sanguine Mail', 'Each ring remembers a pulse.'),
  'gore_treads': ('Gore Treads', 'The soles never quite dry.'),
  'arcane_staff': ('Arcane Staff', 'A scholar\'s argument, given reach.'),
  'mage_circlet': ('Mage Circlet', 'Thin gold, loud thoughts.'),
  'scholar_robes': (
    'Scholar Robes',
    'Ink-stained silk that refuses to burn.',
  ),
  'focus_band': (
    'Focus Band',
    'The sigil turns when a spell is near.',
  ),
  'crypt_staff': (
    'Crypt Staff',
    'Marrow hollowed out and filled with dust.',
  ),
  'warlord_signet': (
    'Warlord Signet',
    'Stolen from a hand that did not open.',
  ),
  'battle_totem': (
    'Battle Totem',
    'A camp charm that still smells of iron and smoke.',
  ),
  'drake_cleaver': (
    'Drake Cleaver',
    'A scale given an edge. The mountain still claims it.',
  ),
  'magma_visor': (
    'Magma Visor',
    'The slits glow. You learn not to look in mirrors.',
  ),
  'basalt_carapace': (
    'Basalt Carapace',
    'Cooled crust over a heart that still wants out.',
  ),
  'lava_treads': (
    'Lava Treads',
    'The ground here never cools. Neither do these.',
  ),
};

const Map<String, (String, String)> ukItems = {
  'slime_jelly': (
    'Жаринове желе',
    'Охололий попіл, що все ще клеїть, як смола.',
  ),
  'linen_scrap': ('Клаптик полотна', 'Подранену тканину знято з полеглих.'),
  'oak_branch': ('Дубова гілка', 'Міцне дерево для ратищ і щитів.'),
  'leather': ('Шкіра', 'Вичинена шкура. Основа легкої броні.'),
  'wolf_pelt': ('Вовча шкура', 'Густа зимова шерсть, ще тепла.'),
  'charred_pelt': (
    'Обвуглена Шкура',
    'Хутро, опалене в пожежі гаю. Ще тримає форму.',
  ),
  'ashen_bark': ('Попеляста Кора', 'Почорніле дерево, що не хоче догоріти.'),
  'goblin_tooth': ('Гоблінський зуб', 'Пожовклий і гострий. Добра зазубрина.'),
  'iron_ore': ('Залізна руда', 'Сира руда. Потребує виплавки.'),
  'iron_ingot': (
    'Залізний злиток',
    'Виплавлений і прокований. Готовий до горна.',
  ),
  'bone': ('Стародавня кістка', 'Суха й щільна. Ріжеться на злі леза.'),
  'bone_dust': ('Кістковий пил', 'Помел, що гуде залишковою магією.'),
  'spider_silk': ('Павутинний шовк', 'Легший за полотно, міцніший за сталь.'),
  'venom_sac': ('Отруйна залоза', 'Обережно. Чудово вкриває леза.'),
  'orc_hide': ('Орча шкура', 'Товста, рубцьована, важко ріжеться.'),
  'warg_fang': ('Ікло варга', 'Зуб довший за кинджал.'),
  'stone_core': ('Кам\'яне ядро', 'Ще живе серце голема.'),
  'cursed_rune': ('Проклята руна', 'Вона шепоче. Не слухай.'),
  'ember_shard': ('Уламок жару', 'Вуглина, що не холоне.'),
  'dragon_scale': ('Драконяча луска', 'Доказ, що ти не мав перемогти.'),
  'minor_potion': (
    'Мале зілля здоров\'я',
    'Відновлює частину максимального HP.',
  ),
  'greater_potion': (
    'Велике зілля здоров\'я',
    'Миттєво відновлює 100% максимального HP.',
  ),
  'ember_blade': (
    'Клинок Жарини',
    'Перша сталь паломника. Лезо ще пахне димом.',
  ),
  'pilgrim_cloak': (
    'Плащ Паломника',
    'Вовна проти попелу. Спорядження 1-го ярусу.',
  ),
  'rusty_sword': ('Іржавий меч', 'Більше іржі, ніж сталі, але все ще кусає.'),
  'wooden_shield': ('Дерев\'яний щит', 'Краще, ніж гола долоня.'),
  'leather_cap': ('Шкіряний ковпак', 'Тримає дощ і кігті осторонь.'),
  'padded_vest': ('Стьобаний жилет', 'Тканина й солдатська надія.'),
  'worn_boots': ('Потерті чоботи', 'Вони вже пройшли далі за тебе.'),
  'copper_ring': ('Мідний перстень', 'Дешевий талісман, який інколи працює.'),
  'bone_charm': (
    'Пахощі з кістки',
    'Суглоб на мотузці. Бряжчить, коли близько біда.',
  ),
  'gnarled_staff': ('Сучкуватий посох', 'Більше ціпок, ніж зброя.'),
  'boar_spear': ('Вепреве ратище', 'Поперечина, щоб зупинити ривок.'),
  'iron_sword': ('Залізний меч', 'Чесна сталь без пихи.'),
  'iron_shield': ('Залізний щит', 'Достатньо важкий, щоб сховатись.'),
  'iron_helm': ('Залізний шолом', 'Огляд — розкіш.'),
  'leather_armor': (
    'Шкіряна броня',
    'Шкіряний обладунок 1-го ярусу. П\'ять шкур і дві жмені руди.',
  ),
  'leather_boots': ('Шкіряні чоботи', 'Досить тихі для лісу.'),
  'silver_ring': (
    'Срібний перстень',
    'Ловить місячне світло й випадкове прокляття.',
  ),
  'fang_amulet': ('Амулет вовчого ікла', 'Зграя все ще відповідає цьому.'),
  'bone_blade': ('Кістяне лезо', 'Вирізьблене, не викуване.'),
  'venom_dagger': ('Отруйний кинджал', 'Поріз — найменша з проблем.'),
  'bulwark_shield': ('Склепний бастіон', 'Двері, що вирішили мандрувати.'),
  'skull_helm': ('Шолом-череп', 'Чийсь останній вираз обличчя.'),
  'chain_mail': ('Кольчуга', 'Тисяча кілець, одна мета.'),
  'silk_boots': ('Шовкокрокові чоботи', 'Ти приходиш раніше за звук.'),
  'shadow_hood': (
    'Тіньовий капюшон',
    'Зрізає відблиск і дає очам терпіння мисливця.',
  ),
  'shadow_wraps': (
    'Тіньові обгорти',
    'М\'яка шкіра, фарбована чорнилом порожнистої ночі.',
  ),
  'ruby_ring': ('Рубіновий перстень', 'Вуглина, яку можна носити.'),
  'cursed_pendant': ('Проклятий кулон', 'Він тебе любить. У тому й біда.'),
  'orcish_axe': ('Орча бойова сокира', 'Щоб колоти щити й суперечки.'),
  'stone_maul': ('Кам\'яна кувалда', 'Архітектура, застосована особисто.'),
  'tower_shield': ('Вежовий щит', 'Портативна стіна.'),
  'warg_helm': ('Шолом варга', 'Щелепа ще працює.'),
  'orcish_plate': ('Орчі лати', 'Вибита шкура поверх гірших намірів.'),
  'golem_greaves': ('Наголінники голема', 'Тебе не зрушать.'),
  'rune_ring': ('Руничне кільце', 'Письмо повзе, коли відводиш погляд.'),
  'wraith_amulet': (
    'Амулет примарної кістки',
    'Холодний навіть у стиснутому кулаці.',
  ),
  'emberfang': ('Жароікло', 'Думка кальдери, якій дали вістря.'),
  'dragonscale_bulwark': (
    'Драконолуский бастіон',
    'Луска, за якою сховається людина.',
  ),
  'drake_crown': ('Корона дрейка', 'Вона все ще думає, що головна.'),
  'dragonscale_plate': ('Драконолускі лати', 'Доказ і захист в одному.'),
  'ashwalker_boots': ('Чоботи попелохода', 'Тут земля ніколи не холоне.'),
  'ember_ring': ('Перстень жару', 'Коло незавершеного вогню.'),
  'caldera_heart': ('Серце кальдери', 'Воно б\'ється. Повільно.'),
  'bitter_root': (
    'Гіркий корінь',
    'Перший реагент гаю. Смак як парі.',
  ),
  'blood_ichor': (
    'Кров\'яний сік',
    'Ще теплий. Колба пітніє зсередини.',
  ),
  'arcane_dust': (
    'Арканічний пил',
    'Помелені чари. Липнуть до пальців.',
  ),
  'magma_heart': ('Магмове серце', 'Ядро, що так і не навчилось холонути.'),
  'major_potion': (
    'Сильне зілля здоров\'я',
    'Миттєво відновлює 70% максимального HP.',
  ),
  'berserk_elixir': (
    'Еліксир берсерка',
    'На три хвилини: більше шкоди й швидкість атаки.',
  ),
  'defense_brew': (
    'Відвар захисту',
    'На три хвилини: важча броня й товстіша шкіра.',
  ),
  'hunter_mail': (
    'Мисливська кольчуга',
    'Вовча шкура нашита на жилет лісника.',
  ),
  'scout_helm': (
    'Шолом розвідника',
    'Гоблінська шкіра, перекроєна щоб пасувала.',
  ),
  'ash_circlet': (
    'Попелясте коло',
    'Кільце деревного вугілля на мотузці паломника.',
  ),
  'blood_fang': ('Криваве ікло', 'Воно п\'є першим. Тобі лишається решта.'),
  'crimson_hood': (
    'Багряний капюшон',
    'Фарбований чимось, що ніколи не було вином.',
  ),
  'sanguine_mail': ('Сангвінічна кольчуга', 'Кожне кільце пам\'ятає пульс.'),
  'gore_treads': ('Криваві кроки', 'Підошви так і не висихають.'),
  'arcane_staff': ('Арканічний посох', 'Аргумент вченого, якому дали довжину.'),
  'mage_circlet': ('Магічне коло', 'Тонке золото, гучні думки.'),
  'scholar_robes': (
    'Шати вченого',
    'Заплямований чорнилом шовк, що не горить.',
  ),
  'focus_band': (
    'Перстень зосередження',
    'Сигіл обертається, коли близько заклинання.',
  ),
  'crypt_staff': (
    'Склепний посох',
    'Мозок видовбано й наповнено пилом.',
  ),
  'warlord_signet': (
    'Перстень воєводи',
    'Знято з руки, що не розтиснулась.',
  ),
  'battle_totem': (
    'Бойовий тотем',
    'Талісман табору, що пахне залізом і димом.',
  ),
  'drake_cleaver': (
    'Дрейковий тесак',
    'Лусці дали вістря. Гора все ще вважає його своїм.',
  ),
  'magma_visor': (
    'Магмовий забрало',
    'Щілини світяться. Ти вчишся не дивитись у дзеркало.',
  ),
  'basalt_carapace': (
    'Базальтовий панцир',
    'Охолола кора над серцем, що хоче назовні.',
  ),
  'lava_treads': (
    'Лавові кроки',
    'Тут земля ніколи не холоне. І ці теж.',
  ),
};

const Map<String, (String, String)> enEnemies = {
  'green_slime': (
    'Cinder Mite',
    'A clot of living ash that still remembers the grove fire.',
  ),
  'field_rat': ('Field Rat', 'Fast, filthy, and disturbingly large.'),
  'wild_boar': ('Wild Boar', 'It charges first and reconsiders never.'),
  'ash_wolf': (
    'Ash Wolf',
    'Grey fur gone black. It hunts the grove that burned around it.',
  ),
  'decayed_treant': (
    'Decayed Treant',
    'A walking trunk whose leaves are only cinders.',
  ),
  'goblin_scrapper': (
    'Goblin Scrapper',
    'Armed with whatever it found this morning.',
  ),
  'goblin_archer': ('Goblin Archer', 'Cowardly, but a genuinely good shot.'),
  'grey_wolf': ('Grey Wolf', 'Never travels far from the pack.'),
  'dire_wolf': ('Dire Wolf', 'The pack leader, and it knows it.'),
  'bandit_cutthroat': (
    'Bandit Cutthroat',
    'Wants your purse. Will settle for your life.',
  ),
  'ridge_ogre': (
    'Ridge Ogre',
    'Slow enough to dodge. Strong enough to matter.',
  ),
  'skeleton_warrior': (
    'Skeleton Warrior',
    'Held together by spite and old bindings.',
  ),
  'skeleton_archer': (
    'Skeleton Archer',
    'Fires without breathing, aims without eyes.',
  ),
  'bone_mage': ('Bone Mage', 'Trades its own marrow for cheap sorcery.'),
  'crypt_lord': ('Crypt Lord', 'Buried with a crown it refuses to surrender.'),
  'cave_spider': ('Cave Spider', 'Drops from above without warning.'),
  'venom_bat': ('Venom Bat', 'Erratic flight makes it maddening to hit.'),
  'broodmother': ('Broodmother', 'Every step you take, she felt it coming.'),
  'orc_grunt': ('Orc Grunt', 'Disciplined, armoured, and utterly humourless.'),
  'orc_berserker': (
    'Orc Berserker',
    'Wears no armour so nothing slows the swing.',
  ),
  'warg': ('Warg', 'Bred for war, fed on messengers.'),
  'wraith': (
    'Wraith',
    'Passes through stone. Prefers not to pass through you.',
  ),
  'stone_golem': ('Stone Golem', 'A wall that decided to walk.'),
  'cursed_knight': (
    'Cursed Knight',
    'Still guarding a hall that sank centuries ago.',
  ),
  'ember_imp': ('Ember Imp', 'Small, gleeful, and constantly on fire.'),
  'magma_golem': ('Magma Golem', 'Cooling crust over a molten core.'),
  'ash_drake': ('Ash Drake', 'The caldera keeps one heir. This is it.'),
};

const Map<String, (String, String)> ukEnemies = {
  'green_slime': (
    'Жариновий кліщ',
    'Згусток живого попелу, що досі пам\'ятає пожежу гаю.',
  ),
  'field_rat': ('Польовий щур', 'Швидкий, брудний і тривожно великий.'),
  'wild_boar': ('Дикий вепр', 'Спочатку б\'є, потім ніколи не думає.'),
  'ash_wolf': (
    'Попелястий Вовк',
    'Сіре хутро почорніло. Полює в гаю, що згорів навколо нього.',
  ),
  'decayed_treant': (
    'Згнилий Трент',
    'Блукаючий стовбур, у якого замість листя лише жарина.',
  ),
  'goblin_scrapper': (
    'Гоблін-забіяка',
    'Озброєний тим, що знайшов сьогодні вранці.',
  ),
  'goblin_archer': ('Гоблін-лучник', 'Боягуз, але стріляє щиро добре.'),
  'grey_wolf': ('Сірий вовк', 'Ніколи не відходить далеко від зграї.'),
  'dire_wolf': ('Лютий вовк', 'Вожак зграї, і він це знає.'),
  'bandit_cutthroat': (
    'Бандит-горлоріз',
    'Хоче гаманець. Погодиться на життя.',
  ),
  'ridge_ogre': (
    'Огр пасма',
    'Достатньо повільний, щоб ухилитись. Достатньо сильний, щоб важити.',
  ),
  'skeleton_warrior': (
    'Скелет-воїн',
    'Тримається разом зі злості й старих пут.',
  ),
  'skeleton_archer': (
    'Скелет-лучник',
    'Стріляє без подиху, цілиться без очей.',
  ),
  'bone_mage': ('Кістяний маг', 'Міняє власний мозок на дешеву магію.'),
  'crypt_lord': ('Володар склепу', 'Похований із короною, якої не віддає.'),
  'cave_spider': ('Печерний павук', 'Падає згори без попередження.'),
  'venom_bat': ('Отруйний кажан', 'Хаотичний політ зводить з розуму.'),
  'broodmother': ('Мати виводка', 'Кожен твій крок вона вже відчула.'),
  'orc_grunt': ('Орк-рядовий', 'Дисциплінований, у броні й геть без гумору.'),
  'orc_berserker': (
    'Орк-берсерк',
    'Без броні, щоб ніщо не сповільнювало удар.',
  ),
  'warg': ('Варг', 'Виведений для війни, годований гінцями.'),
  'wraith': ('Примара', 'Проходить крізь камінь. Крізь тебе — воліє не.'),
  'stone_golem': ('Кам\'яний голем', 'Стіна, що вирішила ходити.'),
  'cursed_knight': (
    'Проклятий лицар',
    'Досі стереже залу, що затонула століття тому.',
  ),
  'ember_imp': ('Жаровий біс', 'Малий, радісний і постійно в вогні.'),
  'magma_golem': ('Магмовий голем', 'Охолоджена кора над розплавленим ядром.'),
  'ash_drake': (
    'Попелястий дрейк',
    'Кальдера тримає одного спадкоємця. Ось він.',
  ),
};

const Map<String, (String, String, String)> enLocations = {
  'meadow': (
    'Ash Grove',
    'The Ash Pilgrim',
    'A burnt forest that still smoulders. Embers hang in the air like fireflies that forgot how to die.',
  ),
  'goblin_woods': (
    'Goblin Woods',
    'The Greenway',
    'Crooked pines, cookfire smoke, and a great many small green problems.',
  ),
  'howling_ridge': (
    'Howling Ridge',
    'Ashen Frontier',
    'Wind-scoured stone above the treeline. Bandits camp here because nobody sane follows them up.',
  ),
  'skeleton_crypt': (
    'Skeleton Crypt',
    'Ashen Frontier',
    'Someone stacked the dead here neatly. Someone else woke them up.',
  ),
  'spider_hollow': (
    'Spider Hollow',
    'Undervault',
    'The webs are load-bearing. Try not to think about what that means.',
  ),
  'orc_warcamp': (
    'Orc War Camp',
    'Undervault',
    'Palisades, drums, and a warband that has been waiting for a reason.',
  ),
  'sunken_ruins': (
    'Sunken Ruins',
    'Drowned Halls',
    'A city that argued with the sea and lost. Its garrison never stood down.',
  ),
  'emberpeak': (
    'Emberpeak Caldera',
    'The Caldera',
    'The mountain is awake and it has opinions about visitors.',
  ),
};

const Map<String, (String, String, String)> ukLocations = {
  'meadow': (
    'Попелястий Гай',
    'Попелястий Паломник',
    'Вигорілий ліс, що досі тліє. Жарини висять у повітрі, наче світляки, які забули, як помирати.',
  ),
  'goblin_woods': (
    'Гоблінський Ліс',
    'Зелений Шлях',
    'Криві сосни, дим багать і сила-силенна дрібних зелених проблем.',
  ),
  'howling_ridge': (
    'Виючий Кряж',
    'Попеляста Межа',
    'Вітром сточений камінь над лісом. Бандити стоять тут, бо ніхто розсудливий за ними не йде.',
  ),
  'skeleton_crypt': (
    'Скелетний Склеп',
    'Попеляста Межа',
    'Хтось акуратно склав тут мертвих. Хтось інший їх розбудив.',
  ),
  'spider_hollow': (
    'Павуча Лощина',
    'Підсклепіння',
    'Павутиння тримає стелю. Краще не думати, що це означає.',
  ),
  'orc_warcamp': (
    'Орчий Військовий Табір',
    'Підсклепіння',
    'Частоколи, барабани й ватага, що чекала на привід.',
  ),
  'sunken_ruins': (
    'Затоплені Руїни',
    'Затоплені Зали',
    'Місто сперечалося з морем і програло. Його гарнізон так і не склав зброю.',
  ),
  'emberpeak': (
    'Кальдера Жаровершини',
    'Кальдера',
    'Гора не спить і має думку про відвідувачів.',
  ),
};

const Map<String, (String, String)> enSkills = {
  'iron_arms': ('Iron Arms', 'The first extra stone on the bar.'),
  'heavy_blow': (
    'Heavy Blow',
    '+5 damage, paid for with a longer follow-through.',
  ),
  'power_strike': (
    'Power Strike',
    'The auto-battler winds up a crushing blow when mana allows.',
  ),
  'execute': ('Execute', 'Wounded enemies take far more from every swing.'),
  'cleave': (
    'Cleave',
    'A wide cut the auto-battler throws between regular swings.',
  ),
  'warlord': ('Warlord', 'Nothing left of the swing but the result.'),
  'fleet_foot': ('Fleet Foot', 'You start moving before the thought finishes.'),
  'quick_draw': ('Quick Draw', 'Shorter recovery between strikes.'),
  'double_loot': ('Double Loot', '10% chance a drop lands twice. Rank it up.'),
  'weak_points': ('Weak Points', 'Every armour set has a seam.'),
  'gold_rush': ('Gold Rush', 'Every clean hit knocks a few coins loose.'),
  'assassin': ('Assassin', 'Speed, seams, and a finishing instinct.'),
  'iron_hide': ('Iron Hide', 'Years of poor decisions, hardened.'),
  'thick_blood': ('Thick Blood', 'More of you to cut through.'),
  'mend': ('Mend', 'The auto-battler spends mana to knit wounds mid-fight.'),
  'thorns': ('Thorns', 'A fraction of every wound is sent back.'),
  'fortress': ('Fortress', 'Blows glance off where they used to bite.'),
  'titan': ('Titan', 'Immovable, and increasingly hard to explain.'),
  'arcane_spark': (
    'Arcane Spark',
    'A first taste of something that is not a sword.',
  ),
  'mana_well': ('Mana Well', 'A deeper pool, and a faster refill.'),
  'mana_bolt': (
    'Mana Bolt',
    'The auto-battler spends mana on a lance of force.',
  ),
  'arcane_surge': ('Arcane Surge', 'Spell power climbs with every rank.'),
  'nova': (
    'Nova',
    'A delayed bloom of magic the loop fires when the pool is full.',
  ),
  'archmage': ('Archmage', 'The pool, the bolt, and the will to keep casting.'),
  'flame_slash': (
    'Flame Slash',
    'A burning cut that leaves a fire DoT on the target.',
  ),
  'iron_will': (
    'Iron Will',
    'A short shield that soaks the next volley.',
  ),
  'shadow_strike': (
    'Shadow Strike',
    'A guaranteed crit burst that also applies bleed.',
  ),
};

const Map<String, (String, String)> ukSkills = {
  'iron_arms': ('Залізні руки', 'Перший зайвий камінь на грифі.'),
  'heavy_blow': ('Важкий удар', '+5 шкоди коштом довшого замаху.'),
  'power_strike': (
    'Могутній удар',
    'Автобій замахується нищівним ударом, коли вистачає мани.',
  ),
  'execute': (
    'Страта',
    'Поранені вороги отримують набагато більше від кожного замаху.',
  ),
  'cleave': ('Розсічення', 'Широкий різ між звичайними ударами.'),
  'warlord': ('Воєвода', 'Від замаху лишається лише результат.'),
  'fleet_foot': ('Прудкі ноги', 'Ти рухаєшся раніше, ніж думка закінчиться.'),
  'quick_draw': ('Швидкий випад', 'Коротше відновлення між ударами.'),
  'double_loot': (
    'Подвійна здобич',
    '10% шанс, що дроп впаде двічі. Підвищуй ранг.',
  ),
  'weak_points': ('Слабкі місця', 'У кожної броні є шов.'),
  'gold_rush': ('Золота лихоманка', 'Кожен чистий удар струшує кілька монет.'),
  'assassin': ('Асасин', 'Швидкість, шви й інстинкт добивати.'),
  'iron_hide': ('Залізна шкура', 'Роки поганих рішень, що затверділи.'),
  'thick_blood': ('Густа кров', 'Більше тебе, щоб прорізати.'),
  'mend': ('Зцілення', 'Автобій витрачає ману, щоб зашити рани серед бою.'),
  'thorns': ('Шипи', 'Частка кожної рани повертається назад.'),
  'fortress': ('Фортеця', 'Удари ковзають там, де раніше кусали.'),
  'titan': ('Титан', 'Непорушний і дедалі важчий для пояснення.'),
  'arcane_spark': ('Арканічна іскра', 'Перший смак чогось, що не є мечем.'),
  'mana_well': ('Криниця мани', 'Глибша водойма й швидше наповнення.'),
  'mana_bolt': ('Мана-стріла', 'Автобій витрачає ману на спис сили.'),
  'arcane_surge': ('Арканічний сплеск', 'Сила заклять росте з кожним рангом.'),
  'nova': ('Нова', 'Відкладений спалах магії, коли водойма повна.'),
  'archmage': ('Архімаг', 'Водойма, стріла й воля продовжувати.'),
  'flame_slash': (
    'Вогняний розсік',
    'Палаючий різ, що лишає вогняний DoT на цілі.',
  ),
  'iron_will': (
    'Залізна воля',
    'Короткий щит, що знімає наступний залп.',
  ),
  'shadow_strike': (
    'Тіньовий удар',
    'Гарантований крит-вибух, що також накладає кровотечу.',
  ),
};
