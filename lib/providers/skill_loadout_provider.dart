import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/skills_data.dart';
import 'save_provider.dart';
import 'skills_provider.dart';

const List<String> defaultSkillLoadout = [
  'flame_slash',
  'iron_will',
  'shadow_strike',
];

@immutable
class SkillLoadout {
  const SkillLoadout({this.slots = defaultSkillLoadout});

  final List<String> slots;

  String? slotAt(int index) =>
      index >= 0 && index < slots.length ? slots[index] : null;

  SkillLoadout copyWithSlot(int index, String skillId) {
    final next = List<String>.of(slots);
    while (next.length < 3) {
      next.add(defaultSkillLoadout[next.length]);
    }
    next[index] = skillId;
    return SkillLoadout(slots: next.take(3).toList());
  }

  Map<String, dynamic> toJson() => {'slots': slots};

  static SkillLoadout fromJson(Map<String, dynamic> json) {
    final raw = json['slots'];
    if (raw is! List) return const SkillLoadout();
    final slots = [
      for (final e in raw)
        if (e is String && trySkillById(e) != null) e,
    ];
    if (slots.length < 3) {
      return SkillLoadout(
        slots: [
          ...slots,
          ...defaultSkillLoadout.where((id) => !slots.contains(id)),
        ].take(3).toList(),
      );
    }
    return SkillLoadout(slots: slots.take(3).toList());
  }
}

class SkillLoadoutNotifier extends Notifier<SkillLoadout> {
  @override
  SkillLoadout build() {
    final saved = savedSection(ref, 'loadout');
    return saved == null
        ? const SkillLoadout()
        : SkillLoadout.fromJson(saved);
  }

  void setSlot(int index, String skillId) {
    if (trySkillById(skillId) == null) return;
    state = state.copyWithSlot(index, skillId);
  }
}

final skillLoadoutProvider =
    NotifierProvider<SkillLoadoutNotifier, SkillLoadout>(
      SkillLoadoutNotifier.new,
    );

/// The three HUD slots, resolved to unlocked (or signature) actives.
final equippedActivesProvider = Provider<List<UnlockedActive>>((ref) {
  final loadout = ref.watch(skillLoadoutProvider);
  final unlocked = {for (final a in ref.watch(unlockedActivesProvider)) a.id: a};
  final out = <UnlockedActive>[];
  for (final id in loadout.slots.take(3)) {
    final def = trySkillById(id);
    if (def?.active == null) continue;
    final learned = unlocked[def!.active!];
    out.add(learned ?? UnlockedActive(def: def, rank: 1));
  }
  return out;
});
