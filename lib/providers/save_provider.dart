import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the single save slot lives.
///
/// Abstracted so tests (and any future cloud backend) can swap the backing
/// store without touching gameplay code.
abstract class SaveStore {
  Map<String, dynamic>? load();
  Future<void> save(Map<String, dynamic> data);
  Future<void> wipe();
}

/// Production store: one JSON blob in shared_preferences.
class PrefsSaveStore implements SaveStore {
  PrefsSaveStore(this._prefs);

  static const String _key = 'idle_rpg_save_v1';

  final SharedPreferences _prefs;

  static Future<PrefsSaveStore> open() async =>
      PrefsSaveStore(await SharedPreferences.getInstance());

  @override
  Map<String, dynamic>? load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      // A corrupt blob should start a new game rather than brick the app.
      return null;
    }
  }

  @override
  Future<void> save(Map<String, dynamic> data) =>
      _prefs.setString(_key, jsonEncode(data));

  @override
  Future<void> wipe() => _prefs.remove(_key);
}

/// Store that keeps the blob in memory only. Used by tests.
class MemorySaveStore implements SaveStore {
  MemorySaveStore([this._data]);

  Map<String, dynamic>? _data;

  @override
  Map<String, dynamic>? load() => _data;

  @override
  Future<void> save(Map<String, dynamic> data) async => _data = data;

  @override
  Future<void> wipe() async => _data = null;
}

/// Overridden in `main()` once shared_preferences has been opened.
final saveStoreProvider = Provider<SaveStore>(
  (ref) => throw StateError('saveStoreProvider must be overridden in main'),
);

/// The decoded save file, or null on a fresh install.
///
/// Every gameplay notifier seeds itself from this synchronously inside
/// `build()`, so it must be resolvable before the first frame.
class SavedGameNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => ref.read(saveStoreProvider).load();

  /// Drops the blob so that invalidated notifiers start from defaults.
  void clear() => state = null;
}

final savedGameProvider =
    NotifierProvider<SavedGameNotifier, Map<String, dynamic>?>(
      SavedGameNotifier.new,
    );

/// Helper for notifiers: pull one top-level section out of the save blob.
Map<String, dynamic>? savedSection(Ref ref, String section) {
  final value = ref.read(savedGameProvider)?[section];
  return value is Map<String, dynamic> ? value : null;
}
