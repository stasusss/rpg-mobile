import '../models/item_set.dart';
import '../models/stats.dart';

/// The three named RPG sets. Piece ids must exist in the item catalogue.
const List<ItemSetDef> allItemSets = [
  ItemSetDef(
    id: ItemSetId.ashenWarden,
    pieceIds: ['ember_blade', 'pilgrim_cloak', 'leather_cap', 'worn_boots'],
    twoPiece: StatBundle(flat: {StatKey.maxHp: 36}),
    fourPiece: StatBundle(flat: {StatKey.fireDamage: 3, StatKey.maxHp: 20}),
  ),
  ItemSetDef(
    id: ItemSetId.shadowstalker,
    pieceIds: ['venom_dagger', 'shadow_wraps', 'shadow_hood', 'silk_boots'],
    twoPiece: StatBundle(flat: {StatKey.crit: 0.04}),
    fourPiece: StatBundle(
      flat: {StatKey.crit: 0.03},
      pct: {StatKey.attackSpeed: 0.08},
    ),
  ),
  ItemSetDef(
    id: ItemSetId.ironcladBehemoth,
    pieceIds: ['iron_sword', 'iron_helm', 'iron_shield', 'chain_mail'],
    twoPiece: StatBundle(flat: {StatKey.armor: 22}),
    fourPiece: StatBundle(flat: {StatKey.armor: 18, StatKey.maxHp: 40}),
    fourThorns: 0.10,
  ),
  ItemSetDef(
    id: ItemSetId.bloodthirster,
    pieceIds: ['blood_fang', 'crimson_hood', 'sanguine_mail', 'gore_treads'],
    twoPiece: StatBundle(flat: {StatKey.lifeSteal: 0.04}),
    fourPiece: StatBundle(
      flat: {StatKey.lifeSteal: 0.06, StatKey.critDamage: 0.25},
    ),
  ),
  ItemSetDef(
    id: ItemSetId.archmageArcana,
    pieceIds: ['arcane_staff', 'mage_circlet', 'scholar_robes', 'focus_band'],
    twoPiece: StatBundle(flat: {StatKey.manaRegen: 2}),
    fourPiece: StatBundle(
      flat: {StatKey.manaRegen: 3, StatKey.magicDamage: 18},
    ),
  ),
  ItemSetDef(
    id: ItemSetId.volcanicDrake,
    pieceIds: [
      'drake_cleaver',
      'magma_visor',
      'basalt_carapace',
      'lava_treads',
    ],
    twoPiece: StatBundle(flat: {StatKey.armor: 80}),
    fourPiece: StatBundle(
      flat: {StatKey.armor: 100, StatKey.fireResist: 1.0},
    ),
  ),
];

final Map<ItemSetId, ItemSetDef> itemSetCatalog = {
  for (final s in allItemSets) s.id: s,
};

ItemSetDef itemSetById(ItemSetId id) => itemSetCatalog[id]!;
