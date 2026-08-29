# Comprehensive Audit Report — Idle RPG (`rpg-mobile`)

**Date:** 29 August 2026  
**Scope:** Full project (Flutter + Flame + Riverpod 3), Chapter 1 “The Ash Pilgrim”, action mastery, item sets, EN/UK localisation, 5 / 45 / 50 layout.  
**Method:** `flutter analyze` (clean), catalogue/key diffs, loot↔recipe crosswalk, mastery curve math, provider/Flame read-through, UI string sweep, plus a dedicated Riverpod/combat pass. Analyzer reported **0 issues**. Suite last recorded **82 tests passing**.

There is no `EquipmentProvider`. Equipment lives on `inventoryProvider`. Combat live state is `combatProvider` / `CombatState`. Derived mastery is `playerStatsProvider`.

---

## Technical Bugs & Warnings

### Analyzer and null safety

`flutter analyze` completes with **no issues**. No null-safety errors, unused-import warnings, or missing required fields in the current tree. This section is about runtime and architecture risk, not compile diagnostics.

### Critical — failed crafts can eat materials

`CraftingController.craft()` (`lib/providers/crafting_provider.dart`) spends gold, then `consumeMaterials`, then `inventory.add`. On `PickupOutcome.bagFull` it refunds gold only — **inputs stay gone**.

`_blockFor` rejects an already-full bag, so the common path is safe. The hole is a **race with the 20 Hz loot tick**: the bag can fill between the pre-check and `add`. `outputQuantity > 1` unique pieces can also fail after the first slot is taken.

**Suggested fix:** treat craft as one transaction (capacity + gold + mats + output). On any failure, restore materials. Prefer reserving the output slot before deducting.

### High — autosave debounce never settles during combat

`saveControllerProvider` (`lib/providers/save_controller.dart`) listens to `playerProvider` and resets a **2-second** debounce on every change.

Combat calls `recordHit()` on every landed swing and `recordDamageTaken()` on every incoming hit (`lib/providers/combat_provider.dart`). Those mutate `PlayerState`. At ~1 attack/second the debounce is reset forever. Player mastery counters, gold, and XP are only guaranteed to disk on:

- app pause / inactive / hidden / detached (`GameScreen.didChangeAppLifecycleState`)
- explicit `flushNow()` after a craft
- provider dispose

A force-quit mid-fight can drop several minutes of hits, kills, and gold. Inventory/progress saves can also stall if those slices change more often than once per two quiet seconds.

**Suggested fix:** persist combat counters on a separate, longer cadence (e.g. every 15–30s or on kill), or do not let `hitsDealt` / `damageTaken` retrigger the shared debounce. Batch `recordHit` / `recordDamageTaken` / `goldOnHit` once per combat tick instead of inside the swing loop.

`PrefsSaveStore.save` is async (`SharedPreferences.setString`) and `flush()` never awaits it. Lifecycle `flushNow()` is fire-and-forget, so a mobile kill can drop the in-flight write even after debounce.

### High — fire damage is unmitigated true damage

`rollAttack` already applies armor. The loop then does `damage = hit.damage + stats.fireDamage` (`combat_provider.dart`). Fire is added **after** mitigation and **does not crit**.

Ashen Warden 4-piece grants a flat **+10 fire**. Starter kit plus bag pieces (`leather_cap`, `worn_boots`) complete that set at level 1. Ten true damage per swing dominates early enemy HP (Green Slime 22, Ash Wolf 28).

The combat-sheet DPS figure (`CombatStats.dps`) **ignores fire**, so the Stats tab under-reports real output.

### Medium — current HP is not clamped when max HP drops

`_tick()` clamps mana to `stats.maxMana` but not HP (`combat_provider.dart`). Unequipping HP gear mid-fight can leave `playerHp` above the new max (`450 / 400` on the plate; the bar is visually capped at 1.0).

### Medium — Flame snapshot misses `combatStatsProvider`

`GameViewport` listens to combat, inventory, settings, location, and l10n — not `combatStatsProvider`. Mastery or skill HP changes update the Flutter HUD immediately, but the in-sprite HP fraction (`playerHp / maxHp`) waits for the next combat emission. Usually a tick later; visible if combat is paused.

