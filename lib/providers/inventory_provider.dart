import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/items_data.dart';
import '../models/gear_score.dart';
import '../models/item.dart';
import '../models/stats.dart';
import 'player_provider.dart';
import 'save_provider.dart';

/// The bag plus the seven equipment slots.
@immutable
class InventoryState {
  const InventoryState({
    required this.bag,
    required this.equipped,
    this.capacity = 48,
    this.nextUid = 1,
    this.unseenUids = const {},
  });

  final List<InventoryEntry> bag;

  /// Every [EquipSlot] is present; a null value means the slot is empty.
  final Map<EquipSlot, InventoryEntry?> equipped;
  final int capacity;

  /// Monotonic counter so stack ids stay unique and serialisable.
  final int nextUid;

  /// Equipment uids added since the Items tab was last opened.
  final Set<String> unseenUids;

  bool get isFull => bag.length >= capacity;
  int get usedSlots => bag.length;

  InventoryEntry? entryByUid(String uid) {
    for (final e in bag) {
      if (e.uid == uid) return e;
    }
    for (final e in equipped.values) {
      if (e != null && e.uid == uid) return e;
    }
    return null;
  }

  /// Total quantity of [itemId] in the bag, ignoring equipped gear.
  int countOf(String itemId) {
    var total = 0;
    for (final e in bag) {
      if (e.itemId == itemId) total += e.quantity;
    }
    return total;
  }

  InventoryState copyWith({
    List<InventoryEntry>? bag,
    Map<EquipSlot, InventoryEntry?>? equipped,
    int? capacity,
    int? nextUid,
    Set<String>? unseenUids,
  }) => InventoryState(
    bag: bag ?? this.bag,
    equipped: equipped ?? this.equipped,
    capacity: capacity ?? this.capacity,
    nextUid: nextUid ?? this.nextUid,
    unseenUids: unseenUids ?? this.unseenUids,
  );

  static InventoryState empty() => InventoryState(
    bag: const [],
    equipped: {for (final slot in EquipSlot.values) slot: null},
  );

  Map<String, dynamic> toJson() => {
    'bag': bag.map((e) => e.toJson()).toList(),
    'equipped': {
      for (final e in equipped.entries)
        if (e.value != null) e.key.name: e.value!.toJson(),
    },
    'capacity': capacity,
    'nextUid': nextUid,
    'unseenUids': unseenUids.toList(),
  };

  static InventoryState fromJson(Map<String, dynamic> json) {
    final bag = <InventoryEntry>[];
    for (final raw in (json['bag'] as List<dynamic>? ?? const [])) {
      if (raw is Map<String, dynamic> &&
          tryItemById(raw['itemId'] as String? ?? '') != null) {
        bag.add(InventoryEntry.fromJson(raw));
      }
    }
    final equipped = <EquipSlot, InventoryEntry?>{
      for (final slot in EquipSlot.values) slot: null,
    };
    final rawEquipped = json['equipped'] as Map<String, dynamic>? ?? const {};
    for (final slot in EquipSlot.values) {
      final raw = rawEquipped[slot.name];
      if (raw is Map<String, dynamic> &&
          tryItemById(raw['itemId'] as String? ?? '') != null) {
        equipped[slot] = InventoryEntry.fromJson(raw);
      }
    }
    return InventoryState(
      bag: bag,
      equipped: equipped,
      capacity: (json['capacity'] as num?)?.toInt() ?? 48,
      nextUid: (json['nextUid'] as num?)?.toInt() ?? bag.length + 10,
      unseenUids: {
        for (final raw in (json['unseenUids'] as List<dynamic>? ?? const []))
          if (raw is String) raw,
      },
    );
  }
}

/// Result of trying to add loot to a full or near-full bag.
enum PickupOutcome { stored, autoSold, bagFull }

