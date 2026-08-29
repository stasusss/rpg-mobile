import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/audio/audio_manager.dart';
import 'package:idle_rpg/providers/save_provider.dart';

/// A container backed by an in-memory save store, disposed with the test.
///
/// Pass [save] to start from an existing save blob.
ProviderContainer createContainer({Map<String, dynamic>? save}) {
  AudioManager.enabled = false;
  final container = ProviderContainer(
    overrides: [saveStoreProvider.overrideWithValue(MemorySaveStore(save))],
  );
  addTearDown(container.dispose);
  return container;
}
