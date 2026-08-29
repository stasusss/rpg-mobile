import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/save_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Vertical-only: the whole layout is built around a portrait 5/45/50 split.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // Loaded before the first frame so every notifier can seed synchronously.
  final saveStore = await PrefsSaveStore.open();

  runApp(
    ProviderScope(
      overrides: [saveStoreProvider.overrideWithValue(saveStore)],
      child: const IdleRpgApp(),
    ),
  );
}
