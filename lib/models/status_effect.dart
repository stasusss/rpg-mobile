import 'package:flutter/material.dart';

import 'combat_event.dart';

/// Named combat auras applied to the hero or the current foe.
enum StatusId {
  bleed,
  poison,
  stun,
  fireDot,
  shield,
  lifesteal,
  thorns,
  enrage;

  Color get color => switch (this) {
    StatusId.bleed => const Color(0xFFE53935),
    StatusId.poison => const Color(0xFF66BB6A),
    StatusId.stun => const Color(0xFFFFEE58),
    StatusId.fireDot => const Color(0xFFFF8A3D),
    StatusId.shield => const Color(0xFF90CAF9),
    StatusId.lifesteal => const Color(0xFFEF9A9A),
    StatusId.thorns => const Color(0xFFA5D6A7),
    StatusId.enrage => const Color(0xFFFF7043),
  };

  bool get isDot =>
      this == StatusId.bleed ||
      this == StatusId.poison ||
      this == StatusId.fireDot;
}

@immutable
class StatusEffect {
  const StatusEffect({
    required this.id,
    required this.target,
    required this.remaining,
    this.magnitude = 0,
    this.tickEvery = 0.5,
    this.tickAcc = 0,
  });

  final StatusId id;
  final CombatTarget target;
  final double remaining;
  final double magnitude;
  final double tickEvery;
  final double tickAcc;

  bool get expired => remaining <= 0;
  bool get stuns => id == StatusId.stun && remaining > 0;

  StatusEffect copyWith({double? remaining, double? tickAcc}) => StatusEffect(
    id: id,
    target: target,
    remaining: remaining ?? this.remaining,
    magnitude: magnitude,
    tickEvery: tickEvery,
    tickAcc: tickAcc ?? this.tickAcc,
    );

  Map<String, dynamic> toJson() => {
    'id': id.name,
    'target': target.name,
    'remaining': remaining,
    'magnitude': magnitude,
    'tickEvery': tickEvery,
  };

  static StatusEffect? fromJson(Map<String, dynamic> json) {
    final idName = json['id'] as String?;
    final targetName = json['target'] as String?;
    if (idName == null || targetName == null) return null;
    final id = StatusId.values.where((e) => e.name == idName);
    final target = CombatTarget.values.where((e) => e.name == targetName);
    if (id.isEmpty || target.isEmpty) return null;
    return StatusEffect(
      id: id.first,
      target: target.first,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
      magnitude: (json['magnitude'] as num?)?.toDouble() ?? 0,
      tickEvery: (json['tickEvery'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

/// Advances durations and returns DoT damage dealt this slice.
({List<StatusEffect> next, double damage}) tickStatusEffects(
  List<StatusEffect> effects,
  double dt,
) {
  if (effects.isEmpty) return (next: const [], damage: 0);
  final next = <StatusEffect>[];
  var damage = 0.0;
  for (final effect in effects) {
    var acc = effect.tickAcc + dt;
    var remaining = effect.remaining - dt;
    var ticks = 0;
    if (effect.id.isDot && effect.tickEvery > 0) {
      while (acc >= effect.tickEvery && remaining > -effect.tickEvery) {
        acc -= effect.tickEvery;
        ticks++;
      }
    }
    if (ticks > 0) damage += effect.magnitude * ticks;
    if (remaining > 0) {
      next.add(effect.copyWith(remaining: remaining, tickAcc: acc));
    }
  }
  return (next: next, damage: damage);
}

bool hasStun(List<StatusEffect> effects) =>
    effects.any((e) => e.stuns);

double statusMultiplier(List<StatusEffect> effects, StatusId id) {
  var total = 0.0;
  for (final effect in effects) {
    if (effect.id == id) total += effect.magnitude;
  }
  return total;
}

List<StatusEffect> upsertStatus(List<StatusEffect> effects, StatusEffect add) {
  final without = [
    for (final e in effects)
      if (!(e.id == add.id && e.target == add.target)) e,
  ];
  return [...without, add];
}