class InventoryNotifier extends Notifier<InventoryState> {
  @override
  InventoryState build() {
    final saved = savedSection(ref, 'inventory');
    if (saved != null) return InventoryState.fromJson(saved);

    var fresh = InventoryState.empty();
    for (final id in starterBag) {
      fresh = _addTo(fresh, id, 1, trackUnseen: false).state;
    }
    // Equip the starter kit so the first fight is not fought naked.
    for (final id in starterEquipment) {
      fresh = _addTo(fresh, id, 1, trackUnseen: false).state;
      fresh = _equipIn(fresh, fresh.bag.last.uid) ?? fresh;
    }
    return fresh;
  }

  /// Starter kit plus optional Ember Heritage scraps after a soft reset.
  void resetForNewRun({Map<String, int> extraMats = const {}}) {
    var fresh = InventoryState.empty();
    for (final id in starterBag) {
      fresh = _addTo(fresh, id, 1, trackUnseen: false).state;
    }
    for (final id in starterEquipment) {
      fresh = _addTo(fresh, id, 1, trackUnseen: false).state;
      fresh = _equipIn(fresh, fresh.bag.last.uid) ?? fresh;
    }
    for (final entry in extraMats.entries) {
      if (entry.value <= 0) continue;
      fresh = _addTo(fresh, entry.key, entry.value, trackUnseen: false).state;
    }
    state = fresh;
  }

  // ------------------------------------------------------------ adding loot

  /// Adds [quantity] of [itemId], merging into existing stacks where possible.
  ///
  /// Returns [PickupOutcome.bagFull] and stores nothing when there is no room.
  PickupOutcome add(String itemId, int quantity) {
    final result = _addTo(state, itemId, quantity);
    state = result.state;
    return result.outcome;
  }

  /// Restores a prior bag snapshot after a failed craft.
  void restoreSnapshot(InventoryState snapshot) => state = snapshot;

  /// True when [quantity] of [itemId] would fully fit after consuming [inputs].
  bool canAcceptCraftOutput({
    required Map<String, int> inputs,
    required String outputItemId,
    required int outputQuantity,
  }) {
    final afterConsume = _consumeFrom(state, inputs);
    if (afterConsume == null) return false;
    final before = afterConsume.countOf(outputItemId);
    final preview = _addTo(
      afterConsume,
      outputItemId,
      outputQuantity,
      trackUnseen: false,
    );
    if (preview.outcome == PickupOutcome.bagFull) return false;
    return preview.state.countOf(outputItemId) - before >= outputQuantity;
  }

  /// Clears the Items-tab attention badge.
  void markBagSeen() {
    if (state.unseenUids.isEmpty) return;
    state = state.copyWith(unseenUids: const {});
  }

  _AddResult _addTo(
    InventoryState s,
    String itemId,
    int quantity, {
    bool trackUnseen = true,
  }) {
    final def = tryItemById(itemId);
    if (def == null || quantity <= 0) {
      return _AddResult(s, PickupOutcome.bagFull);
    }

    var remaining = quantity;
    final bag = List<InventoryEntry>.of(s.bag);

    if (def.stackable) {
      for (var i = 0; i < bag.length && remaining > 0; i++) {
        if (bag[i].itemId != itemId) continue;
        final room = def.maxStack - bag[i].quantity;
        if (room <= 0) continue;
        final moved = remaining < room ? remaining : room;
        bag[i] = bag[i].copyWith(quantity: bag[i].quantity + moved);
        remaining -= moved;
      }
    }

    var uid = s.nextUid;
    final fresh = <String>{};
    while (remaining > 0) {
      if (bag.length >= s.capacity) {
        return _AddResult(
          s.copyWith(
            bag: bag,
            nextUid: uid,
            unseenUids: trackUnseen && fresh.isNotEmpty
                ? {...s.unseenUids, ...fresh}
                : s.unseenUids,
          ),
          remaining == quantity ? PickupOutcome.bagFull : PickupOutcome.stored,
        );
      }
      final take = def.stackable && remaining > def.maxStack
          ? def.maxStack
          : remaining;
      final entryUid = 'i$uid';
      bag.add(InventoryEntry(uid: entryUid, itemId: itemId, quantity: take));
      if (def.isEquipment) fresh.add(entryUid);
      uid++;
      remaining -= take;
    }

    return _AddResult(
      s.copyWith(
        bag: bag,
        nextUid: uid,
        unseenUids: trackUnseen && fresh.isNotEmpty
            ? {...s.unseenUids, ...fresh}
            : s.unseenUids,
      ),
      PickupOutcome.stored,
    );
  }