`resetGameProvider` invalidates combat but not `combatEventBusProvider`, so queued FX can play on a fresh run.

### Medium — HUD and Flame are pushed at 20 Hz

The simulation ticks at 20 Hz by design. That is sound.

- `GameViewport` `ref.listen(combatProvider)` calls `applySnapshot` every tick. The push itself is cheap (health fractions, approach lerp).
- `_EnemyPlate` / `_PlayerPlate` `watch` live HP, so Flutter rebuilds the overlay 20 times a second.
- Travel spawns a `DustPuff` every **110 ms**. Puffs self-remove at 0.4 s (~4 live). Acceptable.
- Ash Grove `EmberField` is a **fixed pool of 28** particles. No leak.

No Flame-side provider reads (correct one-way snapshot). No timer leak: `CombatNotifier.build` cancels `Timer.periodic` in `ref.onDispose`. `SaveController` cancels its debounce on dispose.

Risk is mid-range phones, not architecture: overlay rebuilds plus slash FX plus damage floats during fast multi-hits (`maxAttacksPerTick = 4`). `FloatingText.render` allocates two `TextPaint` objects **per number per frame**. Dying enemy sprites can stack (0.55 s death). Damage numbers are opt-out via settings.

### Medium — dead attribute API still mutates save data

`PlayerNotifier.allocate` / `respecAttributes` still write `allocated` and `attributePoints`. Combat no longer reads them (`combatStatsProvider` uses `masteryAllocationProvider`). Players or leftover UI paths can change a save field that does nothing. `attributePointsPerLevel = 3` in `combat_math.dart` is unused.

Legacy saves without `hitsDealt` / `damageTaken` are seeded from spent Strength/Endurance. That migration is correct. After migration, further `allocate()` calls do not keep mastery in sync.

### Medium — mastery HP gains do not heal

XP level-ups refill HP (`_resolveKill`). Armor-mastery HP increases do not. Current HP stays flat while `maxHp` jumps, so the bar visually drops after taking damage — the opposite of a “you got tougher” beat.

### Low — derived-provider health is otherwise solid

| Provider | Verdict |
|---|---|
| `playerStatsProvider` | Pure derived `ActionMastery`. No leak. |
| `masteryAllocationProvider` | Selects mastery **levels**, so hits do not rebuild the combat sheet every swing. Correct. |
| `setBonusProvider` / `setThornsProvider` | Recompute from equipped ids. Equip/unequip stays in sync. |
| `localeProvider` | Thin alias of `settingsProvider.locale`. Persists. |
| `combatEventBusProvider` | Capped at 64 events; oldest dropped. No unbounded queue. |
| `resetGameProvider` | Wipes store and invalidates player / inventory / skills / progress / settings / combat. Does **not** clear `combatEventBusProvider`. |

No race between Flame and simulation: Flame never writes game state. Location `ref.listen` abandons the current fight before travel. App background pauses the timer so offline farming cannot accrue.

### Low — portrait lock is explicit

`main.dart` locks portrait up/down. The 5 / 45 / 50 column is not asked to survive landscape. That is the right constraint.

---

## Narrative & Localization Flaws

### Dictionary coverage (keys)

| Map | EN | UK | Missing in one side |
|---|---|---|---|
| UI chrome (`strings_ui.dart`) | 238 | 238 | none |
| Items | 65 | 65 | none |
| Enemies | 27 | 27 | none |
| Locations | 8 | 8 | none |
| Skills | 24 | 24 | none |

Catalogue IDs match the data files (65 items, 27 enemies, 8 locations). **Key-level EN/UK parity is 100%.** Fallbacks in `L10n` (English dictionary, then model `.name`) are unused for current content. Runtime UK coverage is lower (**~88–92%**) because several tabs hardcode English.

`ui.chapter1` (`Chapter 1` / `Розділ 1`) is defined in both dictionaries and **never used**.

### High — hardcoded English bypasses l10n

These strings stay English in Ukrainian mode:

