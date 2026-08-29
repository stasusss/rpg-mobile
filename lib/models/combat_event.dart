import 'package:flutter/foundation.dart';

enum CombatEventType { damage, dodge, heal, death, spawn, levelUp, skill }

/// Which entity in the viewport an effect is anchored to.
enum CombatTarget { player, enemy }

/// A one-shot visual cue emitted by the simulation and consumed by the
/// renderer. Events are fire-and-forget: dropping them only loses eye candy,
/// never game state.
@immutable
class CombatEvent {
  const CombatEvent({
    required this.type,
    required this.target,
    this.amount = 0,
    this.crit = false,
    this.fireAmount = 0,
    this.text,
  });

  final CombatEventType type;
  final CombatTarget target;
  final double amount;
  final bool crit;

  /// Post-armour fire portion of [amount], for orange floats.
  final double fireAmount;
  final String? text;
}

/// Single-slot queue bridging the Riverpod simulation to the Flame world.
///
/// The simulation pushes, the game drains once per frame. Capped so a
/// backgrounded game cannot grow it without bound.
class CombatEventBus {
  static const int _maxQueued = 64;
  final List<CombatEvent> _queue = [];

  void push(CombatEvent event) {
    if (_queue.length >= _maxQueued) _queue.removeAt(0);
    _queue.add(event);
  }

  /// Returns everything queued since the last call and clears the buffer.
  List<CombatEvent> drain() {
    if (_queue.isEmpty) return const [];
    final out = List<CombatEvent>.of(_queue);
    _queue.clear();
    return out;
  }

  void clear() => _queue.clear();
}

/// A line in the scrolling activity feed shown under the viewport.
///
/// Stores a dictionary key plus args so toggling language re-resolves the
/// line instead of leaving stale English in the ticker.
@immutable
class ActivityEntry {
  const ActivityEntry({
    required this.key,
    this.args = const {},
    required this.kind,
  });

  final String key;
  final Map<String, String> args;
  final ActivityKind kind;
}

enum ActivityKind { kill, loot, levelUp, death, craft, info, skill }