  // --------------------------------------------------------------- equipping

  bool equip(String uid) {
    final next = _equipIn(state, uid);
    if (next == null) return false;
    state = next;
    return true;
  }

  /// Moves a bag entry into its slot, returning the previously worn item to the
  /// bag. Returns null when the item cannot be equipped.
  InventoryState? _equipIn(InventoryState s, String uid) {
    final index = s.bag.indexWhere((e) => e.uid == uid);
    if (index < 0) return null;
    final entry = s.bag[index];
    final def = tryItemById(entry.itemId);
    if (def == null || !def.isEquipment) return null;
    if (ref.read(playerProvider).level < def.levelReq) return null;

    final slot = def.slot!;
    final bag = List<InventoryEntry>.of(s.bag)..removeAt(index);
    final previous = s.equipped[slot];
    if (previous != null) bag.add(previous);

    final equipped = Map<EquipSlot, InventoryEntry?>.of(s.equipped);
    equipped[slot] = entry.quantity > 1
        ? InventoryEntry(uid: entry.uid, itemId: entry.itemId)
        : entry;

    return s.copyWith(bag: bag, equipped: equipped);
  }

  bool unequip(EquipSlot slot) {
    final entry = state.equipped[slot];
    if (entry == null || state.isFull) return false;
    final equipped = Map<EquipSlot, InventoryEntry?>.of(state.equipped);
    equipped[slot] = null;
    state = state.copyWith(bag: [...state.bag, entry], equipped: equipped);
    return true;
  }

  /// Equips [itemId] straight from a drop when it beats the current slot item.
  /// Returns true when the swap happened.
  bool tryAutoEquip(String uid) {
    final entry = state.bag.firstWhere(
      (e) => e.uid == uid,
      orElse: () => const InventoryEntry(uid: '', itemId: ''),
    );
    if (entry.uid.isEmpty) return false;
    final def = tryItemById(entry.itemId);
    if (def == null || !def.isEquipment) return false;
    if (ref.read(playerProvider).level < def.levelReq) return false;

    final current = state.equipped[def.slot!];
    final currentScore = current == null
        ? -1.0
        : gearScore(itemById(current.itemId));
    if (gearScore(def) <= currentScore) return false;
    return equip(uid);
  }

  // ----------------------------------------------------------------- selling

  /// Sells [quantity] from a stack and credits the gold. Returns gold earned.
  int sell(String uid, {int? quantity}) {
    final index = state.bag.indexWhere((e) => e.uid == uid);
    if (index < 0) return 0;
    final entry = state.bag[index];
    final def = tryItemById(entry.itemId);
    if (def == null) return 0;

    final count = (quantity ?? entry.quantity).clamp(1, entry.quantity);
    final gold = def.sellValue * count;

    final bag = List<InventoryEntry>.of(state.bag);
    if (count >= entry.quantity) {
      bag.removeAt(index);
    } else {
      bag[index] = entry.copyWith(quantity: entry.quantity - count);
    }
    state = state.copyWith(bag: bag);
    ref.read(playerProvider.notifier).gainGold(gold);
    return gold;
  }

  /// Sells every unequipped piece of gear at or below [maxRarity]. Materials
  /// and consumables are never touched.
  int sellGearUpTo(ItemRarity maxRarity) {
    var gold = 0;
    final keep = <InventoryEntry>[];
    for (final entry in state.bag) {
      final def = tryItemById(entry.itemId);
      if (def != null &&
          def.isEquipment &&
          def.rarity.index <= maxRarity.index) {
        gold += def.sellValue * entry.quantity;
      } else {
        keep.add(entry);
      }
    }
    if (gold == 0) return 0;
    state = state.copyWith(bag: keep);
    ref.read(playerProvider.notifier).gainGold(gold);
    return gold;
  }

  // ------------------------------------------------------------- consumables