| Location | String |
|---|---|
| `lib/ui/tabs/map_tab.dart` (~623) | `Farming here` / `Travel here` |
| `lib/ui/tabs/map_tab.dart` (~412) | ` · HERE` on the current node |
| `lib/ui/tabs/skills_tab.dart` (~49, 77) | `N skill point(s)`, `Respec` |
| `lib/ui/tabs/skills_tab.dart` (~433–456) | `Free`, `Rank up` |
| `lib/ui/tabs/skills_tab.dart` (~492–535) | `Per rank`, `Current total`, `Perk`, `Now:`, `Auto-cast`, perk templates (`% chance to double loot`, thorns, gold-on-hit) |
| `lib/ui/tabs/bestiary_tab.dart` (~154, 225) | `undiscovered`, `Fight in {location} to add this entry.` |
| `lib/ui/tabs/bestiary_tab.dart` (~203) | `{n} xp` |
| `lib/ui/tabs/stats_tab.dart` (~270) | `Lv $level` on mastery tracks (elsewhere uses `ui.level`) |

Map travel, the skill tree, and the bestiary are the three places the player still *chooses* something. Those are the worst leaks.

### Medium — model copy vs catalogue copy

`ItemDef.description` in `items_data.dart` often disagrees with `strings_catalog.dart` (`minor_potion`, `leather_armor`, `gnarled_staff`, several late mats). The UI reads the catalogue, so players see the bilingual text. The drift is a maintenance trap: a missing catalogue key would suddenly surface different English from the model.

### High — Chapter 1 tone is split in two

Ash Grove copy is strong (smouldering canopy, embers as dead fireflies). The zone still spawns **Green Slime** (`green_slime`) with “Wobbles toward you with unearned confidence” and drops **Slime Jelly**. A cartoon slime in a burnt pilgrimage wood breaks the chapter title.

`field_rat` and `wild_boar` exist in the bestiary catalogue with pastoral flavour and **never spawn on any location**. They read as leftover pre-rebrand meadow fauna.

Location id `meadow` is correctly frozen for saves; the *display* name is Ash Grove. That is fine. The slime spawn is the problem, not the id.

### High — Chapter 1 signature mats have no sink

`charred_pelt` (Ash Wolf) and `ashen_bark` (Decayed Treant) are the chapter’s named drops. **No recipe consumes them.** The map advertises them; the bag just fills. The pilgrim fantasy (cloak, ember steel, ash reagents) stops at flavour text.

Ashen Warden pieces that *are* themed (`ember_blade`, `pilgrim_cloak`) are starter gear, not crafts. There is no “forge the grove into a kit” loop.

### Medium — there is no quest layer

“The Ash Pilgrim” is a **region label**, not a story. No quests, no pilgrim voice, no grove-to-caldera callback, no bestiary revelations beyond a one-line enemy description. Bestiary lore is a single sentence per mob. That is coherent as an idle loop; it is thin as a chapter.

### Medium — Emberpeak is filed under Drowned Halls

`emberpeak` (volcanic caldera, ash_drake) uses region **Drowned Halls** in both EN and UK — the same region as Sunken Ruins (drowned city). The pilgrimage’s implied ending (return to fire) is geographically and thematically mis-shelved. Palette mood is `dusk`, not `ash`, so the caldera also **does not get ember particles** (only `BiomeMood.ash` on Ash Grove).

Orc War Camp sharing **Undervault** with Spider Hollow is a milder stretch.

### Low — flavour gaps on gear

Many equipment rows omit `description` and inherit `''`. Item sheets hide empty descriptions, so this is silence rather than a fallback leak. Named Chapter 1 pieces and most mats do have bilingual blurbs.

Skill and combat-feed templates interpolate through `L10n.activity`. Those paths are clean.

---

## Visual & UI/UX Flaws

### Layout (5 / 45 / 50)

`GameScreen` uses a fixed flex column inside `SafeArea(bottom: false)` with a second `SafeArea` on the tab bar. Portrait lock plus TopBar font/bar heights derived from the 5% strip is the right idea.

**Risks (not analyzer bugs):**

- Short phones (e.g. 667 logical height): 5% ≈ 33 px. TopBar clamps type to 9 px and the XP bar to 7 px. Readable, not comfortable.
- The 50% band loses a 24 px activity ticker + 50 px tabs + home-indicator inset. Content height on a 667-pt phone is roughly **200–220 px**. Stats (language + three mastery tracks + sets + full combat sheet) and Craft (filter chips + cards) are dense; the first screenful never shows set bonuses without a scroll. Widget tests already cannot see “Ashen Warden Set” without scrolling.
- Large accessibility text is clamped to 1.0 on TopBar and viewport HUD. Good for layout integrity; bad for low-vision players.
- Notch/Dynamic Island is handled; the flame stage never resizes when switching tabs (stated goal, met).

