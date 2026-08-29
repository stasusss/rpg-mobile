/// Wall-clock helpers that refuse to reward a player for moving the system clock.
class TrustedClock {
  /// Hard ceiling for unattended offline farming.
  static const Duration maxOffline = Duration(hours: 12);

  /// Shortest gap worth simulating after a resume.
  static const Duration minOffline = Duration(seconds: 60);

  /// Session stopwatch that does not jump when the wall clock is edited.
  static final Stopwatch session = Stopwatch()..start();

  /// Elapsed time since [savedAtMs], or zero if the clock was set backwards.
  ///
  /// Forward jumps are accepted (the device really was off) but clamped to
  /// [cap] so a 2035 date cannot mint a year of gold.
  static Duration offlineDuration({
    required int savedAtMs,
    DateTime? now,
    Duration cap = maxOffline,
  }) {
    final wall = (now ?? DateTime.now()).millisecondsSinceEpoch - savedAtMs;
    if (wall <= 0) return Duration.zero;
    final capped = wall > cap.inMilliseconds ? cap.inMilliseconds : wall;
    return Duration(milliseconds: capped);
  }

  static bool isWorthSimulating(Duration elapsed) =>
      elapsed >= minOffline;
}