  /// Removes one consumable and returns its definition, or null if unavailable.
  ItemDef? consumeOne(String uid) {
    final index = state.bag.indexWhere((e) => e.uid == uid);
    if (index < 0) return null;
    final entry = state.bag[index];
    final def = tryItemById(entry.itemId);
    if (def == null || def.kind != ItemKind.consumable) return null;

    final bag = List<InventoryEntry>.of(state.bag);
    if (entry.quantity <= 1) {
      bag.removeAt(index);
    } else {
      bag[index] = entry.copyWith(quantity: entry.quantity - 1);
    }
    state = state.copyWith(bag: bag);
    return def;
  }

  /// Finds the weakest potion in the bag, for auto-potion.
  String? findPotionUid() {
    InventoryEntry? best;
    double bestHeal = double.infinity;
    for (final entry in state.bag) {
      final def = tryItemById(entry.itemId);
      if (def == null || def.kind != ItemKind.consumable) continue;
      if (def.healAmount <= 0) continue;
      if (def.healAmount < bestHeal) {
        bestHeal = def.healAmount;
        best = entry;
      }
    }
    return best?.uid;
  }

  // ---------------------------------------------------------------- crafting

  bool hasMaterials(Map<String, int> inputs) =>
      inputs.entries.every((e) => state.countOf(e.key) >= e.value);

  /// Removes recipe inputs. Call only after [hasMaterials] passes.
  bool consumeMaterials(Map<String, int> inputs) {
    final next = _consumeFrom(state, inputs);
    if (next == null) return false;
    state = next;
    return true;
  }

  /// Returns a bag with [inputs] removed, or null if any stack is short.
  static InventoryState? _consumeFrom(
    InventoryState s,
    Map<String, int> inputs,
  ) {
    if (!inputs.entries.every((e) => s.countOf(e.key) >= e.value)) {
      return null;
    }
    final bag = List<InventoryEntry>.of(s.bag);
    for (final need in inputs.entries) {
      var remaining = need.value;
      for (var i = bag.length - 1; i >= 0 && remaining > 0; i--) {
        if (bag[i].itemId != need.key) continue;
        final take = remaining < bag[i].quantity ? remaining : bag[i].quantity;
        remaining -= take;
        if (take >= bag[i].quantity) {
          bag.removeAt(i);
        } else {
          bag[i] = bag[i].copyWith(quantity: bag[i].quantity - take);
        }
      }
    }
    return s.copyWith(bag: bag);
  }

  void expandCapacity(int extra) =>
      state = state.copyWith(capacity: state.capacity + extra);
}

@immutable
class _AddResult {
  const _AddResult(this.state, this.outcome);
  final InventoryState state;
  final PickupOutcome outcome;
}

final inventoryProvider = NotifierProvider<InventoryNotifier, InventoryState>(
  InventoryNotifier.new,
);

/// Combined bonuses from all equipped gear.
final gearBundleProvider = Provider<StatBundle>((ref) {
  final equipped = ref.watch(inventoryProvider).equipped;
  var bundle = StatBundle.empty;
  for (final entry in equipped.values) {
    if (entry == null) continue;
    final def = tryItemById(entry.itemId);
    if (def != null) bundle = bundle + def.effectiveBonuses;
  }
  return bundle;
});

/// Bag contents split for the two inventory sub-grids.
final bagEquipmentProvider = Provider<List<InventoryEntry>>((ref) {
  final bag = ref.watch(inventoryProvider).bag;
  return bag.where((e) {
    final def = tryItemById(e.itemId);
    return def != null && def.kind == ItemKind.equipment;
  }).toList();
});

final bagMaterialsProvider = Provider<List<InventoryEntry>>((ref) {
  final bag = ref.watch(inventoryProvider).bag;
  return bag.where((e) {
    final def = tryItemById(e.itemId);
    return def != null && def.kind != ItemKind.equipment;
  }).toList();
});

/// Charges of any bag item that restores health.
final potionCountProvider = Provider<int>((ref) {
  var total = 0;
  for (final entry in ref.watch(inventoryProvider).bag) {
    final def = tryItemById(entry.itemId);
    if (def != null && def.healAmount > 0) total += entry.quantity;
  }
  return total;
});