### Paper-doll layering

`PlayerComponent.paintBody` order: back leg/arm → torso → head → front leg → weapon arm → **shield last**.

Comment says the weapon sits above everything; the shield is painted after the blade, so a worn shield **covers the weapon** on the facing-right hero. Helmet is drawn, then the eye oval is drawn on top — helmets read as a back-cap, not a covering helm.

Rings and amulets have no doll layer (acceptable). Armor/boots tint by **rarity colour lerp**, not item identity: two uncommon chests look the same. Set identity is not visible in the 45% stage.

### Damage numbers and contrast

- Floating text size is `(viewportH * 0.045).clamp(11, 26)` — OK on the battle band, small on short phones.
- Outgoing hits are **white**. Ash Grove sky bottoms at `#8A3A1C` with orange ground accent. White-on-ember is the weakest pairing in the game; crit gold (`#FFD54F`) is better. Incoming hits are red and read clearly.
- `AppColors.textFaint` (`#666E88`) on `#0F1017` is about **4:1**. Fine for 12 px chrome, weak for 9.5 px tab labels and “searching / in combat” HUD captions.
- Common rarity grey (`#9CA3AF`) on dark surfaces is the same problem as muted text.

### Aesthetic consistency

The game is **procedural vector silhouettes**, not pixel art. Jointed strokes, rounded blobs, and Material icons sit next to each other. That is internally consistent and asset-free. It will not satisfy a “pixel-art paper-doll” brief: no pixel grid, no item-unique sprites, no palette-per-set on the doll.

Ash Grove (embers + burnt parallax) is the strongest visual beat. Later ash-adjacent zones do not reuse `BiomeMood.ash`.

### UX density in the 50% panel

Craft filters (all rarities + three sets) wrap to two+ rows before the first recipe. Gear already shows a set-completion strip — good. Stats mastery copy matches the design request (`Hits: {have}/{need} to next Attack Power`).

Stats is the worst overcrowding: eight cards (language, mastery, sets, combat sheet, gem shop, automation, lifetime, danger) in ~225 pt of content on a short phone. Primary character info competes with settings. Craft living under Items adds a third sub-view to the same half-screen.

---

## Game Design & Pacing Risks

### Action mastery curves

Cost to *reach* a mastery level from zero:

| Level | Hits (weapon / STR) | Damage taken (armor / END) | Kills (rank / AGI+INT) | Cost of next level |
|---|---|---|---|---|
| 1 | 75 | 120 | 14 | 75 / 120 / 14 |
| 5 | 625 | 1,000 | 130 | 175 / 280 / 38 |
| 10 | 1,875 | 3,000 | 410 | 300 / 480 / 68 |
| 20 | 6,250 | 10,000 | 1,420 | 550 / 880 / 128 |
| 30 | 13,125 | 21,000 | 3,030 | 800 / 1,280 / 188 |
| 50 | 34,375 | 55,000 | 8,050 | 1,300 / 2,080 / 308 |

Formulas: `50 + 25L` hits, `80 + 40L` damage, `8 + 6L` kills. Cap 200. Linear-in-level costs → quadratic totals. At ~1 landed hit/sec, weapon 10 is ~30 minutes of uptime; weapon 20 is ~1.7 hours; weapon 50 is a long idle weekend. That is healthy for an incremental.

**Bottleneck:** Armor mastery requires *being hit*. Once the player one-shots (Ashen 4-piece fire, later crit sets), incoming damage dries up and END/HP/armor stall while STR and rank keep climbing. The tank stat is gated on losing.

**Snowball:** Character rank raises **both** AGI and INT, so attack speed, crit, dodge, mana, and magic damage move together. Weapon mastery is “only” STR. Rank is the strongest of the three tracks per action.

