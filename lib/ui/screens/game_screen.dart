import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_manager.dart';
import '../../providers/combat_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/save_controller.dart';
import '../../providers/settings_provider.dart';
import '../../providers/time_controller.dart';
import '../theme.dart';
import '../widgets/bottom_dock.dart';
import '../widgets/game_viewport.dart';
import '../widgets/top_bar.dart';

/// Root gameplay screen. The canvas fills leftover space; hubs open as sheets.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(saveControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAudio();
      ref.read(timeControllerProvider.notifier).claimOffline();
    });
  }

  void _syncAudio() {
    final settings = ref.read(settingsProvider);
    AudioManager.instance.applyVolumes(
      sfx: settings.sfxVolume,
      bgm: settings.bgmVolume,
    );
    AudioManager.instance.setBiome(
      ref.read(currentLocationProvider).palette.mood,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(combatProvider.notifier)
        .setPaused(state != AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      ref.read(timeControllerProvider.notifier).claimOffline();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(ref.read(saveControllerProvider).flushNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (_, next) {
      AudioManager.instance.applyVolumes(
        sfx: next.sfxVolume,
        bgm: next.bgmVolume,
      );
    });
    ref.listen(currentLocationProvider, (_, next) {
      AudioManager.instance.setBiome(next.palette.mood);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Expanded(flex: 8, child: TopBar()),
            const Expanded(flex: 92, child: GameViewport()),
            const BottomDock(),
          ],
        ),
      ),
    );
  }
}