**Desync with XP:** XP still uses `50 * level^1.55 + 50 * level` and grants **skill points only**. A player can be account-level 20 with mastery 8 if they die a lot (no hits) or kited… but this is auto-battle, so XP and hits stay roughly coupled. The confusing part is two “levels” on the Stats tab (account level vs three masteries) with no explanation of why attributes no longer come from the former.

### Item rarity and sets

**Catalogue mix (65 items):** Common 16 · Uncommon 17 · Rare 13 · Epic 11 · Legendary 8. Distribution is fine.

**Multipliers:** 1.00 / 1.12 / 1.28 / 1.48 / 1.75 apply to **flat and percent** authored stats. Rare+ percent ASPD/crit on Shadowstalker pieces inflates twice (item rarity × set bonus).

| Set | 2-piece | 4-piece | Risk |
|---|---|---|---|
| Ashen Warden | +36 HP | +20 HP, +10 fire | **Broken in tutorial.** 4/4 is in the starter bag. Fire is true damage. |
| Shadowstalker | +4% crit | +3% crit, +8% ASPD | **Overtuned if completed.** Venom Dagger already has +10% crit and +25% ASPD (×1.28 rare). Set + rings + rank AGI stack toward the 90% crit cap. Completing 4-piece still needs `orc_hide` (War Camp) — a **cross-zone wall** that currently hides the spike. |
| Ironclad Behemoth | +22 armor | +18 armor, +40 HP, 10% thorns | Thorns is 10% of **post-armor** incoming, then capped with skill thorns at 0.6. Safer than Ashen. Pieces span L8–L16. |

No epic/legendary sets. Rings/amulets are set-less, which is good (keeps 2/4 breakpoints on body slots).

`leather_cap` and `worn_boots` are **not craftable**. Selling them permanently bricks Ashen 4-piece.

### Loot vs crafts

Every recipe **input is dropped by some enemy**. No impossible crafts.

**Eight equipment items are unreachable** — defined and localised, no recipe, no loot table:

`rusty_sword`, `wooden_shield`, `padded_vest`, `copper_ring`, `bone_charm`, `gnarled_staff`, `silver_ring`, `ruby_ring`.

They appear in filters and the item inspector if spawned from debug/tests, never in a normal run. That is dead catalogue weight and a Bestiary-style “why can’t I find this?” problem if the names leak.

**Dead drops:** `charred_pelt`, `ashen_bark` — Chapter 1 identity mats with no recipe.

**Early grind walls:**

- `r_minor_potion` needs slime jelly + linen. Linen is 20% on slime, 35% on goblins. Fine if the slime stays; flavour-wrong if it is removed without a replacement drop.
- `iron_ore` is **12%** on Goblin Scrapper, 45% on Bandit Cutthroat (Ridge, rec L10). Ironclad and almost every mid recipe sit behind that 12% until Ridge.
- `wolf_pelt` is not on Ash Grove wolves (`charred_pelt` instead). First armor craft (`r_leather_armor`, 5 pelts) requires Goblin Woods grey wolves (25%) or later dire wolves.
- `r_shadow_wraps` needs **orc_hide** at required level 18, but orcs are a ~L25 camp. The recipe appears four levels before its unique mat exists.
- Endgame (`dragon_scale` 4% on magma golem, 55% on ash_drake at 0.2 spawn weight) is a classic rare-boss wall. Acceptable if labelled as such; the map does not say so.

Gold on Ash Grove kills is 1–8. `r_leather_armor` costs 60 gold plus mats — a short but real gold gate after leaving the grove.

### First ten minutes

Starter: Ember Blade + Pilgrim Cloak (2-piece Ashen, +36 HP), cap and boots in bag. If the player equips the bag, 4-piece fire turns the grove into a slaughter and **starves armor mastery**. If they do not, the 2-piece HP cushion plus uncommon weapon is still comfortable vs slime/wolf; Treant (52 HP, 6 armor) is the first slow fight.

There is no onboarding copy that says “equip the rest of the set” or “mastery comes from fighting, not from + buttons.”

Ash Grove itself is comfortable (~3 s/kill, Goblin Woods unlock in the first session). The **cliff is Goblin Woods** (rec L5, enemies L5–7) immediately after the grove. That is a sharper step than the grove teaches.

---

## Action Plan (Prioritized Fixes)

### P0 — play-now correctness

1. **Make crafting atomic.** Restore materials (and do not spend gold) if `add` returns `bagFull`. Reserve an output slot before deducting.
2. **Stop fire damage from trivialising Chapter 1.** Either delay Ashen 4-piece (do not put two extra set pieces in the starter bag), apply fire **before** armor, or cut 4-piece fire to ~2–3 until later upgrades. Include fire in `CombatStats.dps`.
3. **Flush mastery counters reliably.** Decouple `hitsDealt` / `damageTaken` from the 2 s save debounce, or checkpoint on every kill and every N seconds. Await `store.save` on lifecycle flush. Batch hit/gold writes once per combat tick.
4. **Localise leftover chrome.** Map (`Farming here`, `Travel here`, `HERE`), the full Skills sheet (points header, `Respec`, `Rank up`, perk blurbs), and Bestiary (`undiscovered`, farm hint, `xp`). Use or delete unused `ui.chapter1`.
5. **Clamp `playerHp` to `maxHp`** when gear or mastery lowers the cap. Listen to `combatStatsProvider` in `GameViewport`. Clear the combat event bus on reset.
6. **Do not consume potions at full HP** (`usePotion` currently returns true after a zero heal). Clear active-skill cooldowns on travel/death.

### P1 — Chapter 1 coherence

7. **Retheme or replace `green_slime`** in Ash Grove (cinder jelly, ash mite, etc.) and keep the `slime_jelly` item id if saves/recipes must stay stable.
8. **Give `charred_pelt` and `ashen_bark` a sink** — e.g. an Ashen Warden upgrade recipe or a grove potion — so the advertised drops matter.
9. **Make `leather_cap` / `worn_boots` re-craftable** from those mats so selling them is not a permanent set brick.
10. **Move Emberpeak** out of Drowned Halls (own “Caldera” / Ash Pilgrim finale region) and set `BiomeMood.ash` so the ember field returns.

### P2 — pacing and mastery

11. **Armor mastery needs an off-combat drip** (or credit a fraction of *prevented* damage) so one-shotters do not freeze END.
12. **Explain the two level tracks** on the Stats tab (account level → skill points; actions → attributes).
13. **Rebalance rank** so AGI and INT do not both ride kills 1:1, or split rank into two slower tracks.
14. **Fix Shadow Wraps gating:** drop a small `orc_hide` substitute in Hollow, or raise the recipe to War Camp level.
15. **Surface iron_ore earlier** (Ash Grove treant / bandit preview) or raise the 12% goblin rate so Ironclad is not a Ridge hostage.

### P3 — presentation

16. **Paint the shield before the weapon** (or put it on the back arm) so the doll’s blade stays visible.
17. **Draw helmet over the eye** (or a visor slit) so helm swaps read.
18. **Recolour outgoing damage numbers** on ash palettes (gold/cream, not white).
19. **Lift `textFaint`** or bump tab label size above 9.5 px.
20. **Cull or spawn `field_rat` / `wild_boar`** so the bestiary is not a graveyard of unreachable rows. Same for the eight gear ids with no drop and no recipe (`rusty_sword`, `wooden_shield`, `padded_vest`, `copper_ring`, `bone_charm`, `gnarled_staff`, `silver_ring`, `ruby_ring`).
21. **Remove or hide `allocate` / `respecAttributes` / `attributePointsPerLevel`** so saves cannot diverge from combat.
22. **Heal (or keep HP fraction)** when armor mastery raises `maxHp`.
23. **Optional quest sting** for Chapter 1 (one beat: “walk the ash to Emberpeak”) so the region name is a promise, not a label.
24. **Cache `TextPaint`** on floating damage and cap concurrent death sprites.

### Already in good shape (do not regress)

- Flame does not read Riverpod; simulation is 20 Hz and testable.
- EN/UK key parity is complete; activity feed stores keys, not baked English.
- Location ids (`meadow`, …) are stable for saves.
- Set 2/4 indicators exist on Gear and Stats; craft can filter by rarity and set.
- Event bus is capped; ember particles are pooled; combat timer is disposed.
- Analyzer is clean; treat new l10n keys as a required pair (EN + UK) in review.

---

*End of audit. No code was changed for these findings; analyzer had nothing to fix.*
